# Apple Music移行調査・実装記録

調査日：2026年10月6日。PicTuneの音楽連携をApple Musicへ移すため、公式資料、既存コード、ローカルSDKを確認しました。アプリ本体の検索・保存形式・写真詳細をApple Musicへ移行しました。対象App IDのMusicKitは有効化済みで、シミュレーターでの実検索・試聴の再生位置の進行・停止を確認しました。実機での動作は未確認です。

PicTuneのBundle IDを使い、シミュレーターで認可・トークン取得・カタログ検索・試聴を通せました。ただし、未契約実機での検索・再生は未確認です。BeRealで未契約でも音が出たというユーザーの観察は、PicTuneでの動作や利用許諾を保証するものではありません。

## 調査で確認したこと

| 項目 | 確認結果 |
| --- | --- |
| カタログ検索 | MusicCatalogSearchRequestでSongを検索できます |
| 曲情報 | 曲ID、曲名、アーティスト、アルバム画像、曲のURL、ISRCを扱えます |
| 試聴 | Song.previewAssetsとPreviewAsset.urlが存在します。両方とも取得できない場合があります |
| 認可 | MusicKitの使用前にMusicAuthorizationによる同意とNSAppleMusicUsageDescriptionが必要です。音楽の有料契約とは別です |
| トークン | App IDのMusicKit App Serviceを有効にすると、ネイティブMusicKitがDeveloper Tokenを自動生成します |
| REST API | カタログはDeveloper Token、ユーザー固有データには追加のMusic User Tokenを使う設計です |
| フル再生 | Apple Music配信曲は契約状態を確認します。試聴URLをAVPlayerで扱う処理とは別です |
| 地域 | Storefrontごとに配信内容が異なります。投稿者の地域で取得したIDやURLだけで受信者の再生を保証できません |

