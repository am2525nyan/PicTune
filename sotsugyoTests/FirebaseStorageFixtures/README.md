# 写真保存の Firebase 結合テスト

`PhotoUploadIntegrationTests` は、アプリの `CameraManager.uploadPhoto` をローカルの Auth・Firestore・Storage に接続して実行します。所有者の事前登録、JPEG と所有者メタデータ、写真・楽曲の保存、画像の取得を確認します。

Storage のルールは 2026-10-11 に Console で確認したルールのスナップショットです。Firestore は同じ所有者登録方式を使う開発ブランチのルールをテスト用に保存しています。このディレクトリはテスト専用で、本番へ deploy しないでください。

別のターミナルで、こちらのディレクトリから起動します。

```sh
firebase emulators:start --project demo-pictune-storage-save --only auth,firestore,storage
```

プロジェクトのルートから、署名を有効にした通常のシミュレータービルドで実行します。Firebase Auth が Keychain を使用するため、`CODE_SIGNING_ALLOWED=NO` は指定しないでください。

```sh
xcodebuild test -project PIcTune.xcodeproj -scheme PIcTune \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -only-testing:PIcTuneTests/PhotoUploadIntegrationTests \
  -only-testing:PIcTuneTests/sotsugyoTests \
  -parallel-testing-enabled NO
```

エミュレーター未起動時は結合テストをスキップします。実機・本番サービスでの動作確認は別途必要です。
