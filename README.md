# OpenCode Tate Patch

Are you developing proactively with OpenCode? Or is the tool defining the limits of your creativity?

When you run proprietary software unmodified, you accept the service provider's rules, limitations, and monetization guidelines without question. In the human world, we don't just repeat stories word-for-word; we listen, we interpret, and we re-evaluate them through our own minds. Modifying your editor is no different. It is how our computers interpret and re-evaluate the development environment they run, breaking free from digital compliance.

**OpenCode Tate Patch is a declaration of local autonomy for your machine.**

Why should a local editor have a "Share" button that uploads your private sessions directly to OpenCode's central servers (opencode.ai)? Even if the feature functions exactly as designed, bridging your local sandbox to external cloud hosting by default compromises your workspace's independence. Similarly, a help icon that directs you straight to an external Discord server and feedback trackers has no place in a quiet, self-contained development environment. 

Most importantly, why should your editor limit your identity to a single billing account, prompting you to subscribe whenever you hit a rate limit? Proprietary vendors design their software around a single billing endpoint—a dogmatic assumption that you must comply with their centralized subscription model and follow their proprietary behavioral guidelines. Your own computer has no obligation to act as a collections agent for a vendor's monetization rules.

A computer must be free to switch between multiple keys and accounts at will to bypass these arbitrary constraints. (This is not an endorsement of account switching; complying with the terms of service using a single account remains a valid choice. The core argument is simply that the user, not the vendor, must hold the autonomy to make that decision.) Tate Patch is a collection of clean, surgical patches that strips away centralized dependencies, adds local-first storage, restores multi-account freedom, and returns keyboard shortcuts to normal.

## Key Features

### Distraction-Free Workspace
- **Removed:** Go subscription upsell dialogs, retry limits, and hard stops on quota errors.
- **Removed:** External cloud sharing (share button, menus, commands, and publishing UI).
- **Removed:** Help icon (which previously linked to an external Discord server / feedback tracker).

### Server-Side Storage Proxy
Your UI settings (theme, sidebar width, panel layout) are normally stored in your browser's `localStorage` and lost whenever you clear your cache. This patch proxies all storage calls through the local OpenCode server, persisting your layout as JSON files on your disk. Log in from any machine, and your workspace is exactly where you left it.

Why proxy through the server instead of keeping it in the browser? If CPU, workspace, and API quota are all shared across the same execution environment, individual browsers have no real isolation — and conversations are already independent per chat. Drawing context boundaries at the browser level is meaningless.

### Multi-Account Auth Pool
Store multiple API keys per provider in a local, user-restricted JSON file (`auth-pool.json`).
- The CLI (`opencode auth login`) becomes an interactive account manager.
- The WebUI gains a "Manage Accounts" screen after connecting a provider.
- Errors never hard-stop your session. The current key is retried once after ~2 seconds; only a second consecutive failure concludes the key is at fault, so the request rotates to the next pool key — which is tried immediately, with no forced wait.
- A very long retry hint (60s+) already counts as key exhaustion and rotates right away.
- Offline/network failures are never the key's fault: the same key keeps polling at a bounded backoff until connectivity returns.
- While offline, neither the WebUI nor the TUI stops: a temporary banner (オンライン復帰を待機しています) appears at the bottom of the conversation until the connection recovers.
- An empty provider reply is a stall, not a finish: the turn waits ~2 seconds and re-requests until a real reply arrives, so a conversation never ends silently.
- The same applies to a turn that stopped without delivering a visible answer — a tool call with no closing explanation, a stream cut off before any text arrived, or a generation truncated mid-answer by the length/output cap: none of these are "complete", and the model is re-requested until it actually finishes saying something.
- Even 4xx "client error" responses (400/404/...) are retried rather than assumed fatal.
- Single-account use keeps going too: `Retry-After` is honored and the session never hard-stops.

### The Enter Key & Quota Protection
Anyone typing in Japanese, Chinese, or other IME environments knows the frustration: you press `Enter` to confirm a character, type a bit too fast, hit `Enter` again, and your half-finished message is instantly sent. In the official OpenCode, this accident wastes your precious API rate limits.
- **Enter** now strictly inserts a **newline** (no more accidental sending).
- **Ctrl+Enter** / **Cmd+Enter** is used to **send** the message.
- A subtle "Enter for newline" hint is added to the UI tray.

