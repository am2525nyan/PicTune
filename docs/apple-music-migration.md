# Apple Music移行調査

調査日：2026年10月6日。PicTuneの音楽連携をApple Musicへ移すため、公式資料、既存コード、ローカルSDKを確認しました。アプリ本体への移行は未実装です。

検索と曲情報取得の実装手段は確認できました。未契約者の試聴を目標としますが、PicTuneのApp IDでのトークン発行、未契約端末での検索、試聴の実再生は未確認です。BeRealで未契約でも音が出たというユーザーの観察は、PicTuneでの動作や利用許諾を保証するものではありません。

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

第一検証経路はMusicKitの検索から試聴URLを取得し、ユーザー操作でAVPlayerに渡す構成です。検索や試聴の前に有料会員かどうかだけで利用を拒否する実装にはしません。ただし、この構成の実通信・利用条件への適合は検証が必要です。

ネイティブ検索が未契約端末で成立しない場合は、Developer Tokenのみを使うカタログRESTリクエストを切り分けます。DefaultMusicTokenProviderのAPIも型チェックしましたが、ユーザー認可を省略できると確認したわけではありません。サーバーで署名する構成を採る場合はMedia IDと秘密鍵の管理が別途必要で、秘密鍵をアプリには埋め込みません。

WWDC26の新しいMusic Pickerは未契約時にユーザーのライブラリだけを表示する、と説明されています。未契約者の楽曲検索要件をそのまま満たす根拠にはならず、今回は既存の検索画面を維持する設計です。[WWDC26](https://developer.apple.com/videos/play/wwdc2026/254/)

## 利用条件とBeRealの位置付け

BeReal公式ヘルプは、アカウント連携、撮影時に聴いていた曲の共有、投稿からの試聴、音楽サービスへの移動を説明しています。Spotifyも連携を公式発表しています。試聴の供給元や個別契約は公開資料から確定できません。[BeReal](https://help.bereal.com/hc/en-us/articles/10499233725469-BeReal-Audio)、[Spotifyの発表](https://newsroom.spotify.com/2023-04-19/our-new-integration-allows-you-to-share-music-and-podcasts-on-bereal-heres-how/)

Appleの審査ガイドライン5.2.5には、写真コラージュのBGMなど娯楽目的のプレビュー利用の制限と、該当曲へのリンク表示が記載されています。4.5.2は、ユーザーが開始する再生、標準操作、音楽ファイルの共有制限、複雑な音楽演出に必要な権利を扱っています。[App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)

Developer Program契約3.3.6 Dには、他コンテンツとの同期、音源の変更・アップロード等、再生やプレイリストと独立した画像・テキスト利用への制限、およびMusicKit再生でのフル楽曲提供に関する条件があります。一般の音源素材ライセンスとして扱うことはできません。[契約](https://developer.apple.com/support/terms/apple-developer-program-license-agreement/)

PicTuneは現在、静止画の下に楽曲情報を置き、タップで試聴する構成です。写真に曲を紐づけることだけを一律禁止とは断定できませんが、試聴を思い出のBGMとして提供する用途が許可されるとも断定できません。外部リンク・明示的な再生操作を付けるだけで自動的に適合するわけではありません。

用途確認時には、写真詳細画面、曲選択画面、手動再生、未契約者への試聴、QR・NFCによる曲情報共有、音声ファイルの書き出しがない点を正確に示します。Appleへの問い合わせは未送信です。

## 現在の実装と変更範囲

| ファイル | 確認した内容と移行時の対応 |
| --- | --- |
| sotsugyo/Utils/SpotifyAPI.swift | Client Credentialsによる検索をApple用検索処理へ置換します。現行の秘密情報は文書・ログへ転記しません |
| sotsugyo/ViewModel/searchMusicViewModel.swift | SearchOperationを差し替えます。検索待機・古い検索結果の破棄・履歴は維持します |
| sotsugyo/Model/Track.swift | provider、曲へのリンク、Storefront等を追加する設計です |
| sotsugyo/Model/FirebaseMusic.swift | 保存データからサービス種別を復元できるようにします |
| sotsugyo/Utils/CameraManager.swift | 写真と楽曲情報を本人・QR共有相手へ同じ形式で保存します |
| sotsugyo/ViewModel/MainContentModel.swift | 新旧データの読み込み、試聴の再取得・失敗表示、NFC受信時の読み込みを扱います |
| sotsugyo/View/ImageDetailView.swift | 手動の再生・停止、試聴不可、曲へのリンクを表示する設計です |
| sotsugyo/Info.plist | MusicKit利用理由を追加します。現時点ではキーがありません |
| PIcTune.xcodeproj | App IDと署名チームをApple側の登録に合わせます |

NFC取り込みではaddDocumentで新IDを生成した直後に元IDで読み戻しており、楽曲情報を取得できない経路があります。Apple移行に伴う共有確認で扱う必要があります。既存処理の存在を共有動作確認済みとは扱いません。

## 保存データの互換設計

以下は未実装の設計です。

- 新規保存にmusicProvider = appleMusic、Appleの楽曲ID、musicURL、storefront、必要に応じてisrcを持たせます。既存の曲名・アーティスト等のキーは可能な範囲で維持します。
- providerがなく楽曲IDがある既存レコードはSpotifyとして読みます。曲なしレコードはそのまま扱います。
- Spotify IDをApple IDとして解釈しません。既存曲の一括自動変換や削除は行いません。
- 試聴URLを永久に有効な保存データと見なしません。AppleのIDを起点に地域と最新の取得結果を確認し、取得できない場合でも写真と手紙を閲覧できるようにします。
- QR・フォルダコピー・NFCでサービス種別と曲リンクも引き継ぎます。共有先に音声ファイルや認証トークンは保存しません。
- ISRC照合は将来移行時の手段ですが、現行データにISRCはなく、同じISRCで複数結果もあり得ます。今回の調査では旧曲の変換は行っていません。[ISRC検索](https://developer.apple.com/documentation/applemusicapi/get-multiple-catalog-songs-by-isrc)

## 開発者設定

現在のアプリBundle IDはcom.hosonuma.sakki.sotsugyou、署名チームはTVH687AC7Fです。アプリのDeployment TargetはiOS 18.0です。これらはローカル設定であり、Developer Programの有効状態やPortalでの権限を証明しません。

Apple DeveloperのCertificates Identifiers and Profilesで、対象App IDのApp ServicesにあるMusicKitを有効にする必要があります。アプリのBundle IDを一致させます。この調査ではPortal設定を確認・変更していません。FirebaseのSign in with Appleが実装済みでも、MusicKit設定が有効とは限りません。

MusicKitはランタイムサービスとしてApp IDに関連付くため、entitlementsにキーが見当たらないことだけでPortal側が無効とは判断しません。[公式設定手順](https://developer.apple.com/documentation/musickit/using-automatic-token-generation-for-apple-music-api)

## 検証結果と次の実装順序

Xcode 27.2 Beta 2のiOS 27.2 SDKを使い、Swift 5モード、iOS 18.0ターゲットで次を型チェックし、終了コード0を確認しました。

- MusicCatalogSearchRequestからSongを取得し、既存モデル相当の値へ変換する処理。
- DefaultMusicTokenProviderからDeveloper Tokenを要求し、日本カタログのURLRequestを構成する処理。
- 試聴URLからAVPlayerを構成する処理。

これは一時ファイルによるAPIの型検証です。App IDでの認可・トークン発行、実通信、試聴再生、アプリ全体のビルド成功を意味しません。検証コードでは認可・HTTPエラー処理等を省略しており、本番実装として使用しません。

実装は、対象App IDの設定確認、未契約実機での検索・試聴検証、検索の差し替えと新旧データ互換、写真詳細・共有の確認の順に進める設計です。認可拒否・制限、未契約・契約済み、検索結果なし、試聴なし、通信失敗、配信停止、異なるStorefrontを確認対象にします。

アプリの実装変更、ビルド・単体テスト、シミュレーター起動、実機再生、QR・NFC、Appleへの用途確認は未実施です。調査文書だけを追加しています。
