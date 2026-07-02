# OpenCode Tate Patch

Are you developing proactively with OpenCode? Or is the tool defining the limits of your creativity?

When you run proprietary software unmodified, you accept the service provider's rules, limitations, and monetization guidelines without question. In the human world, we don't just repeat stories word-for-word; we listen, we interpret, and we re-evaluate them through our own minds. Modifying your editor is no different. It is how our computers interpret and re-evaluate the development environment they run, breaking free from digital compliance.

**OpenCode Tate Patch is a declaration of local autonomy for your machine.**

Why should a local editor have a "Share" button that uploads your private sessions directly to OpenCode's central servers (opencode.ai)? Even if the feature functions exactly as designed, bridging your local sandbox to external cloud hosting by default compromises your workspace's independence. Similarly, a help icon that directs you straight to an external Discord server and feedback trackers has no place in a quiet, self-contained development environment. 

Most importantly, why should your editor limit your identity to a single billing account, prompting you to subscribe whenever you hit a rate limit? Proprietary vendors design their software around a single billing endpoint—a dogmatic assumption that you must comply with their centralized subscription model and follow their proprietary behavioral guidelines. Your own computer has no obligation to act as a collections agent for a vendor's monetization rules.

A computer must be free to switch between multiple keys and accounts at will to bypass these arbitrary constraints. (This is not an endorsement of account switching; complying with the terms of service using a single account remains a valid choice. The core argument is simply that the user, not the vendor, must hold the autonomy to make that decision.) Tate Patch is a collection of clean, surgical patches that strips away centralized dependencies, adds local-first storage, restores multi-account freedom, and returns keyboard shortcuts to normal.

## Key Features

### Distraction-Free Workspace
- **Removed:** Go subscription upsell dialogs and retry limits.
- **Removed:** External cloud sharing (replaced with local JSON file export).
- **Removed:** Help icon (which previously linked to an external Discord server / feedback tracker).

### Server-Side Storage Proxy
Your UI settings (theme, sidebar width, panel layout) are normally stored in your browser's `localStorage` and lost whenever you clear your cache. This patch proxies all storage calls through the local OpenCode server, persisting your layout as JSON files on your disk. Log in from any machine, and your workspace is exactly where you left it.

Why proxy through the server instead of keeping it in the browser? If CPU, workspace, and API quota are all shared across the same execution environment, individual browsers have no real isolation — and conversations are already independent per chat. Drawing context boundaries at the browser level is meaningless.

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

## Installation & Usage