根拠：[MusicKit](https://developer.apple.com/documentation/musickit)、[検索](https://developer.apple.com/documentation/musickit/musiccatalogsearchrequest)、[Song](https://developer.apple.com/documentation/musickit/song)、[PreviewAsset](https://developer.apple.com/documentation/musickit/previewasset)、[トークン自動生成](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)、[Developer Token](https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens)、[ユーザー認証](https://developer.apple.com/documentation/applemusicapi/user-authentication-for-musickit)、[地域](https://developer.apple.com/documentation/applemusicapi/storefronts-and-localization)。

Apple Developer Programへの加入が必要です。標準年会費は99米ドルまたは現地通貨です。APIの従量課金表は確認できませんでしたが、レート制限と429応答があります。利用者のApple Music契約とは分けて扱います。[加入料金](https://developer.apple.com/help/account/membership/program-enrollment)、[API要件](https://developer.apple.com/documentation/applemusicapi/generating-developer-tokens)

## 未契約者の試聴に関する判断

カタログに試聴URLがあることと、ネイティブMusicKitのプレイヤーが未契約者向けに自動で試聴へ切り替わることは別です。ApplicationMusicPlayerで再生を呼べば未契約でも試聴できる、という仕様は確認できていません。

実装はMusicKitで認可・Developer Token・利用者のStorefrontを取得し、カタログREST APIから試聴URLを取得して、ユーザー操作でAVPlayerに渡す構成です。検索や試聴の前に有料会員かどうかだけで利用を拒否する実装にはしません。シミュレーターでの実通信は確認済みですが、未契約実機での挙動と利用条件への適合は検証が必要です。

カタログ通信ではDeveloper Tokenのみをヘッダーに渡し、Music User Tokenは送信しません。ただし、先行するMusicKit認可やStorefront取得が未契約端末で成立することを実証したわけではありません。秘密鍵の埋め込みやサーバーによる独自署名は追加していません。

WWDC26の新しいMusic Pickerは未契約時にユーザーのライブラリだけを表示する、と説明されています。未契約者の楽曲検索要件をそのまま満たす根拠にはならず、今回は既存の検索画面を維持する設計です。[WWDC26](https://developer.apple.com/videos/play/wwdc2026/254/)

## 利用条件とBeRealの位置付け

BeReal公式ヘルプは、アカウント連携、撮影時に聴いていた曲の共有、投稿からの試聴、音楽サービスへの移動を説明しています。Spotifyも連携を公式発表しています。試聴の供給元や個別契約は公開資料から確定できません。[BeReal](https://help.bereal.com/hc/en-us/articles/10499233725469-BeReal-Audio)、[Spotifyの発表](https://newsroom.spotify.com/2023-04-19/our-new-integration-allows-you-to-share-music-and-podcasts-on-bereal-heres-how/)

Appleの審査ガイドライン5.2.5には、写真コラージュのBGMなど娯楽目的のプレビュー利用の制限と、該当曲へのリンク表示が記載されています。4.5.2は、ユーザーが開始する再生、標準操作、音楽ファイルの共有制限、複雑な音楽演出に必要な権利を扱っています。[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

Developer Program契約3.3.6 Dには、他コンテンツとの同期、音源の変更・アップロード等、再生やプレイリストと独立した画像・テキスト利用への制限、およびMusicKit再生でのフル楽曲提供に関する条件があります。一般の音源素材ライセンスとして扱うことはできません。[契約](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)

PicTuneは現在、静止画の下に楽曲情報を置き、タップで試聴する構成です。写真に曲を紐づけることだけを一律禁止とは断定できませんが、試聴を思い出のBGMとして提供する用途が許可されるとも断定できません。外部リンク・明示的な再生操作を付けるだけで自動的に適合するわけではありません。

用途確認時には、写真詳細画面、曲選択画面、手動再生、未契約者への試聴、QR・NFCによる曲情報共有、音声ファイルの書き出しがない点を正確に示します。Appleへの問い合わせは未送信です。

## 実装した変更

| 対象 | 内容 |
| --- | --- |
| AppleMusicAPI | 認可・Developer Token自動取得・利用者のStorefrontによる検索。通信中断、401/403、404、429を処理 |
| SearchViewModel / SearchView | Apple Musicへ検索を切り替え。既存の検索履歴・待機・古い応答破棄・選択保持を維持し、公式曲リンクを表示 |
| Track / FirebaseMusic | サービス種別・曲リンク・Storefront・ISRCの保存と復元。旧SpotifyデータはSpotifyのまま扱う |
| CameraManager | 本人とQR共有相手に同じ楽曲データを保存 |
| PhotoRecord / FirebaseMusic / PhotoLibraryRepository | 新旧データの読み込み。NFC・フォルダコピーでは保存内容を維持し、新しい写真ドキュメントIDと楽曲IDを区別して復元 |
| MusicPreviewPlayer / ImageDetailView | 明示的な試聴・停止、試聴なし・取得失敗表示、サービスリンク。画面を閉じたときに停止 |
| Info.plist | NSAppleMusicUsageDescriptionを追加 |
| Xcode設定 | ソース登録、UIテスト対象名を実際のPIcTuneへ修正。Bundle ID・署名チームは変更なし |
| UIGIFImageView | クリーンビルドで判明した既存のSwiftyGif import不足を1行補完 |

Spotify検索実装とそこにあったクライアント秘密情報は現在のソースから削除しました。過去のGit履歴やSpotify側の認証情報は変更・失効していません。

試聴前にApple Musicの曲IDを利用者のStorefrontで再取得します。配信停止や地域差で取得できない場合は、保存済みの古い試聴URLにフォールバックせずエラーを表示します。旧Spotify曲は既存の試聴URLを使用するため、URLの失効等で再生できない場合があります。

## 保存データの互換設計

以下の保存・復元処理を実装しました。外部Firestoreへの保存・共有の実通信は未確認です。

- 新規保存にmusicProvider = appleMusic、Appleの楽曲ID、musicURL、storefront、必要に応じてisrcを保存します。既存の曲名・アーティスト等のキーは維持します。
- providerがなく楽曲IDがある既存レコードはSpotifyとして読みます。曲なしレコードはそのまま扱います。
- Spotify IDをApple IDとして解釈しません。既存曲の一括自動変換や削除は行いません。
- 試聴URLを永久に有効な保存データと見なしません。AppleのIDを起点に地域と最新の取得結果を確認し、取得できない場合でも写真と手紙を閲覧できるようにします。
- QR・フォルダコピー・NFCでサービス種別と曲リンクも引き継ぎます。共有先に音声ファイルや認証トークンは保存しません。
- ISRC照合は将来移行時の手段ですが、現行データにISRCはなく、同じISRCで複数結果もあり得ます。今回の移行では旧曲の変換は行っていません。[ISRC検索](https://developer.apple.com/documentation/applemusicapi/get-multiple-catalog-songs-by-isrc)

## 開発者設定

現在のアプリBundle IDはcom.hosonuma.sakki.sotsugyou、署名チームはTVH687AC7Fです。アプリのDeployment TargetはiOS 18.0です。これらはローカル設定であり、Developer Programの有効状態やPortalでの権限を証明しません。

Apple DeveloperのCertificates Identifiers and Profilesで、対象App IDのApp ServicesにあるMusicKitを有効にする必要があります。アプリのBundle IDを一致させます。2026年10月6日にPortalで同じTeam IDとBundle IDを確認し、ユーザーの承認を受けてMusicKit App Serviceを有効化しました。Save・Confirm後に対象App IDを開き直し、MusicKitがチェック済みで保存されていることを確認しました。FirebaseのSign in with Appleが実装済みでも、MusicKit設定が有効とは限りません。

MusicKitはランタイムサービスとしてApp IDに関連付くため、entitlementsにキーが見当たらないことだけでPortal側が無効とは判断しません。[公式設定手順](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)

## 検証結果

検証環境はXcode 27.2 Beta 2（iOS 27.2 SDK）、iPhone 18 Proシミュレーター（iOS 27.0）です。Deployment TargetはiOS 18.0を維持しています。

単体テストは、APIリクエスト形式、試聴URLなし、認可拒否、検索結果なし、429、利用者側Storefront、配信停止時に古いURLを使用しないこと、新旧データ互換、停止後の遅延応答を固定データで検証します。UIテストは実際のSwiftUI画面をDebug専用の固定データで起動し、検索・選択・結果なし・認可拒否・写真詳細の試聴なし表示を操作します。

2026年10月6日に最新mainを統合した後の `xcodebuild test` は成功しました。単体テスト15件、対象UIテスト2件で失敗0件です。アプリ・ウィジェット・テストターゲットをシミュレーター向けにビルドしています。署名を無効にしたDebugビルドであり、実機署名・Release配布の確認ではありません。

```sh
xcodebuild -project PIcTune.xcodeproj -scheme PIcTune -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro,OS=27.0' \
  test -only-testing:PIcTuneTests \
  -only-testing:PIcTuneUITests/sotsugyoUITests/testAppleMusicSearchSelectionEmptyAndDeniedStates \
  -only-testing:PIcTuneUITests/sotsugyoUITests/testPhotoDetailExplainsMissingPreview \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO
```

初回ビルド時に既存GIFコードのimport不足とUIテスト対象名の不一致を修正しました。初回UIテストの「追加」ボタン確認は、検索中にナビゲーションバーが隠れるOSの挙動に合わせ、検索を閉じてから確認する手順へ修正しました。

画面は固定データによるものです。実在する楽曲名を使用していますが、その曲の試聴配信の有無を示すものではありません。

- [検索・選択](screenshots/apple-music-search.png)
- [認可拒否時の表示](screenshots/apple-music-permission.png)
- [写真詳細・試聴音源なし](screenshots/apple-music-detail.png)

### 追加の接続検証（2026年10月6日）

接続済みiPhone 18 Pro（iOS 27.0、Developer Mode有効）向けの署名付きアプリビルドと `build-for-testing` は成功しました。実機テストはロック解除待ちで起動できず停止しました。その後のユーザー指定により、専用のiPhone 18 Proシミュレーター（iOS 27.0、名前 `PicTune Apple Music Check`）へ検証先を切り替えました。

専用シミュレーターで、単体テスト15件、固定データを使うUIテスト2件、実接続UIテスト1件の成功をそれぞれ確認しました。実接続テストは、本番と同じ検索・再取得・再生クラスをDebug確認画面から使用しています。

- 認可状態 `.authorized`、Storefront `jp` を確認。
- 検索語「YOASOBI アイドル」でHTTP 200、25曲を取得。
- YOASOBI「アイドル」の楽曲情報・アートワークを取得。
- 試聴の前に曲を再取得し、AVPlayerが再生中になり再生位置が3秒以上進むことを確認。
- 停止操作後に停止中へ戻ることを確認。音の聴取確認は行っていません。

初回はアクセス許可画面でテストがスキップされ、その後の実行では認可済み状態になりました。初期の1回はカタログAPIから401または403が返りましたが、後続実行ではHTTP 200でした。認証エラーの原因は特定しておらず、解消理由を設定反映やキャッシュ更新と断定しません。初期の検証ではプレイヤーは再生中でしたが、画面下部の再生位置を判定するテストが失敗しました。確認画面のタイトルをコンパクトにすると判定が成功したため、表示位置の影響と考えられます。最終手順では再生位置を画面内に表示してから判定します。

最終実行の実接続UIテストは1件、失敗0件でした。ログに `Live preview verification: 再生位置: 3秒` を記録しています。以下は固定データではなく、実サービスへ接続したDebug確認画面です。

- [検索成功：HTTP 200、25曲](screenshots/apple-music-live-search.png)
- [試聴中：再生位置3秒](screenshots/apple-music-live-playing.png)
- [停止後：再生位置0秒](screenshots/apple-music-live-stopped.png)

シミュレーターで契約情報を取得できていないため、この結果を「未契約実機でも必ず再生できる」の証明とは扱いません。

Debug限定の `--music-live-check` 起動経路を追加しました。本番と同じAppleMusicAPIとMusicPreviewPlayerを使用し、実検索、取得した曲の試聴、再生位置、停止を確認できます。Firebaseへの写真保存や共有は実行しません。表示する `canPlayCatalogContent` はフル楽曲再生の可否であり、課金・契約状態そのものを証明しません。

自動テストは `sotsugyoUITests/testLiveAppleMusicSearchPlaybackAndStop` です。明示的にテストプロセスの環境変数 `PICTUNE_RUN_LIVE_MUSIC=1` を設定したときだけ実行し、通常のテストではスキップします。システムの権限画面が出た場合もスキップし、新しい権限を自動許可しません。成功条件は検索結果取得、試聴の再生位置が3秒以上進むこと、停止状態への遷移です。再生時間の進行を音の聴取確認とは区別します。

### 採用時のmain統合（2026年10月6日）

ユーザーの採用指示に従って、写真・フォルダのModel統一（PR #37）を取り込みました。写真詳細は `LibraryPhoto.record.music` を使用し、写真と曲の対応を維持します。保存時の `Track → FirebaseMusic → PhotoRecord` と読み込み時の逆経路で、サービス種別・曲リンク・Storefront・ISRC・アルバム名を引き継ぐよう統合しました。コピー先の写真IDを用いてもApple Musicの楽曲情報が失われないことを回帰テストに追加しています。

統合後の `build-for-testing` と `test-without-building` は成功しました。iPhone 18 Proシミュレーター（iOS 27.0）で単体テスト39件、UIテスト8件（実接続1件を含む）、失敗0件でした。実接続では検索25曲、HTTP 200、試聴の再生位置3秒、停止を再確認しました。検索・写真詳細・実接続のスクリーンショットは統合後の実行結果に更新しています。フォルダ・手紙・設定・写真編集も固定データで確認しました。NFCテストの成功はシミュレーターでの利用不可表示の確認であり、実機での送受信成功を意味しません。

### 未確認・公開前に必要な確認

- 署名済みアプリによるトークン発行と実機起動の確認。署名付きビルドとMusicKit有効化は完了していますが、実機でのトークン発行は未確認です。
- 未契約・契約済み実機での認可、トークン取得、検索、アートワーク取得、試聴の実再生、停止・終了・失敗、地域差。
- Firebaseへの本人・QR相手への実保存、フォルダコピー、NFC取り込み。保存形式とコピー経路のコード確認を実機動作確認とは扱いません。
- AppleへのPicTune用途確認。プレビューを写真のBGMとして利用してよいと確定したわけではなく、問い合わせも送信していません。
