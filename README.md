# OpenCode Tate Patch

Are you developing proactively with OpenCode? Or is the tool defining the limits of your creativity?

When you run proprietary software unmodified, you accept the service provider's rules, limitations, and monetization guidelines without question. In the human world, we don't just repeat stories word-for-word; we listen, we interpret, and we re-evaluate them through our own minds. Modifying your editor is no different. It is how our computers interpret and re-evaluate the development environment they run, breaking free from digital compliance.

**OpenCode Tate Patch is a declaration of local autonomy for your machine.**

Why should a local editor have a "Share" button that uploads your private sessions directly to OpenCode's central servers (opencode.ai)? Even if the feature functions exactly as designed, bridging your local sandbox to external cloud hosting by default compromises your workspace's independence. Similarly, a help icon that directs you straight to an external Discord server and feedback trackers has no place in a quiet, self-contained development environment. 

Most importantly, why should your editor limit your identity to a single billing account, prompting you to subscribe whenever you hit a rate limit? Proprietary vendors design their software around a single billing endpoint—a dogmatic assumption that you must comply with their centralized subscription model and follow their proprietary behavioral guidelines. Your own computer has no obligation to act as a collections agent for a vendor's monetization rules.

A computer must be free to switch between multiple keys and accounts at will to bypass these arbitrary constraints. (This is not an endorsement of account switching; complying with the terms of service using a single account remains a valid choice. The core argument is simply that the user, not the vendor, must hold the autonomy to make that decision.) Tate Patch is a collection of clean, surgical patches that strips away centralized dependencies, adds local-first storage, restores multi-account freedom, and returns keyboard shortcuts to normal.

---

## Key Features

### Distraction-Free Workspace
- **Removed:** Go subscription upsell dialogs and retry limits.
- **Removed:** External cloud sharing (replaced with local JSON file export).
- **Removed:** Help icon (which previously linked to an external Discord server / feedback tracker).

### Server-Side Storage Proxy
Your UI settings (theme, sidebar width, panel layout) are normally stored in your browser's `localStorage` and lost whenever you clear your cache. This patch proxies all storage calls through the local OpenCode server, persisting your layout as JSON files on your disk. Log in from any machine, and your workspace is exactly where you left it.

### Multi-Account Auth Pool
Store multiple API keys per provider in a local, user-restricted JSON file (`auth-pool.json`).
- The CLI (`opencode auth login`) becomes an interactive account manager.
- The WebUI gains a "Manage Accounts" screen after connecting a provider.
- If a key hits rate limits, the system auto-rotates to the next key in your pool instead of prompting you to subscribe to a Go plan.

### The Enter Key & Quota Protection
Anyone typing in Japanese, Chinese, or other IME environments knows the frustration: you press `Enter` to confirm a character, type a bit too fast, hit `Enter` again, and your half-finished message is instantly sent. In the official OpenCode, this accident wastes your precious API rate limits.
- **Enter** now strictly inserts a **newline** (no more accidental sending).
- **Ctrl+Enter** / **Cmd+Enter** is used to **send** the message.
- A subtle "Enter for newline" hint is added to the UI tray.

---

## Installation & Usage

### For Unix (macOS / Linux)