### Home Trash (Archive) Management
Archived sessions are no longer hidden forever. The Home view gains a **Trash** toggle that lists archived sessions with **Restore** and **Delete** actions.
- Restore sends `archived: null` so the session returns to the regular list without losing its history.
- The server/schema accept a nullable `archived` timestamp for full round-trip restoration.

## Installation & Usage

## Prerequisites
- [opencode](https://opencode.ai) v1.18.31 installed
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

### Patch Inventory (9 patches)

| # | Patch | Target | Description |
|---|-------|--------|-------------|
| 1 | `version.patch` | Version split | Shows `(Tate Patched 5)` in UI (CLI `--version`, health, TUI), while outbound User-Agents identify as clean `opencode/1.18.31` via `InstallationClientVersion` |
| 2 | `webapp-storage-proxy.patch` | Local persistence | Proxies webapp localStorage requests to server and persists layout config locally |
| 3 | `auth-pool.patch` | Multi-account pool | Implements auth key pool management (CRUD backend APIs, WebUI connected badge & config page, CLI commands) with auto-rotation on quota or long waits and a no-hard-stop retry policy: offline shows a waiting banner (オンライン復帰を待機しています) in WebUI + CLI and keeps polling, empty provider replies auto-retry after ~2s until a real reply arrives, including localized language keys |
| 4 | `ctrl-enter-send.patch` | Keyboard input | Rebinds Enter to newline and Ctrl/Cmd+Enter to send, adding UI tray hint with all translations |
| 5 | `remove-help-button.patch` | Help button | Removes the sidebar help icon linking to an external Discord server |
| 6 | `remove-share.patch` | Cloud share | Removes the cloud session publishing feature entirely (menus, commands, share button) |
| 7 | `remove-upsell.patch` | Billing ads | Strips away Go subscription billing promotion banners and error messages |
| 8 | `trash.patch` | Trash (archive) | Adds the Home trash tray (archive/restore/delete), makes the `archived` timestamp nullable for `archived: null` restore, and adds a trash icon plus all translations |
| 9 | `anti-key-stick.patch` | Key switch integrity | Makes a switched API key take effect on the **next request, with no restart** (see below) |

#### Why `anti-key-stick.patch` exists

Stock OpenCode resolves the provider credential once per instance and caches it,
together with the built model client, in an instance-scoped cache. Nothing
invalidated that cache when the credential changed, so `PUT /auth/:providerID`,
`pool/switch` and `pool/reset` all returned `200` while the **old key kept being
sent**. From the user's side that reads as *"I changed the key but the quota
error never went away"* — which is easy to mistake for the server deliberately
refusing to let you switch accounts.

The stock WebUI/TUI happen to hide this by tearing the whole instance down after
every credential change. Nothing else does: the HTTP API, the SDK, `curl`, and
the Tate auth-pool endpoints were all affected. `authOverride` (the session-level
auto-rotation hook) was resolved and then dropped before the request was built,
so the automatic key rotation could not rotate either.

This patch:

- resolves the credential per request and threads it into the model client, so a
  key switch applies immediately and the built client is never reused across keys;
- makes `OPENCODE_AUTH_CONTENT` a seed rather than an override, so it can no
  longer make credential writes invisible for the lifetime of the process;
- stops Bedrock / SAP AI Core from pinning the first key they ever saw into
  `process.env` for the whole process;
- clears pool exhaustion on credential removal too;
- stops handing the plaintext credential store to workspace adapters that are not
  explicitly marked `local` (it reaches plugin-registered and remote adapters).

Covered by `packages/opencode/test/provider/key-switch.test.ts`.

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
- **Goアップセルの排除**: 使用上限に達した際の有料プランへの誘導広告や文言、およびエラー時のセッション停止を完全に削除しました。
- **共有機能の完全削除**: クラウドへの公開を伴う「共有」機能（共有ボタン、メニュー、コマンド、公開UI）を全て削除しました。
- **ヘルプボタンの削除**: 外部のDiscordサーバーや開発元への接続経路となるだけのサイドバーアイコンを削除しました。

### サーバーサイドストレージプロキシ
テーマ設定やサイドバーの幅、パネルの開閉状態といったUIのカスタマイズ設定は、通常ブラウザの `localStorage` に保存され、キャッシュクリア時にリセットされてしまいます。このパッチはすべてのストレージ操作をローカルのOpenCodeサーバーへプロキシし、設定をPC上のJSONファイルとして永続化します。これにより、別のブラウザや異なる端末からアクセスした場合でも、あなたの慣れ親しんだ作業環境が完全に再現されます。
なぜこのようなパッチを行うかというと、CPUリソース、ワークスペース、APIクォータを含む実行環境が共有されているならば、それぞれのブラウザが独立に動作するはずもなく、しかも会話単位で既に独立したチャットが行われていることから、ブラウザ単位でコンテキストの境界を定める事自体が無意味だと判断したからです。

### マルチアカウント認証プール
プロバイダごとに複数のAPIキーを、ローカルの安全な `auth-pool.json`（ファイルパーミッションは所有者のみの `0o600`）に保存し、管理できます。
- CLIコマンド (`opencode auth login`) を、対話型で複数のキーを切り替え・整理できるアカウント管理メニューへ変更しました。
- WebUIの接続ダイアログにも、登録済みのキー一覧を直感的に操作できる「アカウント管理」画面を追加しました。
- エラー時にセッションが意図せず停止することはありません。まず使っているキーを約2秒後に1回だけ再試行し、それでも連続で失敗した場合のみ「キーの責務」と判断してプール内の別キーへローテーションします（切り替えた後は無条件待機なしで即時試行）。
- リトライ指定が非常に長い場合（60秒超）は最初からキー枯渇とみなし、すぐにローテーションします。
- オフライン・ネットワーク障害はキーの責務ではありません。同じキーで上限付きバックオフにより継続ポーリングし、オンライン復帰を待ちます（復帰後の失敗から改めて同じキー→ローテーションの手順）。
- オフライン時もWebUI・TUIどちらも停止しません。会話の最下部に一時バナー「オンライン復帰を待機しています」を表示し、復帰するまでポーリングを続けます。
- 空の返信（モデルが何も出力せず応答を終えた場合）も停止ではなく停滞とみなし、約2秒待って再リクエストし、実際の応答が届くまで再試行し続けます。会話が黙って終わることはありません。
- 目に見える回答（テキスト）を返さずに終わった場合も同様です。ツール呼び出しのみで締めの説明が無かったり、テキストが届く前にストリームが切れたり、出力上限（length）で回答途中に打ち切られた場合は「完了」とは見なさず、実際に応答するまでモデルへ再リクエストし続けます。
- 400/404等の4xx「クライアントのミス」も、本当にクライアント原因とは限らないため再試行します。
- 1アカウントのみで利用する場合も停止しません。`Retry-After` を尊重して再試行を続けます。

### Enterキーの挙動変更とクォータ保護
日本語や中国語などのIME（かな漢字変換）環境において、文字の確定に`Enter`キーは欠かせません。しかし、公式のOpenCodeでは`Enter`キーが即座にメッセージ送信に結びついています。文字確定のつもりで誤ってダブルプレスすると、書きかけのメッセージが意図せず送信され、貴重なAPI利用枠（クォータ）を無駄に消費してしまいます。
- **Enter**キーは純粋に**改行**として動作するように変更し、誤送信の余地をなくしました。
- メッセージの**送信**には、明示的な意思表示として**Ctrl+Enter**（Macでは**Cmd+Enter**）を使用します。
- 入力トレイの右端に「Enterで改行」のヒントが表示されます。

### ホーム画面のゴミ箱（アーカイブ管理）
アーカイブしたセッションを確認・操作できる**ゴミ箱**をホーム画面に追加しました。
- ゴミ箱はアーカイブ済みセッションの一覧を表示し、**復元**・**削除**が可能です。
- 復元は `archived: null` を送信するため、履歴を失わず通常の一覧へ戻せます。
- サーバー・スキーマ側も `archived` タイムスタンプを nullable として受け付けるよう修正しました。

## インストールと使い方

### 必要条件
- [opencode](https://opencode.ai) v1.18.31 がインストールされていること
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

### パッチ構成一覧（計9個）

| # | パッチ名 | 対象 | 説明 |
|---|---------|------|------|
| 1 | `version.patch` | バージョン表記 | UIでは `(Tate Patched 5)` を表示しつつ、対外的なUser-Agentは `InstallationClientVersion` によりクリーンな `opencode/1.18.31` として識別（表示と送信の分離） |
| 2 | `webapp-storage-proxy.patch` | 設定のローカル永続化 | localStorageの操作をサーバーへ転送し、レイアウト設定をPC上に保存 |
| 3 | `auth-pool.patch` | 複数アカウントプール | APIキーのローカルプール管理機能（バックエンドAPI、CLI/WebUI管理画面、Connectedバッジ）と、クォータ・長時間待機時の自動ローテーション、および意図せぬ停止を防ぐリトライポリシー、関連言語ラベルを実装 |
| 4 | `ctrl-enter-send.patch` | キーボード入力 | Enterを改行、Ctrl+Enterを送信にマッピング変更し、入力欄のヒント（多言語対応）を追加 |
| 5 | `remove-help-button.patch` | ヘルプリンク削除 | サイドバー上の外部Discordサーバーへ遷移するヘルプボタンを削除 |
| 6 | `remove-share.patch` | 共有機能の削除 | セッションのクラウド共有機能（共有ボタン・メニュー・コマンド）を完全に削除 |
| 7 | `remove-upsell.patch` | 広告・宣伝の排除 | Goサブスクリプションの宣伝バナーや利用制限メッセージを排除 |
| 8 | `trash.patch` | ゴミ箱（アーカイブ） | ホーム画面にゴミ箱（アーカイブリスト・復元・削除）を追加し、`archived: null` 復元のため `archived` タイムスタンプをnullable化（ゴミ箱アイコン・多言語ラベルを含む） |
| 9 | `anti-key-stick.patch` | キー切り替えの整合性 | APIキーを切り替えた次のリクエストから（再起動なしで）実際に反映されるように修正（下記参照） |

#### `anti-key-stick.patch` について

公式のOpenCodeは、プロバイダの資格情報をインスタンスごとに一度だけ解決し、
生成済みのモデルクライアントと一緒にインスタンススコープのキャッシュに保持します。
資格情報が変わってもこのキャッシュを破棄する処理が存在せず、
`PUT /auth/:providerID` や `pool/switch`・`pool/reset` は `200` を返したまま、
**実際には古いキーが送信され続けていました**。使用者からすると
「キーを切り替えたのにクォータ切れが解消されない」という見え方になり、
サーバーが意図的にアカウント切り替えを拒んでいるように感じられます。

公式のWebUI/TUIは資格情報変更のたびにインスタンスごと破棄するため、
たまたまこの問題を隠せていました。HTTP API・SDK・`curl`・そして本パッチの
プール操作は、すべてこの影響を受けていました。
またセッション単位の自動ローテーション用フックである `authOverride` は、
解決された後にリクエスト組み立て前に破棄されていたため、
自動ローテーション自体も実際にはキーを切り替えられずにいました。

本パッチの内容:

- リクエストごとに資格情報を解決しモデルクライアントへ渡すため、
  キー切り替えが即座に反映され、異なるキーでクライアントが使い回されない
- `OPENCODE_AUTH_CONTENT` を上書き(source of truth)ではなく初期値(seed)とし、
  プロセス中は資格情報の書き込みが見えなくなる問題を解消
- Bedrock / SAP AI Core が最初に見たキーを `process.env` に固定し続ける問題を解消
- 資格情報の削除時にもプール枯渇状態をクリア
- 平文の資格情報ストアを、明示的に `local` と宣言されていない
  ワークスペースアダプタへ渡さないようにする（プラグイン登録・リモートアダプタも含む）

`packages/opencode/test/provider/key-switch.test.ts` で回帰テスト済み。

## 開発と貢献について

パッチの提案、バグ報告、およびコードの最適化、それ以外でも何でも投稿大歓迎です！
パッチを追加したい場合、`patch.sh` 内の `ordered_patches` 配列に変更したパッチ名を登録してプルリクエストを作成してください。

## ライセンス

このリポジトリ内のパッチ群は、**GNU Affero General Public License v3.0 (AGPL-3.0)** に基づいてライセンスされます。

OpenCode本体の著作権は anomalyco に帰属し、個別のライセンスに従います。
