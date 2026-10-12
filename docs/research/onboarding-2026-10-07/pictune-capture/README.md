# PicTuneの実ビルドから取得したチェキ

2026-10-07、`PIcTune.xcodeproj` / `PIcTune` / Debug をビルドし、iPhone 18 Pro・iOS 27.0のシミュレーターで取得しました。Xcode 27.2 beta 2のiOS Simulator SDKを使用しています。

## 取得物

- `cheki.png`：無地のチェキ。999 × 1587 pxのPNG原本。
- `cheki-plain.jpg`：同じ描画結果のJPEG。
- `cheki-ribbon.jpg`：既存スタンプ `4`（リボン）を付けたJPEG。
- `cheki-lace.jpg`：既存スタンプ `2`（水色）を付けたJPEG。
- `editor-iphone18pro-ios27.png`：実アプリの「写真を編集」画面。
- `input-photo.jpg`：前のデザイン比較モックで使っていたサンプル写真。実機カメラで撮影したユーザー写真ではありません。
- `capture-harness.patch`：取得時だけ適用したDebug用コード。現在のアプリソースには適用していません。

## 取得方法と検証範囲

サンプル写真をアプリのDocumentsに `cheki-reference-input.jpg` としてコピーし、既存のUI確認用起動経路へ一時的な書き出し処理を加えました。起動引数は `-ui-testing -cheki-reference-capture -AppleLanguages (ja) -AppleLocale ja_JP` です。

通常の保存処理が使う `PhotoArtwork` をSwiftUIの `ImageRenderer` で描画しました。333 × 529pt、scale 3で、既存の `Image` アセット・写真配置・スタンプをそのまま使っています。JPEGは同じUIImageから品質0.75で出力しています。HTML側でチェキ枠を描き直した画像ではありません。

取得用の画面は実際の `PhotoPreviewView` を使用します。PNGと3種類のJPEGを確認し、無地の編集画面を `simctl io screenshot` で撮影しました。ユーザーの写真・クラウドデータは使用していません。保存ボタンによるFirebaseへのアップロード、写真ライブラリへの保存、実機カメラ撮影は今回の確認範囲外です。

ビルドは最終的に `BUILD SUCCEEDED`。初回はディスク不足で失敗したため、今回の一時キャッシュを削除し、既存の依存・ビルドキャッシュを再利用して成功しました。取得後、`UITestFixtures.swift` は取得前の内容へ戻しています。アプリの恒久的なコード変更はありません。

会話内の「可愛いチェキの入口」3案は、このJPEGを埋め込んだ画像に差し替えました。写真の縦横比を保ち、HTMLによる追加の白フチ・画像トリミング・フチ内の仮文字は取り除いています。
