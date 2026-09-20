<img src="Assets/Prism-preview.png" width="112" alt="Prismaのアイコン">

# Prisma

macOSのアプリごとに音量を調整する、ネイティブの音量ミキサーです。メニューバーからの操作、Chromeタブ単位の音量、Stream Deckにも対応します。

[English](README.md) · [試験版をダウンロード](https://github.com/kory-/prisma/releases/tag/v0.7.0) · [不具合の報告](https://github.com/kory-/prisma/issues)

**公開試験版 · Apple Silicon · macOS 14.4以降**

この版はアドホック署名で、**Appleの公証を受けていません**。最低対応バージョンは14.4に設定しています。実際の音声再生はmacOS 26.5.2と27.0で確認しており、すべての対応環境での動作確認は済んでいません。[確認済みの範囲と制限](docs/testing.md)

## できること

- アプリごとの音量を0〜100%に調整、またはミュート。
- メイン画面とメニューバーの両方から操作。
- Macの標準出力先を切り替え。
- ログイン時の起動、起動時の音声制御、外観、Dock、メニューを設定。
- 日本語・英語の切り替えと、システム言語への追従。
- 任意のChrome拡張 **Prisma Tabs** で、再生したタブを自動検出して個別に調整。
- 任意の **Stream Deckプラグイン** で、キーやダイヤルから操作。Stream Deck +には再生中アプリのアイコンと音量を表示。

Prisma本体だけでも使えます。仮想オーディオドライバや管理者権限の常駐サービスは必要ありません。

## 導入

1. [リリースページ](https://github.com/kory-/prisma/releases/tag/v0.7.0)から `Prisma-0.7.0-macOS-arm64.zip` をダウンロードして展開し、`Prisma.app` を「アプリケーション」に移動します。
2. Prismaを開きます。この試験版にはDeveloper ID署名・Apple公証がありません。macOSにブロックされた場合は、信頼するアプリ向けの[Appleの手順](https://support.apple.com/ja-jp/102445)を確認するか、[ソースからビルド](docs/development.md)してください。Gatekeeper全体を無効にする必要はありません。
3. ツールバーの音量コントロールをオンにして、macOSのシステムオーディオへのアクセスを許可します。
4. 音声を再生し、アプリのスライダーで調整します。標準では、ウインドウを閉じてもメニューバーに常駐します。

設定は歯車ボタンまたは **⌘,** で開けます。出力先の変更はMac全体に適用されます。アプリごとに別の出力先を指定する機能ではありません。

| 任意の連携 | 導入方法 |
| --- | --- |
| Stream Deck | `io.github.kory-.prisma.streamDeckPlugin` をダブルクリック。[設定手順](docs/stream-deck.md) |
| Chromeのタブ | Prismaメニューの「Chrome拡張を設定…」から準備。[設定手順](docs/chrome.md) |

## プライバシー

音声はメモリ内で処理し、録音ファイルの保存・音声の外部送信・アクセス解析を行いません。Chrome拡張は、検出したタブのタイトル・アイコン・再生状態を同じMacのPrismaに渡します。[詳細](PRIVACY.md)

## 開発と報告

[ビルドとテスト](docs/development.md) · [変更履歴](CHANGELOG.md) · [不具合の報告](https://github.com/kory-/prisma/issues)

開発者：[kory-](https://github.com/kory-)。Background Musicのソースは含まない独立した実装です。Apple・Google・Elgatoおよび同名のPrisma ORMとは関係ありません。

[MITライセンス](LICENSE)で公開しています。
