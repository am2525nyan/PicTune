# PicTune

写真に音楽や手紙を添えて思い出を残し、友人と共有する iOS アプリです。撮影した写真を加工してフォルダにまとめ、QR コードや NFC タグを使って共有できます。

この README はリポジトリ内のコード・設定をもとに記載しています。各機能の実機動作や外部サービスへの接続を保証するものではありません。

## 主な機能

| 機能 | 内容 |
| --- | --- |
| ログイン・設定 | Google・Apple・メールによる認証、名前の変更、ログアウト、アカウント削除 |
| 写真撮影・加工 | カメラ撮影、セピア加工、フレーム・スタンプ・手描きによる装飾 |
| 音楽の紐づけ | Apple Musicで検索した楽曲情報を写真に保存し、写真詳細で表示・手動試聴（音源がある場合） |
| フォルダ・手紙 | 写真の一覧・詳細表示、フォルダ作成、写真の追加・削除、フォルダに添える手紙の保存・表示 |
| QR コード共有 | 撮影前に相手のコードを読み取り、写真と楽曲情報を相手にも保存 |
| NFC 共有 | ユーザー ID とフォルダ ID をタグに書き込み、読み取ったフォルダの写真・楽曲情報・手紙を取り込み |
| 写真の書き出し | 写真ライブラリへの保存、共有シートでの共有 |
| ウィジェット | アプリと共有した画像 URL を使ってホーム画面に写真を表示 |

## 基本的な使い方

1. アプリを起動し、ログインします。
2. 「撮影」から写真を撮ります。友人と共有する場合は、撮影前に相手の QR コードを読み取ります。
3. 撮影した写真にスタンプや手描きを加えて保存し、続けて楽曲を検索・選択します。
4. メイン画面で写真を振り返り、フォルダにまとめたり、手紙を添えたりします。
5. フォルダを NFC タグに書き込み、受け取る側で「NFC読み込み」を使って取り込みます。

## 技術構成

- **画面・状態管理**：SwiftUI、UIKit、Combine
- **撮影・加工・再生**：AVFoundation、Core Image、PencilKit、Photos
- **認証・保存**：Firebase Authentication、FirebaseUI、Cloud Firestore、Firebase Storage
- **音楽検索**：MusicKitによる認可・トークン取得、Apple Music API、URLSession
- **共有・操作案内**：Core NFC、CodeScanner、TipKit
- **ウィジェット**：WidgetKit、App Groups
- **依存関係の管理**：Xcode の Swift Package Manager。定義は `PIcTune.xcodeproj/project.pbxproj` にあります。

## 開発環境

| 項目 | リポジトリの設定 |
| --- | --- |
| プロジェクト | `PIcTune.xcodeproj` |
| アプリの共有スキーム | `PIcTune` |
| アプリの対象端末 | iPhone |
| アプリの Deployment Target | iOS 18.0 |
| Swift 言語モード | Swift 5 (`SWIFT_VERSION = 5.0`) |

macOS と、iOS 18.0 のターゲットをビルドできる Xcode・iOS SDK が必要です。Xcode の動作確認済みバージョンは、この README では指定していません。カメラ・QR 読み取り・NFC の一連の動作確認には、対応する実機を使用してください。

## セットアップ・起動

1. リポジトリを取得し、ルートディレクトリでプロジェクトを開きます。

   ```sh
   open PIcTune.xcodeproj
   ```

2. Xcode で Swift Package Manager の依存パッケージを解決します。一部の依存はブランチ参照のため、取得時点によって解決されるコードが変わることがあります。
3. アプリとウィジェットの Signing & Capabilities を開き、使用する開発チーム・Bundle ID・プロビジョニングを確認します。既存設定を別の開発環境で使えるとは限りません。
4. 以下の外部サービスと共有設定を確認します。
5. スキーム `PIcTune` と実行先を選択し、Xcode の Run（⌘R）で起動します。

### Firebase・認証

- `sotsugyo/GoogleService-Info.plist` が、接続する Firebase プロジェクトとアプリ登録に対応していることを確認します。
- 利用する認証プロバイダー（Google・Apple・メール）、Cloud Firestore、Firebase Storage の設定とアクセス権を確認します。
- Google 認証の URL Scheme は `sotsugyo/Info.plist`、Sign in with Apple の entitlement は `sotsugyo/sotsugyo.entitlements` にあります。Firebase の接続先や Bundle ID を変更する場合は、関連設定も合わせて確認します。

### Apple Music

