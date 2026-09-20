# Privacy

Prisma 0.7.0 · Prisma Tabs 0.3.0 · Stream Deck plugin 0.4.1.0

## Audio and settings

Prisma uses macOS Core Audio process taps to detect playback and, when needed, attenuate it. Audio is processed in memory. There is no recording-file feature, audio upload, account system, analytics, or telemetry.

Per-app volume/mute preferences, selected UI options, and startup choices are stored in macOS user preferences. Login launch uses Apple's SMAppService when enabled. App names and icons come from macOS.

## Chrome extension

Prisma Tabs adjusts HTML media and Web Audio inside web pages. It does not record tab audio. It exchanges a detected tab's ID, title, icon, volume, mute and playback status with the native Prisma helper on the same Mac. Titles can contain personal information and appear in the mixer, menu and optional Stream Deck display.

The extension stores tab IDs and volume/mute state in `chrome.storage.session`. It does not deliberately save tab titles or URLs to disk. It obtains site icons through Chrome's favicon API. It does not read form inputs or page article content. The native helper retains live state in memory.

| Permission | Use |
| --- | --- |
| `nativeMessaging` | Communicate with Prisma on this Mac |
| `tabs` | Identify tab metadata and track tab lifecycle |
| `favicon` | Show site icons |
| `scripting` | Apply audio support to eligible existing pages |
| `storage` | Retain volume state for the Chrome session |
| HTTP/HTTPS host access | Detect and adjust media automatically on permitted pages |

The extension does not use `tabCapture` or `offscreen`. It runs only where Chrome permits it and where site access is granted.

## Stream Deck and local integrations

The plugin connects to Stream Deck through a loopback WebSocket (`127.0.0.1`) and exchanges local app/tab playback metadata with Prisma. The app's integration uses macOS distributed notifications and local URL commands. These are local convenience interfaces, not a security boundary against other processes running as the same user.

Opening a documentation or download link contacts GitHub in your browser. GitHub and the host apps have their own privacy policies. Prisma does not upload playback metadata to those pages.

## Removal

Turn off Prisma's volume control and quit to stop processing. Disable login launch before removing the app. Remove Prisma Tabs through Chrome's extension manager and remove the plugin through Stream Deck as desired. Optional Chrome setup files are under `~/Library/Application Support/Prisma/ChromeExtension` and `~/Library/Application Support/Google/Chrome/NativeMessagingHosts/local.prisma.chrome.json`.

## 日本語

音声の録音保存・外部送信・アクセス解析は行いません。音量と表示設定はMacに保存します。Chrome拡張は検出したタブのタイトル・アイコン・再生状態を同じMacのPrismaへ渡すため、タイトルは本体やStream Deckに表示されます。拡張のタブ設定はChromeのセッション内に保持します。説明書へのリンクを開くと、ブラウザでGitHubへ接続します。
