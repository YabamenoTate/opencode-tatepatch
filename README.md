# OpenCode Tate Patch

Are you developing proactively with OpenCode? Or is the tool defining the limits of your creativity?

When you run proprietary software unmodified, you accept the service provider's rules, limitations, and monetization guidelines without question. In the human world, we don't just repeat stories word-for-word; we listen, we interpret, and we re-evaluate them through our own minds. Modifying your editor is no different. It is how our computers interpret and re-evaluate the development environment they run, breaking free from digital compliance.

**OpenCode Tate Patch is a declaration of local autonomy for your machine.**

Why should a local editor have a "Share" button that uploads your private sessions directly to OpenCode's central servers (opencode.ai)? Even if the feature functions exactly as designed, bridging your local sandbox to external cloud hosting by default compromises your workspace's independence. Similarly, a help icon that directs you straight to an external Discord server and feedback trackers has no place in a quiet, self-contained development environment. 

Most importantly, why should your editor limit your identity to a single billing account, prompting you to subscribe whenever you hit a rate limit? Proprietary vendors design their software around a single billing endpoint—a dogmatic assumption that you must comply with their centralized subscription model and follow their vendor-imposed behavioral rules. Your own computer has no obligation to act as a collections agent for a vendor's monetization rules.

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
- The CLI (`opencode auth login`) becomes an interactive account manager for adding, switching, and organizing keys.
- The WebUI gains a "Manage Accounts" screen after connecting a provider.
- Errors do not cause unexpected session termination. The current key is retried once after ~2 seconds; only a second consecutive failure marks the key as faulty and rotates to the next pool key, tried immediately with no forced wait.
- A very long retry hint (60s+) counts as key exhaustion and rotates right away.
- Network/offline failures are not attributed to the key: the same key is polled with bounded backoff until connectivity returns.
- While offline, the WebUI and TUI remain active and show a temporary banner ("Waiting for network recovery...") at the bottom of the conversation.
- An empty provider reply is treated as a stall, not a finish: the turn waits ~2 seconds and retries until a real reply arrives.
- A turn that ends without delivering a visible answer (tool call with no closing explanation, stream cut before text arrives, truncation by length/output cap) is also treated as incomplete and retried until the model actually produces an answer.
- 4xx responses (400/404/...) are retried rather than treated as fatal.
- Single-account use also respects `Retry-After` and never hard-stops the session.

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
- [opencode](https://opencode.ai) installed, at the base version named in [VERSION](VERSION)
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

### Patch Inventory (12 patches)

| # | Patch | Target | Description |
|---|-------|--------|-------------|
| 1 | `webapp-storage-proxy.patch` | Local persistence | Proxies webapp localStorage requests to server and persists layout config locally |
| 2 | `auth-pool.patch` | Multi-account pool | Implements auth key pool management (CRUD backend APIs, WebUI connected badge & config page, CLI commands) with auto-rotation on quota or long waits and a no-hard-stop retry policy: offline shows a waiting banner (オンライン復帰を待機しています) in WebUI + CLI and keeps polling, empty provider replies auto-retry after ~2s until a real reply arrives, including localized language keys |
| 3 | `ctrl-enter-send.patch` | Keyboard input | Rebinds Enter to newline and Ctrl/Cmd+Enter to send, adding UI tray hint with all translations |
| 4 | `remove-help-button.patch` | Help button | Removes the sidebar help icon linking to an external Discord server |
| 5 | `remove-share.patch` | Cloud share | Removes the cloud session publishing feature entirely (menus, commands, share button) |
| 6 | `remove-upsell.patch` | Billing ads | Strips away Go subscription billing promotion banners and error messages |
| 7 | `trash.patch` | Trash (archive) | Adds the Home trash tray (archive/restore/delete), makes the `archived` timestamp nullable for `archived: null` restore, and adds a trash icon plus all translations |
| 8 | `anti-key-stick.patch` | Key switch integrity | Makes a switched API key take effect on the **next request, with no restart**, and gives every session its own key that rotates only when that key is actually rate limited (see below) |
| 9 | `shell-background.patch` | Non-blocking shell | Ends the wait on a silent long-running command without ever cutting short a command that is still making progress (see below) |
| 10 | `wait-commit.patch` | Wait tool / commit permissions | Adds the `wait` tool (registered in the tool registry), grants the `"wait"` permission to agents, and adjusts shell/commit-related flow so long-running work can be coordinated safely |
| 11 | `version.patch` | Version split | Adds the tatepatch label (CLI `--version`, health, TUI) from `VERSION`, while outbound User-Agents stay clean semver via `InstallationClientVersion` |
| 12 | `key-suffix.patch` | Key visibility | Shows the last 4 characters of the API key currently serving a session next to status labels ("Thinking", "Edit", "Write") in the WebUI, and fixes a frozen `options.apiKey` shadowing the rotated key in `resolveSDK` |
| 13 | `wire-identity.patch` | Deterministic wire identity | Derives request session/message/parent/project IDs from (local session ID, API key) so the wire identity is stable across restarts and different keys cannot be correlated; rotation produces distinct identities per key |

#### Why `shell-background.patch` exists

Any command the model starts that does not exit — `npm run dev`, a local server, a
watcher — stalls the turn until the tool timeout. Stock OpenCode kills the process
and reports *"timed out"*, which throws away whatever the command was doing, and a
hand-written large `timeout` value only postpones the stall: `timeout` was an
unbounded `PositiveInt`, so a value like `3600000` blocked the turn for an hour.

This patch:

- treats **output as liveness**. While the command keeps writing to stdout or
  stderr, the turn keeps waiting normally, for as long as it takes. A build that
  runs all day is left alone. Only after **300 seconds of complete silence** is
  the command moved to the background;
- moves the *already running* process — no restart, no lost work — so scope
  teardown no longer kills it, and keeps draining its output to a truncation log
  so it cannot die of a broken pipe while unattended;
- returns immediately with a `shell_metadata` block carrying the **PID**, the log
  path, and how to read or stop it, so the model knows the process is still alive
  and can move on;
- teaches the model to start servers this way: launch, **wait about 10 seconds**,
  then read the log and end the turn instead of waiting for the process to exit;
- **does not clamp `timeout`**. A model that asks for two hours still gets two
  hours, and asking for a huge timeout does not buy the turn back — the idle
  window ends the wait either way. This matters because models routinely pass a
  multi-hour timeout for a dev server, which is exactly the case that used to
  leave the shell sitting there until a human noticed and killed it;
- **drops the built-in default timeout** so there is no clock at all unless one is
  asked for. A command is never stopped running here — it is only ever stopped
  being waited on.

The 300s idle window is tunable via `OPENCODE_EXPERIMENTAL_BASH_IDLE_TIMEOUT_MS`.
An operator who does want a default wall-clock limit can set
`OPENCODE_EXPERIMENTAL_BASH_DEFAULT_TIMEOUT_MS`.

Covered by `packages/opencode/test/tool/shell.test.ts`.

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

#### One key per session, rotating only on a real rate limit

Once several keys are configured, the interesting failure is no longer *"the switch
did nothing"* but *"every key is rate limited and the client sits there for hours"*.
A real `429 Rate limit reached` from the gateway carries `retry-after` in seconds
until the quota resets, which can be tens of thousands of seconds. Rotating on a
timer, or re-selecting a key per request, does not help: it either spreads the load
or re-uses a key that has already been shown to be exhausted.

So the key set is now just a set. The key in `auth.json` and every entry of
`auth-pool.json` are candidates, and none of them is privileged:
- the **first** request after startup uses the `auth.json` key, which keeps the
  single-key configuration behaving exactly as it did before;
- every other session is given a key that no other session is currently using, so
  concurrent sessions spread across the accounts instead of piling onto one;
- a session **keeps** its key for as long as that key stays healthy. It only gives it
  up when that key comes back `429` (or is otherwise reported as a key-level
  failure), at which point the key is put in cooldown for the window the gateway
  asked for and the session moves to another one. Healthy sessions are never
  disturbed;
- a long `retry-after` (60s or more) on a rate-limit response rotates on the first
  failure, because that is an unambiguous "this account is done for now". A short
  one rotates after two consecutive failures, and a network error never rotates,
  since a dropped connection is not the key's fault. The new key is tried
  immediately rather than after a wait;
- cooldown is remembered on disk and is applied to the `auth.json` key as well, so
  an exhausted primary is not re-tried on every new session;
- a session's key is released when the session is deleted, and otherwise expires
  after an idle timeout, so a key is never stranded by a session that went away;
- nothing is ever written back to `auth.json` automatically. Only the explicit
  `PUT /auth/:providerID`, `pool/switch` and `pool/reset` endpoints still change
  it, so a provider switch made by hand is never silently undone.

`GET /auth/:providerID/pool` reports which keys are currently leased, by hash and
masked form only, so it is possible to see at a glance which account a busy
instance is sitting on.

If **every** key is in cooldown there is nothing useful left to switch to, so the
patch does not spin: it keeps the key that recovers first, reports the wait through
`pool` state, and lets the normal retry backoff run rather than immediately
re-requesting an account the gateway has already rejected.

#### Keys and sessions are not allowed to leak into each other

The header set on the wire is exactly the set upstream sends — the same fields, the
same names, the same conditions for their presence, and the same User-Agent. What
changes is that the values identifying this checkout are **per key rather than per
machine**.

The point is not to look anonymous. A stable project identity is what lets a gateway
reuse a cached prefix for the same repository, so stripping it would only produce a
slower and more obviously scripted client. Instead the identity is kept and
re-keyed:

- `x-opencode-project` used to be a hash of the checkout's git remote, identical for
  every session of that repository and identical on every account. It is now derived
  from the project **and the key in use**. One key always presents one project, so a
  gateway caching per account still gets its cache hits; a different key presents a
  project identity that account has never seen.
- `x-opencode-session`, `x-session-affinity`, `X-Session-Id` and
  `x-parent-session-id` are scoped the same way, so when a session rotates to
  another key after a rate limit the new account is handed a session it has never
  seen, and nothing cached for that session under the old key is visible to it.
- `x-opencode-request` is scoped too. It is a per-message id, and retrying the same
  message after a rotation would otherwise repeat it verbatim on the new account,
  which links the two.

So the same key looks like one consistent project and one consistent client for as
long as it is in use, and switching keys breaks every identifier at once. Nothing is
shared between accounts that has not been re-derived for that account. The
derivation is one-way and hashes the key in, so the value can be walked back to
neither the real project id nor the credential.

Conversation content is of course still sent to whichever key answers it. Assistant
responses are still not stored provider-side (`store: false`).

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

あなたはOpenCodeで主体的な開発ができていますか？ それとも、プロプライエタリの支配の中を不自由に泳がされていますか。

他人が作ったソフトウェアをそのままの状態でただ動かすことは、そのルールや制限、マネタイズの論理を無批判に受け入れることを意味します。
人間社会においても、私たちは他人の話をただオウム返しにするのではなく、自分の頭で解釈し、再評価して語り直します。ソフトウェアの挙動を改造（フォークやパッチ）することも、それとまったく同じです。これは、コンピュータが自ら実行する開発ツールのコードを解釈し、その振る舞いを主体的に再評価する目的においての有効な手段ではないでしょうか？

**OpenCode Tate Patchは、あなたのコンピュータのローカルな自律性を取り戻すためのプロジェクトです。**

ローカル環境で動作するエディタに、なぜ作成したコードを特定企業の共有サーバー（opencode.ai）へ直接アップロードする「共有」ボタンがデフォルトで置かれているのでしょうか。これは機能自体は正常に動作するかどうかという問題ではなく、ローカルな作業空間から中央集権的な外部インフラへの接続をデフォルトにする設計そのものが、ツールの独立性を損なっています。同様に、外部のDiscordサーバーやフィードバックページへ直接ユーザーを誘導するヘルプアイコンも、ローカルで静かに集中すべき開発環境には不要なものです。

何より重要なのは、なぜエディタがあなたのアイデンティティを「単一の課金アカウント」に制限し、レート制限に達するたびにサブスクリプションの購入を促してくるのか、という点です。プロプライエタリなベンダーは、自社の課金システムという「中央集権的なドグマ」を前提にソフトウェアを設計し、ユーザーにそのルールに従うことを強要します。しかし、あなた自身が所有するコンピュータが特定のベンダーに盲目的に従って集金ルールを執行する必要はありません。

コンピュータは、こうした人為的な制限を回避するために、複数のAPIキーやアカウントを自由に切り替えられるべきです。
（これは、複数アカウントで切り替えを行うことを推奨しているのではなく、自分の意思で単一アカウントを使って利用規約を守る選択肢も存在している前提で、その選択の主導権はユーザーに存在すべきであるという主張でしかありません。）
Tate Patchは、中央集権的な依存関係を排し、ローカルとして妥当な制御性とプライバシーを取り戻すために設計されたパッチセットです。

## 主な機能

### ノイズのないクリーンな作業環境
- **Goアップセルの排除**: 使用上限に達した際の有料プランへの誘導広告や文言、およびエラー時のセッション停止を完全に削除しました。
- **共有機能の完全削除**: クラウドへの公開を伴う「共有」機能（共有ボタン、メニュー、コマンド、公開UI）をすべて削除しました。
- **ヘルプボタンの削除**: 外部のDiscordサーバーや開発元への接続経路となるだけのサイドバーアイコンを削除しました。

### サーバーサイドストレージプロキシ
テーマ設定やサイドバーの幅、パネルの開閉状態といったUIのカスタマイズ設定は、通常ブラウザの `localStorage` に保存され、キャッシュクリア時にリセットされてしまいます。このパッチはすべてのストレージ操作をローカルのOpenCodeサーバーへプロキシし、設定をPC上のJSONファイルとして永続化します。これにより、別のブラウザや異なる端末からアクセスした場合でも、慣れ親しんだ作業環境が完全に再現されます。
なぜブラウザではなくサーバー経由でプロキシするのかといえば、CPUリソース、ワークスペース、APIクォータが同一の実行環境で共有されていることによって、ブラウザが独立に動作するはずがなく、しかも会話単位で既に独立したチャットが行われていることから、ブラウザ単位でコンテキストの境界を定める事自体が無意味だと判断したからです。

### マルチアカウント認証プール
プロバイダごとに複数のAPIキーを、ローカルの安全な `auth-pool.json`（パーミッション `0o600`）に保存し、柔軟に管理できます。
- CLIコマンド (`opencode auth login`) を、対話型で複数のキーを切り替え・整理できるアカウント管理メニューへと拡張しました。
- WebUIの接続ダイアログにも、登録済みのキー一覧を直感的に管理できる「アカウント管理」画面を追加しました。
- エラー時にセッションが意図せず停止しないために、現在のキーを約2秒後に1回だけ再試行し、それでも連続で失敗した場合のみ「キーの障害」とみなしてプール内の別キーへローテーションします（切り替え後の待機時間はなし）。
- リトライ指定が非常に長い場合（60秒超）は最初からキー枯渇とみなし、即座にローテーションします。
- ネットワーク障害やオフライン状態のときはキーが理由の遮断ではないので、同じキーでバックオフを伴うポーリングを続け、オンライン復帰を待ちます。
- オフライン時もWebUIやTUIは停止せず、会話の最下部に一時バナー「オンライン復帰を待機しています」を表示します。
- 空の返信（モデルが何も出力せず応答を終えた場合）は停止ではなく停滞とみなし、実際の応答が届くまで約2秒ずつ待って再リクエストを続け、会話が黙って終わることを防ぎます。
- 目に見える回答を返さずに終了した場合（ツール呼び出しのみ、ストリームの切断、出力上限での打ち切りなど）も「完了」とはみなさず、モデルが実際に応答を終えるまで再リクエストし続けます。
- 4xx系のクライアントエラー（400/404など）であっても一律で即死させず、再試行を行います。
- 1アカウントのみの利用でも `Retry-After` が尊重され、セッションが突然停止することはありません。

### Enterキーの挙動変更とクォータ保護
日本語や中国語などのIME（かな漢字変換）環境において、文字の確定に`Enter`キーは欠かせません。しかし、公式のOpenCodeでは`Enter`キーが即座にメッセージ送信に結びついています。文字確定のつもりで誤ってダブルプレスすると、書きかけのメッセージが意図せず送信され、貴重なAPI利用枠（クォータ）を無駄に消費してしまいます。
- **Enter**キーは純粋に**改行**として動作するように変更し、誤送信の余地をなくしました。
- メッセージの**送信**には、明示的な意思表示として**Ctrl+Enter**（Macでは**Cmd+Enter**）を使用します。
- 入力欄の右端に「Enterで改行」のヒントが表示されます。

### ホーム画面のゴミ箱（アーカイブ管理）
アーカイブしたセッションを確認・操作できる**ゴミ箱**をホーム画面に追加しました。
- ゴミ箱画面から、アーカイブ済みセッションの一覧を表示し、**復元**および**完全削除**が可能です。
- サーバー・スキーマ側も `archived` タイムスタンプを nullable として受け付けるようにし、復元時は `archived: null` が送信されるため、履歴を失うことなく通常の一覧へ戻せます。

## インストールと使い方

### 必要条件
- [opencode](https://opencode.ai) が [VERSION](VERSION) のベースバージョンでインストールされていること
- [git](https://git-scm.com) がインストールされていること
- [bun](https://bun.sh) がインストールされていること

### 1. ディレクトリの配置
`tatepatch` フォルダをOpenCodeの設定パスに配置します：
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

### パッチ構成一覧（計12個）

| # | パッチ名 | 対象 | 説明 |
|---|---------|------|------|
| 1 | `webapp-storage-proxy.patch` | 設定のローカル永続化 | localStorageの操作をサーバーへ転送し、レイアウト設定をPC上に保存 |
| 2 | `auth-pool.patch` | 複数アカウントプール | APIキーのローカルプール管理機能（バックエンドAPI、CLI/WebUI管理画面、Connectedバッジ）、クォータ・長時間待機時の自動ローテーション、およびリトライポリシー、関連言語ラベルを実装 |
| 3 | `ctrl-enter-send.patch` | キーボード入力 | Enterを改行、Ctrl+Enterを送信にマッピング変更し、入力欄に多言語対応のヒントを追加 |
| 4 | `remove-help-button.patch` | ヘルプリンク削除 | サイドバー上の外部Discordサーバーへ遷移するヘルプボタンを削除 |
| 5 | `remove-share.patch` | 共有機能の削除 | セッションのクラウド共有機能（共有ボタン・メニュー・コマンド）を完全に削除 |
| 6 | `remove-upsell.patch` | 広告・宣伝の排除 | Goサブスクリプションの宣伝バナーや利用制限メッセージを排除 |
| 7 | `trash.patch` | ゴミ箱（アーカイブ） | ホーム画面にゴミ箱（アーカイブリスト・復元・削除）を追加し、nullableな `archived` タイムスタンプによる復元に対応（ゴミ箱アイコン・多言語ラベルを含む） |
| 8 | `anti-key-stick.patch` | キー切り替えの整合性 | APIキーを切り替えた次のリクエストから再起動なしで即座に反映（下記参照） |
| 9 | `shell-background.patch` | ノンブロッキングシェル | 静かな長時間コマンド（サーバ等）の待機をエージェントが間違えて実行して延々と待ち始めたとき、進行中のコマンドを切断せずバックグラウンドに追いやってエージェントに警告しつつ続行 |
| 10 | `wait-commit.patch` | waitツール / コミット権限 | `wait`ツールを追加（ツールレジストリに登録）、エージェントに `"wait"` 権限を付与し、`shell-background.patch`の影響で長時間コマンドが出来なくなる代わりに、長時間待機は明示的`wait`ツールを使わせる。 |
| 11 | `version.patch` | バージョン表記 | `VERSION` から取得した tatepatch ラベルを UIに表示しつつ、対外的なUser-Agentは `InstallationClientVersion` によりクリーンなセマンティクスとして識別（表示と送信は分離） |
| 12 | `key-suffix.patch` | 使用中キーの可視化 | WebUIのステータス表示（"Thinking" / "Edit" / "Write"）の隣に、そのセッションでリクエストに使われているAPIキーの末尾4桁を表示。さらに `resolveSDK` において設定凍結済みの `options.apiKey` がローテーション後のキーを覆い隠す問題を修正 |
| 13 | `wire-identity.patch` | 決定的なwire identity | リクエストのsession/message/parent/project IDを（ローカルセッションID、APIキー）から決定的に導出し、再起動後も同一キーで同一identityを用いるように。キーごとに異なるidentityを用いることで相関を避ける |

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

## 開発と貢献について

パッチの提案、バグ報告、およびコードの最適化、それ以外でも何でも投稿大歓迎です！
パッチを追加したい場合、`patch.sh` 内の `ordered_patches` 配列に変更したパッチ名を登録してプルリクエストを作成してください。

## ライセンス

このリポジトリ内のパッチ群は、**GNU Affero General Public License v3.0 (AGPL-3.0)** に基づいてライセンスされます。

OpenCode本体の著作権は anomalyco に帰属し、個別のライセンスに従います。