音楽検索は `sotsugyo/Utils/AppleMusicAPI.swift` にあります。Apple Developer Programに登録し、対象App ID（現在は `com.hosonuma.sakki.sotsugyou`）のApp ServicesでMusicKitを有効にしてください。アプリの署名チーム・Bundle IDと一致させます。Developer TokenはMusicKitから取得し、秘密鍵をアプリに埋め込みません。

初回利用時に「メディアとApple Music」へのアクセスを要求します。利用理由は `Info.plist` の `NSAppleMusicUsageDescription` にあります。検索と試聴は有料契約の有無だけで制限しませんが、未契約実機での動作は未確認です。試聴URLがない曲も選択でき、写真詳細にはApple Musicへのリンクを表示します。

以前のSpotifyデータはSpotifyとして読み込みます。新旧データの形式、利用条件、Developer設定と確認範囲は [移行調査・実装記録](docs/apple-music-migration.md) を参照してください。

### App Groups・NFC・権限

- アプリとウィジェットは App Group `group.PIcTune` を使用します。両方の entitlement と開発チームの設定を揃えてください。ID を変更する場合は、コード内の UserDefaults の suite 名も変更対象になります。
- NFC の entitlement は `sotsugyo/sotsugyo.entitlements` にあります。NFC 共有の確認には、対応する実機と読み書き可能なタグを使用します。
- カメラや写真ライブラリ保存などの権限説明文は、主に Xcode プロジェクトのビルド設定にあります。動作確認時は端末側の権限状態も確認します。

## ディレクトリ構成

```text
PIcTune.xcodeproj/        Xcode プロジェクト・共有スキーム
sotsugyo/
  sotsugyoApp.swift       アプリ起動・Firebase と TipKit の初期化
  View/                  SwiftUI の画面
    main/                写真一覧・フォルダ・手紙など
    TipKit/              操作ガイド
  ViewModel/             状態管理・データの取得と更新
  Model/                 楽曲などのデータモデル
  Utils/                 カメラ・認証・Apple Music・NFC・QR など
  Assets.xcassets/        画像・スタンプ・色
PicTuneWidget/           ホーム画面ウィジェット
sotsugyoTests/           単体テスト
sotsugyoUITests/         UI テスト
```

外部サービスとの通信処理は `Utils/` だけでなく、`View/`・`ViewModel/` にもあります。

## データの保存先

| 保存先 | 主な用途 |
| --- | --- |
| Firestore：`users/{uid}/personal/info` | ユーザー情報 |
| Firestore：`users/{uid}/folders/{folderId}` | フォルダ情報・手紙（`letter` フィールド） |
| Firestore：`users/{uid}/folders/{folderId}/photos/{photoId}` | 写真への参照・日時・楽曲情報 |
| Firebase Storage：`images/` | 保存した画像本体 |
| Firebase Storage：`livephotos/` | 撮影処理にある動画保存先 |
| App Group の UserDefaults | ウィジェット用画像 URL（`first`・`second`・`third`） |

`all` は全写真用の特別なフォルダ ID です。共有処理には相手のユーザー領域への書き込みやフォルダデータのコピーが含まれるため、保存形式・削除処理を変更するときは共有先との関係も確認します。

## ビルド・テストと確認範囲

Xcode でスキーム `PIcTune` を選択し、Build（⌘B）または Test（⌘U）を実行します。共有スキームには `PIcTuneTests` と `PIcTuneUITests` が登録されています。

単体テストには楽曲検索・保存形式・旧データ互換・試聴なし・停止後の応答を含みます。Apple Music用UIテストはDebug限定の固定データで検索・選択・エラー・写真詳細を確認します。テストの成功だけでは各機能の動作を確認できません。変更した画面・保存処理・共有処理について、実際の操作でも確認してください。

- 音楽検索・試聴は外部 API と試聴 URL の取得結果に依存します。試聴URLがなくても検索結果に表示します。
- ウィジェットは共有領域の 3 件の画像 URL を前提に読み込む実装です。初回起動や写真が少ない状態も確認対象です。
- Live Photo 関連の撮影・保存処理はありますが、機能全体の完成や実機動作を確認済みとは扱っていません。
- Apple Developer Portal設定、Apple Musicの実通信・実機再生、QR・NFCの実機確認は未実施です。

## 開発時のルール

作業範囲、動作確認、デザイン変更時のスクリーンショット、コミット・push・PR のルールは [AGENTS.md](AGENTS.md) を参照してください。
