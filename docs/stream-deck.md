# Prisma for Stream Deck

[Download Prisma app](https://github.com/kory-/prisma/releases/tag/v0.7.0) · [Download plugin 0.4.3](https://github.com/kory-/prisma/releases/tag/plugin-v0.4.3) · [日本語の手順](#日本語の手順)

The GitHub preview plugin (0.4.1.0) requires **Prisma 0.7.0**, an **Apple Silicon Mac**, macOS **14.4+**, and Stream Deck software **6.6+**. Dials require Stream Deck +. Windows and Intel Mac builds are not included.

The Marketplace candidate (0.4.3.0) requires Stream Deck **6.9+** and uses SDK 3 for Marketplace processing. It works with the same Prisma 0.7.0 app. Marketplace approval is pending.

## Setup

1. Install and launch Prisma. Enable volume control and grant macOS audio access.
2. Double-click `io.github.kory.prisma.streamDeckPlugin` (the older v0.7.0 download is named `io.github.kory-.prisma.streamDeckPlugin`) and accept Stream Deck's installation prompt.
3. Find the **Prisma** category in Stream Deck and place the actions you want.

| Action | Control |
| --- | --- |
| Playing Apps | Place on a dial. Follows playing apps according to dial position, left to right. |
| Volume Up / Volume Down | Place on a key. Choose an app and an amount per press. |
| Mute / Dial Volume | Place on a key to mute; on a dial to adjust volume and mute. Choose a fixed app or automatic mode. |

Turn a dial to change volume; press or touch to toggle mute. App icons, names and levels appear on the touch strip. Assignments remain stable briefly after playback stops, and while adjusting or muted. Settings save automatically. An optional `Prisma.Auto.streamDeckProfile` sets up four automatic dials; importing it is not required and does not replace your current profile automatically.

The plugin follows Stream Deck's language (Japanese/English; otherwise English). **Get Prisma and setup help** in the action settings links to this page. If the display says **Launch Prisma**, launch the app. If it says **Control off**, enable volume control in Prisma.

For Chrome tab controls, [set up Prisma Tabs](chrome.md) first. When a tab occupies an automatic dial, Chrome-wide audio is not assigned a duplicate dial. Fixed tab IDs only apply to the current Chrome session.

## Migration from earlier previews

The corrected Marketplace plugin ID is **`io.github.kory.prisma`**, starting with **0.4.3.0**. Elgato identified the trailing dash in the earlier `io.github.kory-.prisma` ID as the cause of installation failures in their testing. Earlier private builds also used `local.appmixer.streamdeck`. These are separate plugins: back up your profile, install the corrected plugin, and recreate its actions or import the matching optional profile. Existing actions are not automatically migrated or overwritten. Remove the old plugin only after migrating your actions.

The Prisma app bundle ID and local messaging names are retained for compatibility with existing app settings and Chrome integration.

## Distribution status

This package is distributed directly through GitHub. It is **not yet listed or approved on Elgato Marketplace**. Official CLI validation checks package structure; it is not a hardware compatibility certification. [Testing status](testing.md)

## 日本語の手順

1. Prisma本体を導入・起動し、音量コントロールをオンにします。
2. `io.github.kory.prisma.streamDeckPlugin` をダブルクリックしてStream Deckへ導入します（以前のv0.7.0配布ファイル名は `io.github.kory-.prisma.streamDeckPlugin` です）。
3. 「Prisma」カテゴリのアクションを配置します。「再生中を自動割り当て」をダイヤルに置くと、左から再生中アプリを自動で割り当てます。
4. 回して音量、押す／タッチでミュート。固定アプリや変更幅はアクション設定から選べます。

Marketplace提出版（0.4.3.0）はStream Deck 6.9以降が必要です。GitHubプレビュー版（0.4.1.0）の必要条件は6.6以降のままです。

Prisma本体は別途必要です。本体だけでも利用できます。0.4.3.0からIDを `io.github.kory.prisma` に変更しました。以前の `io.github.kory-.prisma` や開発用IDとは別のプラグインなので、既存プロファイルをバックアップし、新しいアクションへ置き換えるか対応する新しいプロファイルを読み込んでください。自動移行は行いません。現在はGitHubでの直接配布で、Marketplace掲載前です。