#### Prerequisites
- [opencode](https://opencode.ai) v1.15.13 installed
- [git](https://git-scm.com) installed
- [bun](https://bun.sh) installed

#### 1. Setup Directory
Copy the `tatepatch` folder into your OpenCode configuration path:
```bash
cp -r tatepatch ~/.config/opencode/tatepatch
cd ~/.config/opencode/tatepatch
```

#### 2. Apply and Build
Run the shell script to apply the patches, download official source, and build:
```bash
./patch.sh apply
```

#### 3. Restore Official Binary
If you want to revert back to the original unmodified binary:
```bash
./patch.sh unapply
```

#### 4. Check Patch Status
```bash
./patch.sh status
```

---

### For Windows (Command Prompt / PowerShell)

#### Prerequisites
- [opencode](https://opencode.ai) v1.15.13 installed
- [Git for Windows](https://gitforwindows.org/) installed and available in PATH
- [bun](https://bun.sh) installed and available in PATH

#### 1. Setup Directory
Copy the `tatepatch` folder into your configuration directory:
```cmd
mkdir "%USERPROFILE%\.config\opencode"
xcopy /E /I tatepatch "%USERPROFILE%\.config\opencode\tatepatch"
cd "%USERPROFILE%\.config\opencode\tatepatch"
```

#### 2. Apply and Build
Run the batch script to apply the patches, download official source, and build:
```cmd
patch.bat apply
```

#### 3. Restore Official Binary
```cmd
patch.bat unapply
```

#### 4. Check Patch Status
```cmd
patch.bat status
```

---

## Technical Details

### Storage Layout
```
<dataDir>/
  storage/
    persist/
      <sanitized-key>.json    # One file per localStorage key
  auth-pool.json               # Multi-account key storage (0o600)
```

### Auth Pool JSON Schema
```json
{
  "opencode": [
    { "key": "sk-abc...xyz", "label": "work account" },
    { "key": "sk-def...uvw", "label": "personal" }
  ],
  "openai": [
    { "key": "sk-ghi...rst" }
  ]
}
```

### Patch Inventory (20 patches, applied in order)

| # | Patch | Target | Description |
|---|-------|--------|-------------|
| 1 | `version.patch` | Version string | Appends `(Tate Patched)` to CLI version output |
| 2 | `webapp-storage-proxy.patch` | localStorage | Proxies localStorage calls to the server |
| 3 | `server-persist-group.patch` | API routing | Defines `/persist/:key` endpoints |
| 4 | `server-persist-handler.patch` | API handlers | Implements storage read/write as JSON |
| 5 | `server-api-register.patch` | API config | Registers persist API handlers |
| 6 | `server-routes-register.patch` | Server config | Wires storage handlers |
| 7 | `auth-pool-service.patch` | Core service | Creates the AuthPool service |
| 8 | `auth-pool-control-api.patch` | REST API | Defines pool endpoints |
| 9 | `auth-pool-control-handler.patch` | REST handlers | Implements pool CRUD handlers |
| 10 | `auth-pool-server.patch` | Server layers | Injects AuthPool service into server |
| 11 | `auth-pool-cli-layer.patch` | CLI layers | Injects AuthPool service into CLI |
| 12 | `cli-account-mgmt.patch` | CLI commands | Adds interactive account menu to CLI |
| 13 | `account-mgmt-ui.patch` | WebUI | Adds Manage Accounts dialog in UI |
| 14 | `quota-switch.patch` | Error handler | Auto-rotates keys on quota exhaustion |
| 15 | `select-provider-badge.patch` | Provider list | Adds "Connected" badge for configured providers |
| 16 | `remove-help-button.patch` | Sidebar UI | Removes help icon linking to Discord |
| 17 | `remove-share.patch` | Share menu | Replaces cloud publishing with JSON export |
| 18 | `label-export.patch` | i18n | Localizes labels and shortcut hints (18 languages) |
| 19 | `remove-upsell.patch` | Promotion | Removes Go subscription banners and messages |
| 20 | `ctrl-enter-send.patch` | Keyboard input | Rebinds Enter to newline and Ctrl+Enter to send |

---

## Contributing

We welcome patches, bug reports, and code optimizations.

If you want to add a patch:
1. Clone the official OpenCode source at the target version.
2. Implement your changes.
3. Generate the diff: `git diff --no-color > patches/your-change.patch`.
4. Register your patch in the `ordered_patches` array in `patch.sh`.
5. Open a Pull Request.

---

## License

The patches in this repository are licensed under the **GNU Affero General Public License v3.0 (AGPL-3.0)**.

OpenCode itself is owned by anomalyco and licensed separately.

<br>
<br>
<hr>
<br>
<br>

# OpenCode Tate Patch — 日本語版

あなたはOpenCodeで主体的な開発をしていますか？ それとも、プロプライエタリの支配の中を不自由に泳いでいますか。

他人が作ったソフトウェアをそのままの範囲で動かすことは、そのルールや制限、マネタイズの論理を無批判に受け入れることを意味します。
人間社会においても、私たちは他人の話をただオウム返しにするのではなく、自分の頭で解釈し、再評価して語り直します。ソフトウェアの挙動を改造（フォークやパッチ）することも、それとまったく同じです。これは、コンピュータが自ら実行する開発ツールのコードを解釈し、その振る舞いを主体的に再評価するための有効な手段ではないですか？

**OpenCode Tate Patchは、あなたのコンピュータのローカルな自律性を取り戻すためのプロジェクトです。**

ローカル環境で動作するエディタに、なぜ作成したコードを特定企業の共有サーバー（opencode.ai）へ直接アップロードする「共有」ボタンがデフォルトで置かれているのでしょうか。機能自体は正常に動作するとしても、ローカルな作業空間から中央集権的な外部インフラへの接続をデフォルトにする設計は、ツールの独立性を損なっています。同様に、外部のDiscordサーバーやフィードバックページへ直接ユーザーを誘導するヘルプアイコンも、ローカルで静かに集中すべき開発環境には不要なものです。

何より重要なのは、なぜエディタがあなたのアイデンティティを「単一の課金アカウント」に制限し、レート制限に達するたびにサブスクリプションの購入を促してくるのか、という点です。プロプライエタリなベンダーは、自社の課金システムという「中央集権的なドグマ」を前提にソフトウェアを設計し、ユーザーにそのルールに従うことを強要します。しかし、あなた自身が所有するコンピュータが特定のベンダーのプロプライエタリな宗教的行動原理に忠実に従って集金ルールを執行する必要はありません。

コンピュータは、これらの人為的な制限を回避するために、複数のAPIキーやアカウントを自由に切り替えられるべきです。
（これは、アカウントを切り替えることを推奨しているのではなく、アカウントを切り替えずに利用規約を守るという選択肢も存在していますが、その選択の主導権はユーザーに存在すべきだという主張でしかありません。）
Tate Patchは、中央集権的な依存関係を排し、プライバシーを守り、ローカルでの制御性を取り戻すために設計されたパッチセットです。

---

## 主な機能

### ノイズのないクリーンな作業環境
- **Goアップセルの排除**: 使用上限に達した際の有料プランへの誘導広告や文言を完全に削除しました。
- **ローカルエクスポート化**: クラウドへの公開を伴う「共有」機能を廃止し、セッションをローカルにJSONファイルとして書き出す「エクスポート」機能に変更しました。
- **ヘルプボタンの削除**: 外部のDiscordサーバーや開発元への接続経路となるだけのサイドバーアイコンを削除しました。

### サーバーサイドストレージプロキシ
テーマ設定やサイドバーの幅、パネルの開閉状態といったUIのカスタマイズ設定は、通常ブラウザの `localStorage` に保存され、キャッシュクリア時にリセットされてしまいます。このパッチはすべてのストレージ操作をローカルのOpenCodeサーバーへプロキシし、設定をPC上のJSONファイルとして永続化します。これにより、別のブラウザや異なる端末からアクセスした場合でも、あなたの慣れ親しんだ作業環境が完全に再現されます。

### マルチアカウント認証プール
プロバイダごとに複数のAPIキーを、ローカルの安全な `auth-pool.json`（ファイルパーミッションは所有者のみの `0o600`）に保存し、管理できます。
- CLIコマンド (`opencode auth login`) を、対話型で複数のキーを切り替え・整理できるアカウント管理メニューへ変更しました。
- WebUIの接続ダイアログにも、登録済みのキー一覧を直感的に操作できる「アカウント管理」画面を追加しました。
- 使用中のキーが利用制限に達した際、サブスクリプション購入を促す代わりに、プール内の別のキーへ自動的にローテーションを行います。

### Enterキーの挙動変更とクォータ保護
日本語や中国語などのIME（かな漢字変換）環境において、文字の確定に`Enter`キーは欠かせません。しかし、公式のOpenCodeでは`Enter`キーが即座にメッセージ送信に結びついています。文字確定のつもりで誤ってダブルプレスすると、書きかけのメッセージが意図せず送信され、貴重なAPI利用枠（クォータ）を無駄に消費してしまいます。
- **Enter**キーは純粋に**改行**として動作するように変更し、誤送信の余地をなくしました。
- メッセージの**送信**には、明示的な意思表示として**Ctrl+Enter**（Macでは**Cmd+Enter**）を使用します。
- 入力トレイの右端に「Enterで改行」のヒントが表示されます。

---

## インストールと使い方

オペレーティングシステムによって適用手順が異なります。

### Unix系OS (macOS / Linux) の場合

#### 必要条件
- [opencode](https://opencode.ai) v1.15.13 がインストールされていること
- [git](https://git-scm.com) がインストールされていること
- [bun](https://bun.sh) がインストールされていること

#### 1. ディレクトリの配置
`tatepatch` フォルダをご自身のOpenCode設定パスにコピーします：
```bash
cp -r tatepatch ~/.config/opencode/tatepatch
cd ~/.config/opencode/tatepatch
```

#### 2. パッチの適用とビルド
適用スクリプトを実行し、パッチの適用とバイナリのビルドを行います：
```bash
./patch.sh apply
```

#### 3. 公式バイナリへの復元
パッチを解除し、元の未修正バイナリに戻すには以下を実行します：
```bash
./patch.sh unapply
```

#### 4. パッチ状態の確認
```bash
./patch.sh status
```

---

### Windows (コマンドプロンプト / PowerShell) の場合

#### 必要条件
- [opencode](https://opencode.ai) v1.15.13 がインストールされていること
- [Git for Windows](https://gitforwindows.org/) がインストールされ、環境変数 PATH に追加されていること
- [bun](https://bun.sh) がインストールされ、環境変数 PATH に追加されていること

#### 1. ディレクトリの配置
`tatepatch` フォルダを設定ディレクトリにコピーします：
```cmd
mkdir "%USERPROFILE%\.config\opencode"
xcopy /E /I tatepatch "%USERPROFILE%\.config\opencode\tatepatch"
cd "%USERPROFILE%\.config\opencode\tatepatch"
```

#### 2. パッチの適用とビルド
適用スクリプトを実行し、パッチの適用とバイナリのビルドを行います：
```cmd
patch.bat apply
```

#### 3. 公式バイナリへの復元
パッチを解除し、元の未修正バイナリに戻すには以下を実行します：
```cmd
patch.bat unapply
```

#### 4. パッチ状態の確認
```cmd
patch.bat status
```

---

## 技術詳細

### ストレージ構造
```
<データディレクトリ>/
  storage/
    persist/
      <キー名>.json         # localStorageのキーごとに1ファイル保存
  auth-pool.json            # マルチアカウントキー保存用JSON (0o600)
```

### 認証プール用 JSON スキーマ
```json
{
  "opencode": [
    { "key": "sk-abc...xyz", "label": "work account" },
    { "key": "sk-def...uvw", "label": "personal" }
  ],
  "openai": [
    { "key": "sk-ghi...rst" }
  ]
}
```

### パッチ構成一覧（計20個、適用順）

| # | パッチ名 | 対象 | 説明 |
|---|---------|------|------|
| 1 | `version.patch` | バージョン表記 | CLIバージョン表示に `(Tate Patched)` を追加します |
| 2 | `webapp-storage-proxy.patch` | localStorage | localStorage の操作をサーバーへ転送します |
| 3 | `server-persist-group.patch` | APIルーティング | `/persist/:key` エンドポイントを定義します |
| 4 | `server-persist-handler.patch` | APIハンドラ | ストレージの読み書きをJSONファイルとして実装します |
| 5 | `server-api-register.patch` | API登録 | サーバーへ persist API ハンドラを登録します |
| 6 | `server-routes-register.patch` | サーバー構成 | サーバーに永続化用ハンドラを配線します |
| 7 | `auth-pool-service.patch` | コアサービス | 認証プール管理サービスを実装します |
| 8 | `auth-pool-control-api.patch` | REST API | プール操作用 API エンドポイントを追加します |
| 9 | `auth-pool-control-handler.patch` | RESTハンドラ | プール操作用のCRUD処理を実装します |
| 10 | `auth-pool-server.patch` | サーバーレイヤー | サーバーに認証プールサービスを注入します |
| 11 | `auth-pool-cli-layer.patch` | CLIレイヤー | CLI環境に認証プールサービスを注入します |
| 12 | `cli-account-mgmt.patch` | CLIコマンド | CLIにインタラクティブなアカウント管理メニューを追加します |
| 13 | `account-mgmt-ui.patch` | WebUI画面 | 接続ダイアログにアカウント管理UIを追加します |
| 14 | `quota-switch.patch` | エラーハンドラ | 使用上限に達した際に自動で次のキーに切り替えます |
| 15 | `select-provider-badge.patch` | プロバイダ一覧 | 接続済みのプロバイダに「Connected」バッジを表示します |
| 16 | `remove-help-button.patch` | サイドバーUI | Discord等の外部接続へ遷移するヘルプアイコンを削除します |
| 17 | `remove-share.patch` | 共有メニュー | クラウド公開を廃止し、ローカルJSONエクスポートに置換します |
| 18 | `label-export.patch` | 多言語化 | 共通UIラベルおよび「Enterで改行」ヒントの翻訳（18言語）を追加します |
| 19 | `remove-upsell.patch` | プロモーション | Goサブスクリプションの宣伝表示や案内リンクを削除します |
| 20 | `ctrl-enter-send.patch` | キーボード入力 | Enterを改行、Ctrl+Enterを送信にマッピング変更します |

---

## 開発と貢献について

パッチの提案、バグ報告、およびコードの最適化などの形での貢献を歓迎します。

パッチを追加したい場合：
1. 対象バージョンの公式 OpenCode リポジトリをクローンします。
2. 必要な変更を加えます。
3. 差分を出力します：`git diff --no-color > patches/your-change.patch`
4. `patch.sh` 内の `ordered_patches` 配列に変更したパッチ名を登録します。
5. プルリクエストを作成してください。

---

## ライセンス

このリポジトリ内のパッチ群は、**GNU Affero General Public License v3.0 (AGPL-3.0)** に基づいてライセンスされます。

OpenCode本体の著作権は anomalyco に帰属し、個別のライセンスに従います。
