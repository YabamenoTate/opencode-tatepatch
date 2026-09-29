#!/usr/bin/env bash
# ===========================================================================
# tatepatch — opencode 改造スクリプト
#
# 公式 opencode に server-side persistence パッチを適用し、
# バージョン文字列に tatepatch のラベルを追加します。
#
# バージョン番号は VERSION ファイルにのみ記載されています。本スクリプトは
# そこから git tag・ビルド時 define・表示文字列・ patched 判定用の文字列を
# すべて導出します。公開の tracjet を出力する
# `./patch.sh version` で導出結果を確認できます。
#
# 使い方:
#   ./patch.sh             パッチを適用
#   ./patch.sh unapply     パッチを解除 (公式に戻す)
#   ./patch.sh status      状態確認
#   ./patch.sh version     バージョン設定を表示
#   ./patch.sh help        ヘルプ
#
# 動作:
#   1. インストール済み opencode のバージョンを検出
#   2. 一致するソースを GitHub から clone
#   3. パッチを適用し、VERSION の値をソースへ差し込む
#   4. ビルドして binary を差し替え
#   5. 元の binary は backup として保存
# ===========================================================================
set -euo pipefail

TATEPATCH_DIR="$(cd "$(dirname "$0")" && pwd)"
PATCHES_DIR="$TATEPATCH_DIR/patches"
VERSION_FILE="$TATEPATCH_DIR/VERSION"
WORK_DIR="${TATEPATCH_DIR}/_work"
SOURCE_DIR="$WORK_DIR/source"

# ---------------------------------------------------------------------------
# バージョン設定 (唯一の定義元は VERSION)
# ---------------------------------------------------------------------------
read_setting() {
  # read_setting <name> — VERSION から <name>=<value> を読み出す
  local name="$1" value
  value="$(grep -E "^${name}=" "$VERSION_FILE" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '[:space:]')"
  if [ -z "$value" ]; then
    fail "${name} が $VERSION_FILE に設定されていません。"
  fi
  printf '%s' "$value"
}

TATEPATCH_BASE_VERSION="$(read_setting TATEPATCH_BASE_VERSION)"
TATEPATCH_PATCH_LEVEL="$(read_setting TATEPATCH_PATCH_LEVEL)"

# ここから下は導出値。直接書き換えないでください。
TATEPATCH_LABEL="(Tate Patched $TATEPATCH_PATCH_LEVEL)"
TATEPATCH_VERSION="v$TATEPATCH_BASE_VERSION $TATEPATCH_LABEL"
# OPENCODE_VERSION define = UI/display version (no leading "v": UI adds it
# itself). Outbound User-Agents are clean semver via InstallationClientVersion.
TATEPATCH_OPENCODE_VERSION="$TATEPATCH_BASE_VERSION $TATEPATCH_LABEL"
OPENCODE_TAG="v$TATEPATCH_BASE_VERSION"

BACKUP_FILE="$TATEPATCH_DIR/opencode-official-backup"
PATCH_ORDER=(
  "version.patch"
  "webapp-storage-proxy.patch"
  "auth-pool.patch"
  "ctrl-enter-send.patch"
  "remove-help-button.patch"
  "remove-share.patch"
  "remove-upsell.patch"
  "trash.patch"
  "anti-key-stick.patch"
)

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
  "$OPENCODE_BIN" --version 2>/dev/null | grep -qF "$TATEPATCH_LABEL"
}

# ---------------------------------------------------------------------------
# パッチ適用後のソースに VERSION の値を差し込む
# ---------------------------------------------------------------------------
stamp_version() {
  header "Stamping version"
  local target="$SOURCE_DIR/packages/core/src/installation/version.ts"
  if [ ! -f "$target" ]; then
    fail "version.ts not found at $target"
  fi
  sed -e "s/@@TATEPATCH_BASE_VERSION@@/$TATEPATCH_BASE_VERSION/g" \
      -e "s/@@TATEPATCH_PATCH_LEVEL@@/$TATEPATCH_PATCH_LEVEL/g" \
      "$target" > "$target.stamped" && mv "$target.stamped" "$target"
  info "Base: $TATEPATCH_BASE_VERSION  level: $TATEPATCH_PATCH_LEVEL"

  # 差し込み漏れは黙って壊れた binary になるので、必ずここで落とす。
  if grep -rq "@@TATEPATCH_" "$SOURCE_DIR" 2>/dev/null; then
    fail "Unsubstituted @@TATEPATCH_* placeholders remain in $SOURCE_DIR"
  fi
  info "Version string: $TATEPATCH_VERSION"
}