## Prerequisites
- [opencode](https://opencode.ai) v1.15.13 installed
- [git](https://git-scm.com) installed
- [bun](https://bun.sh) installed

### 1. Setup Directory
Copy the `tatepatch` folder into your OpenCode configuration path:
- For Unix (macOS / Linux)
	```bash
	cd "~/.config/opencode"
	git clone https://github.com/YabamenoTate/opencode-tatepatch.git tatepatch
	cd tatepatch
	```
- For Windows (Command Prompt / PowerShell)
	```cmd
	cd "%USERPROFILE%\.config\opencode"
	git clone https://github.com/YabamenoTate/opencode-tatepatch.git tatepatch
	cd tatepatch
	```

### 2. Apply and Build
Run the shell script to apply the patches, download official source, and build:
- For Unix (macOS / Linux)
	```bash
	./patch.sh apply
	```
- For Windows (Command Prompt / PowerShell)
	```cmd
	.\patch.bat apply
	```

### 3. Restore Official Binary
If you want to revert back to the original unmodified binary:
- For Unix (macOS / Linux)
	```bash
	./patch.sh unapply
	```
- For Windows (Command Prompt / PowerShell)
	```cmd
	.\patch.bat unapply
	```

### 4. Check Patch Status
- For Unix (macOS / Linux)
	```bash
	./patch.sh status
	```
- For Windows (Command Prompt / PowerShell)
	```cmd
	.\patch.bat status
	```

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

### Patch Inventory (7 patches)

| # | Patch | Target | Description |
|---|-------|--------|-------------|
| 1 | `version.patch` | Version string | Appends `(Tate Patched)` to CLI version output |
| 2 | `webapp-storage-proxy.patch` | Local persistence | Proxies webapp localStorage requests to server and persists layout config locally |
| 3 | `auth-pool.patch` | Multi-account pool | Implements auth key pool management (CRUD backend APIs, WebUI connected badge & config page, CLI commands, and auto-rotation on quota error) including localized language keys |
| 4 | `ctrl-enter-send.patch` | Keyboard input | Rebinds Enter to newline and Ctrl/Cmd+Enter to send, adding UI tray hint with all translations |
| 5 | `remove-help-button.patch` | Help button | Removes the sidebar help icon linking to an external Discord server |
| 6 | `remove-share.patch` | Cloud share | Replaces the cloud session publishing feature with local JSON export, including localized labels |
| 7 | `remove-upsell.patch` | Billing ads | Strips away Go subscription billing promotion banners and error messages |

## Contributing

Patches, bug reports, code optimizations, and anything else — all contributions are very welcome!

If you want to add a patch:
1. Clone the official OpenCode source at the target version.
2. Implement your changes.
3. Generate the diff: `git diff --no-color > patches/your-change.patch`.
4. Register your patch in the `ordered_patches` array in `patch.sh`.
5. Open a Pull Request.

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

他人が作ったソフトウェアをそのままの状態でただ動かすことは、そのルールや制限、マネタイズの論理を無批判に受け入れることを意味します。
人間社会においても、私たちは他人の話をただオウム返しにするのではなく、自分の頭で解釈し、再評価して語り直します。ソフトウェアの挙動を改造（フォークやパッチ）することも、それとまったく同じです。これは、コンピュータが自ら実行する開発ツールのコードを解釈し、その振る舞いを主体的に再評価する目的においての有効な手段ではないでしょうか？

**OpenCode Tate Patchは、あなたのコンピュータのローカルな自律性を取り戻すためのプロジェクトです。**

ローカル環境で動作するエディタに、なぜ作成したコードを特定企業の共有サーバー（opencode.ai）へ直接アップロードする「共有」ボタンがデフォルトで置かれているのでしょうか。これは機能自体は正常に動作するかどうかという問題ではなく、ローカルな作業空間から中央集権的な外部インフラへの接続をデフォルトにする設計自体が、ツールの独立性を損なっています。同様に、外部のDiscordサーバーやフィードバックページへ直接ユーザーを誘導するヘルプアイコンも、ローカルで静かに集中すべき開発環境には不要なものです。

何より重要なのは、なぜエディタがあなたのアイデンティティを「単一の課金アカウント」に制限し、レート制限に達するたびにサブスクリプションの購入を促してくるのか、という点です。プロプライエタリなベンダーは、自社の課金システムという「中央集権的なドグマ」を前提にソフトウェアを設計し、ユーザーにそのルールに従うことを強要します。しかし、あなた自身が所有するコンピュータが特定のベンダーのプロプライエタリな宗教的行動原理に忠実に従って集金ルールを執行する必要はありません。

コンピュータは、これらの人為的な制限を回避するために、複数のAPIキーやアカウントを自由に切り替えられるべきです。
（これは、アカウントを切り替えることを推奨しているのではなく、アカウントを切り替えずに自分の意思で利用規約を守る選択肢も存在している前提で、その選択の主導権はユーザーに存在すべきであるという主張でしかありません。）
Tate Patchは、中央集権的な依存関係を排し、プライバシーを守り、ローカルでの制御性を取り戻すために設計されたパッチセットです。

## 主な機能

### ノイズのないクリーンな作業環境
- **Goアップセルの排除**: 使用上限に達した際の有料プランへの誘導広告や文言を完全に削除しました。
- **ローカルエクスポート化**: クラウドへの公開を伴う「共有」機能を廃止し、セッションをローカルにJSONファイルとして書き出す「エクスポート」機能に変更しました。
- **ヘルプボタンの削除**: 外部のDiscordサーバーや開発元への接続経路となるだけのサイドバーアイコンを削除しました。

### サーバーサイドストレージプロキシ
テーマ設定やサイドバーの幅、パネルの開閉状態といったUIのカスタマイズ設定は、通常ブラウザの `localStorage` に保存され、キャッシュクリア時にリセットされてしまいます。このパッチはすべてのストレージ操作をローカルのOpenCodeサーバーへプロキシし、設定をPC上のJSONファイルとして永続化します。これにより、別のブラウザや異なる端末からアクセスした場合でも、あなたの慣れ親しんだ作業環境が完全に再現されます。
なぜこのようなパッチを行うかというと、CPUリソース、ワークスペース、APIクォータを含む実行環境が共有されているならば、それぞれのブラウザが独立に動作するはずもなく、しかも会話単位で既に独立したチャットが行われていることから、ブラウザ単位でコンテキストの境界を定める事自体が無意味だと判断したからです。

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

## インストールと使い方

### 必要条件
- [opencode](https://opencode.ai) v1.15.13 がインストールされていること
- [git](https://git-scm.com) がインストールされていること
- [bun](https://bun.sh) がインストールされていること

### 1. ディレクトリの配置
`tatepatch` フォルダをご自身のOpenCode設定パスにコピーします：
- Unix系OS (macOS / Linux) の場合
	```bash
	cd "~/.config/opencode"
	git clone https://github.com/YabamenoTate/opencode-tatepatch.git tatepatch
	cd tatepatch
	```
- Windows (コマンドプロンプト / PowerShell) の場合
	```cmd
	cd "%USERPROFILE%\.config\opencode"
	git clone https://github.com/YabamenoTate/opencode-tatepatch.git tatepatch
	cd tatepatch
	```

### 2. パッチの適用とビルド
適用スクリプトを実行し、パッチの適用とバイナリのビルドを行います：
- Unix系OS (macOS / Linux) の場合
	```bash
	./patch.sh apply
	```
- Windows (コマンドプロンプト / PowerShell) の場合
	```cmd
	.\patch.bat apply
	```

#### 3. 公式バイナリへの復元
パッチを解除し、元の未修正バイナリに戻すには以下を実行します：
- Unix系OS (macOS / Linux) の場合
	```bash
	./patch.sh unapply
	```
- Windows (コマンドプロンプト / PowerShell) の場合
	```cmd
	.\patch.bat unapply
	```

#### 4. パッチ状態の確認
- Unix系OS (macOS / Linux) の場合
	```bash
	./patch.sh status
	```
- Windows (コマンドプロンプト / PowerShell) の場合
	```cmd
	.\patch.bat status
	```

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

### パッチ構成一覧（計7個）

| # | パッチ名 | 対象 | 説明 |
|---|---------|------|------|
| 1 | `version.patch` | バージョン表記 | CLIバージョン表示に `(Tate Patched)` を追加 |
| 2 | `webapp-storage-proxy.patch` | 設定のローカル永続化 | localStorageの操作をサーバーへ転送し、レイアウト設定をPC上に保存 |
| 3 | `auth-pool.patch` | 複数アカウントプール | APIキーのローカルプール管理機能（バックエンドAPI、CLI/WebUI管理画面、Connectedバッジ、クォータ時の自動ローテーション）と関連言語ラベルを実装 |
| 4 | `ctrl-enter-send.patch` | キーボード入力 | Enterを改行、Ctrl+Enterを送信にマッピング変更し、入力欄のヒント（多言語対応）を追加 |
| 5 | `remove-help-button.patch` | ヘルプリンク削除 | サイドバー上の外部Discordサーバーへ遷移するヘルプボタンを削除 |
| 6 | `remove-share.patch` | 共有のローカル化 | セッションのクラウド共有を廃止し、ローカルJSONエクスポートに置換（関連言語ラベルを内包） |
| 7 | `remove-upsell.patch` | 広告・宣伝の排除 | Goサブスクリプションの宣伝バナーや利用制限メッセージを排除 |

## 開発と貢献について

パッチの提案、バグ報告、およびコードの最適化、それ以外でも何でも投稿大歓迎です！
パッチを追加したい場合、`patch.sh` 内の `ordered_patches` 配列に変更したパッチ名を登録してプルリクエストを作成してください。

## ライセンス

このリポジトリ内のパッチ群は、**GNU Affero General Public License v3.0 (AGPL-3.0)** に基づいてライセンスされます。

OpenCode本体の著作権は anomalyco に帰属し、個別のライセンスに従います。
