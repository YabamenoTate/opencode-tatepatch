#!/usr/bin/env bash
# ===========================================================================
# tatepatch — opencode 改造スクリプト
#
# 公式 opencode に server-side persistence パッチを適用し、
# バージョン文字列に "(Tate Patched)" を追加します。
#
# 使い方:
#   ./patch.sh             パッチを適用
#   ./patch.sh unapply     パッチを解除 (公式に戻す)
#   ./patch.sh status      状態確認
#   ./patch.sh help        ヘルプ
#
# 動作:
#   1. インストール済み opencode のバージョンを検出
#   2. 一致するソースを GitHub から clone
#   3. パッチを適用
#   4. ビルドして binary を差し替え
#   5. 元の binary は backup として保存
# ===========================================================================
set -euo pipefail

TATEPATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$TATEPATCH_DIR/patches"
AUX_DIR="$TATEPATCH_DIR/aux"
WORK_DIR="${TATEPATCH_DIR}/_work"
BUNDLE_DIR="$WORK_DIR/bundle"
SOURCE_DIR="$WORK_DIR/source"

# インストール先 (opencode のパスを自動検出)
OPENCODE_BIN=""
if command -v opencode &>/dev/null; then
  OPENCODE_BIN="$(command -v opencode)"
fi
OPENCODE_DIR="$(dirname "$OPENCODE_BIN" 2>/dev/null || echo "")"

# ---------------------------------------------------------------------------
# ヘルパー
# ---------------------------------------------------------------------------
info()  { echo "  $1"; }
warn()  { echo "  WARNING: $1"; }
fail()  { echo "  FAILED: $1"; exit 1; }
header(){ echo ""; echo "==> $1"; }

cleanup() { rm -rf "$WORK_DIR" 2>/dev/null || true; }
trap cleanup EXIT

require_cmd() {
  if ! command -v "$1" &>/dev/null; then
    fail "Required command not found: $1"
  fi
}

# ---------------------------------------------------------------------------
# 状態確認
# ---------------------------------------------------------------------------
get_installed_version() {
  if [ -z "$OPENCODE_BIN" ]; then
    echo ""
    return
  fi
  "$OPENCODE_BIN" --version 2>/dev/null | head -1 | grep -oP '[\d]+\.[\d]+\.[\d]+' || echo ""
}

is_patched() {
  if [ -z "$OPENCODE_BIN" ]; then return 1; fi
  "$OPENCODE_BIN" --version 2>/dev/null | grep -q "(Tate Patched)"
}

# ---------------------------------------------------------------------------
# アンインストール (公式 binary に戻す)
# ---------------------------------------------------------------------------
unapply() {
  header "Unapplying patch — restoring official binary"

  if [ ! -f "$OPENCODE_BIN.backup" ]; then
    fail "No backup found at $OPENCODE_BIN.backup"
  fi

  cp "$OPENCODE_BIN.backup" "$OPENCODE_BIN"
  chmod +x "$OPENCODE_BIN"
  info "Restored backup binary."
  info "Version: $("$OPENCODE_BIN" --version 2>/dev/null || echo "?")"
}

# ---------------------------------------------------------------------------
# パッチ適用 + ビルド
# ---------------------------------------------------------------------------
do_patch() {
  header "Detecting opencode installation"
  if [ -z "$OPENCODE_BIN" ]; then
    fail "opencode not found in PATH. Install opencode first: curl -fsSL https://opencode.ai/install | bash"
  fi

  if is_patched; then
    info "Already patched: $("$OPENCODE_BIN" --version 2>/dev/null)"
    info "Run '$0 unapply' first to revert, then rerun."
    exit 0
  fi

  VERSION="$(get_installed_version)"
  if [ -z "$VERSION" ]; then
    fail "Cannot determine installed opencode version"
  fi
  info "Installed: v$VERSION at $OPENCODE_BIN"

  # 必要なツールの確認
  require_cmd git
  require_cmd bun

  # ソースの準備
  header "Preparing source code (v$VERSION)"
  rm -rf "$SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"

  info "Cloning opencode source at tag v$VERSION ..."
  git clone --depth 1 --branch "v$VERSION" \
    https://github.com/anomalyco/opencode.git "$SOURCE_DIR" 2>&1 | tail -3 || {
    fail "Failed to clone source. Check: v$VERSION tag exists on GitHub?"
  }

  cd "$SOURCE_DIR"

  # パッチの適用
  header "Applying patches"
  local ordered_patches=(
    "version.patch"
    "webapp-storage-proxy.patch"
    "auth-pool.patch"
    "ctrl-enter-send.patch"
    "remove-help-button.patch"
    "remove-share.patch"
    "remove-upsell.patch"
  )

  for patch_name in "${ordered_patches[@]}"; do
    local patch_file="$PATCHES_DIR/$patch_name"
    if [ -f "$patch_file" ]; then
      info "Applying $patch_name ..."
      if ! git apply "$patch_file" 2>/tmp/tatepatch_err.log; then
        fail "Patch failed: $patch_name\n$(cat /tmp/tatepatch_err.log)\nSource has changed — aborting."
      fi
    fi
  done

  # 依存関係のインストール
  header "Installing dependencies"
  bun install 2>&1 | tail -3

  # web app のビルド (binary に埋め込む)
  header "Building web app"
  OPENCODE_CHANNEL=prod \
  OPENCODE_VERSION="$VERSION" \
  bun run --cwd "$SOURCE_DIR/packages/app" build 2>&1 | tail -3

  # binary のビルド
  header "Building opencode binary"
  info "This may take a while..."
  OPENCODE_VERSION="$VERSION" \
  bun run "$SOURCE_DIR/packages/opencode/script/build.ts" --single 2>&1 | tail -5

  # ビルド成果物の検索
  local binary_path=""
  binary_path=$(find "$SOURCE_DIR/packages/opencode/dist" -name "opencode" -type f 2>/dev/null | head -1)
  if [ -z "$binary_path" ]; then
    fail "Build completed but binary not found in dist/"
  fi

  # バージョン確認
  info "Checking built binary version..."
  local built_version
  built_version="$("$binary_path" --version 2>/dev/null || true)"
  info "Built: $built_version"

  # インストール
  header "Installing patched binary"
  info "Backing up original to $OPENCODE_BIN.backup"
  cp "$OPENCODE_BIN" "$OPENCODE_BIN.backup"
  info "Installing patched binary"
  cp "$binary_path" "$OPENCODE_BIN"
  chmod +x "$OPENCODE_BIN"

  header "Installation complete!"
  info "Version: $("$OPENCODE_BIN" --version 2>/dev/null)"
  info ""
  info "(Tate Patched) が表示されていれば成功です。"
  info ""
  info "元の binary に戻す: $0 unapply"
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
case "${1:-apply}" in
  apply)
    do_patch
    ;;
  unapply|uninstall|revert)
    unapply
    ;;
  status)
    if [ -z "$OPENCODE_BIN" ]; then
      echo "Status: opencode not installed"
    elif is_patched; then
      echo "Status: PATCHED ($("$OPENCODE_BIN" --version 2>/dev/null))"
    else
      echo "Status: OFFICIAL ($("$OPENCODE_BIN" --version 2>/dev/null))"
    fi
    ;;
  help|--help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply           Apply tatepatch (default)"
    echo "  unapply         Restore official binary"
    echo "  status          Show patch status"
    echo "  help            Show this help"
    ;;
  *)
    echo "Unknown command: $1"
    echo "Usage: $0 [apply|unapply|status|help]"
    exit 1
    ;;
esac
