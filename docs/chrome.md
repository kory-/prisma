# Prisma Tabs

[日本語の手順](#日本語の手順)

Prisma Tabs 0.3.0 requires Chrome 119 or later and Prisma 0.7.0. It automatically detects HTML audio/video and Web Audio on permitted HTTP/HTTPS pages. There is no per-tab Add button.

## Setup

1. Put Prisma in its permanent location, launch it, and choose **Prisma → Set Up Chrome Extension…**.
2. Open `chrome://extensions` in Chrome and enable Developer mode.
3. Choose **Load unpacked**, then select `~/Library/Application Support/Prisma/ChromeExtension`.
4. Allow access to the sites you want to control. Play audio; the tab appears in Prisma automatically.

The app includes the extension. The separate `Prisma-Tabs-0.3.0.zip` contains the same files for inspection/manual loading; native messaging still requires step 1. It is not listed in Chrome Web Store.

If you move Prisma, repeat step 1 from its new location. When upgrading, repeat step 1, reload Prisma Tabs once in `chrome://extensions`, and reload existing Web Audio pages if needed.

## Controls and limits

- Use Prisma, its menu, the extension popup, or Stream Deck to change tab volume.
- Volume settings survive navigation in the same tab; closing the tab clears it. Browser sessions start with new tab settings.
- Site volume, Prisma tab volume and Prisma's Chrome-wide volume multiply. Keep Chrome-wide volume at 100% when you only want tab controls.
- Turning Prisma's audio control off restores the pages' normal output.
- The extension exposes up to 16 tabs, prioritizing playing tabs.
- Existing Web Audio connections may require one page reload after extension installation. Prisma does not reload pages for you.
- Chrome internal pages, pages which disallow extensions, and sites without permission are excluded. DRM and custom audio implementations are not verified across all services.
- A playing HTML media element can count as active during silence.
- The extension follows Chrome's language (Japanese/English; otherwise English).

See [privacy and permission details](../PRIVACY.md).

## 日本語の手順

1. Prismaを保存先に移動して起動し、**Prisma → Chrome拡張を設定…** を選びます。
2. Chromeで `chrome://extensions` を開き、デベロッパーモードをオンにします。
3. 「パッケージ化されていない拡張機能を読み込む」から `~/Library/Application Support/Prisma/ChromeExtension` を選びます。
4. 対象サイトへのアクセスを許可して音声を再生すると、Prismaに自動表示されます。タブごとの追加操作は不要です。

更新時は1を実行後、拡張の再読み込みを一度行ってください。既に開いていたWeb Audioページはページの再読み込みが必要な場合があります。本体を移動した場合も1を実行します。Chrome Web Storeでの配布はまだ行っていません。