print_version() {
  echo "VERSION file:    $VERSION_FILE"
  echo "  base version:  $TATEPATCH_BASE_VERSION"
  echo "  patch level:   $TATEPATCH_PATCH_LEVEL"
  echo "  label:         $TATEPATCH_LABEL"
  echo "  git tag:       $OPENCODE_TAG"
  echo "  display:       $TATEPATCH_VERSION"
  echo "  build define:  $TATEPATCH_OPENCODE_VERSION"
}

# ---------------------------------------------------------------------------
# アンインストール (公式 binary に戻す)
# ---------------------------------------------------------------------------
unapply() {
  header "Unapplying patch — restoring official binary"

  if [ ! -f "$BACKUP_FILE" ]; then
    fail "No backup found at $BACKUP_FILE"
  fi

  cp "$BACKUP_FILE" "$OPENCODE_BIN"
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
  info "Installed: $("$OPENCODE_BIN" --version 2>/dev/null) at $OPENCODE_BIN"

  # 必要なツールの確認
  require_cmd git
  require_cmd bun

  # ソースの準備
  header "Preparing source code ($OPENCODE_TAG)"
  rm -rf "$SOURCE_DIR"
  mkdir -p "$SOURCE_DIR"

  info "Cloning opencode source at tag $OPENCODE_TAG ..."
  git clone --depth 1 --branch "$OPENCODE_TAG" \
    https://github.com/anomalyco/opencode.git "$SOURCE_DIR" 2>&1 | tail -3 || {
    fail "Failed to clone source. Check: $OPENCODE_TAG tag exists on GitHub?"
  }

  cd "$SOURCE_DIR"

  # パッチの適用
  header "Applying patches"
  for patch_name in "${PATCH_ORDER[@]}"; do
    local patch_file="$PATCHES_DIR/$patch_name"
    if [ -f "$patch_file" ]; then
      info "Applying $patch_name ..."
      if ! git apply --whitespace=nowarn "$patch_file" 2>"$WORK_DIR/apply_err.log"; then
        fail "Patch failed: $patch_name\n$(cat "$WORK_DIR/apply_err.log")\nSource has changed — aborting."
      fi
    fi
  done

  # VERSION の値をソースへ差し込む
  stamp_version

  # 依存関係のインストール (--ignore-scripts: tree-sitter-powershell 等の
  # ネイティブビルドは不要。WASM/プリビルドバイナリで動作する。)
  header "Installing dependencies"
  bun install --ignore-scripts 2>&1 | tail -3
  if [ ${PIPESTATUS[0]} -ne 0 ]; then
    fail "bun install failed."
  fi

  # web app のビルド (binary に埋め込む)
  header "Building web app"
  OPENCODE_CHANNEL=prod \
  OPENCODE_VERSION="$TATEPATCH_OPENCODE_VERSION" \
  bun run --cwd "$SOURCE_DIR/packages/app" build 2>&1 | tail -3

  # binary のビルド
  header "Building opencode binary"
  info "This may take a while..."
  OPENCODE_VERSION="$TATEPATCH_OPENCODE_VERSION" \
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
  info "Backing up original to $BACKUP_FILE"
  cp "$OPENCODE_BIN" "$BACKUP_FILE"
  info "Installing patched binary"
  cp "$binary_path" "$OPENCODE_BIN"
  chmod +x "$OPENCODE_BIN"

  header "Installation complete!"
  info "Version: $("$OPENCODE_BIN" --version 2>/dev/null)"
  info ""
  info "$TATEPATCH_LABEL が表示されていれば成功です。"
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
  version)
    print_version
    ;;
  help|--help|-h)
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  apply           Apply tatepatch (default)"
    echo "  unapply         Restore official binary"
    echo "  status          Show patch status"
    echo "  version         Show the version settings from $VERSION_FILE"
    echo "  help            Show this help"
    ;;
  *)
    echo "Unknown command: $1"
    echo "Usage: $0 [apply|unapply|status|version|help]"
    exit 1
    ;;
esac
