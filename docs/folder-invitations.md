# 招待リンクによる共有フォルダ

## 仕様

- フォルダ詳細の「リンクで共有」から、256 bit相当のランダムな招待トークンを含むHTTPSリンクを発行します。リンクの参加期限は7日です。同じフォルダの有効なリンクを再利用でき、無効化後は再発行できます。
- リンクを知っているログイン済みの利用者が参加できます。未ログイン時は招待を保持し、ログイン後に受け取り画面へ戻ります。
- 参加者は閲覧専用です。元フォルダの写真・楽曲情報・手紙の変更をFirestoreのリスナーで表示します。受信者のフォルダ一覧には「共有されたフォルダ」として表示します。
- 参加処理は共有権限と受信一覧への参照を1バッチで保存します。同じ招待の再試行ではフォルダが重複しません。
- リンクの無効化・期限切れは新しい参加を停止します。参加済みの利用者との共有は継続します。元フォルダの削除後は閲覧できなくなります。
- 成功した参加処理の後だけ、封筒からカードが現れ、光と粒子が広がる演出と触覚フィードバックを表示します。Reduce Motionでは粒子を表示せず、短い切り替えにします。
- Webページはアプリを開く案内のみです。写真・手紙・フォルダ名や送り主の個人情報をWebページへ表示しません。未インストールの場合は最新版のインストール後に元のリンクを開き直します。自動的なインストール後復帰は実装していません。

## データと権限

- `folderInvites/{token}`: 送り主、対象フォルダ、表示用タイトル・名前、期限、無効化状態。全件一覧取得は禁止です。
- `users/{uid}/folderInviteLinks/{folderID}`: 送り主が再利用・無効化するためのリンク参照。
- 元フォルダの `sharedWith`: 閲覧できる利用者ID。参加時には有効な招待をルールで照合します。
- `users/{uid}/sharedFolders/{stableID}`: 受信者の一覧に表示する参照。IDは送り主とフォルダIDのSHA-256です。
- `imageOwners/{fileName}`: 画像所有者。クライアントによる変更・削除は禁止です。移行時の既存コピーには `legacyReaders` を保持します。
- Storageの `ownerIDs` メタデータと、`users/{uid}/imageAccess/{fileName}` により画像閲覧を制限します。画像への参照を偽造するだけでは閲覧できません。共有画像のStorage読取では元フォルダの共有権限も確認します。
- すでに画面で見た内容や保存したコピーを相手の端末から回収する機能はありません。

## NFC・QRとの互換性

- NFCには同じ招待HTTPSリンクをURIレコードとして保存します。有効期限は7日です。旧形式の「UID フォルダID」は受け付けず、最新アプリでカードを書き直す案内を表示します。
- 撮影相手のQRは `pictune-camera:{token}` の招待に変更しました。15分間有効で、他人のUIDだけでは相手の写真一覧へ保存できません。相手のメールアドレス等を読み取る処理も不要になりました。
- QRで撮影した写真は従来どおり両者へ保存します。招待された撮影者だけが有効期間内に相手の写真を作成できます。相手の既存写真を編集・削除する権限はありません。
- Widgetは公開画像URLを使用せず、認証済みアプリがApp Groupに保存したローカル画像を読みます。未保存時やログアウト時は空の状態を扱います。
- 本番ルール切り替え後、旧版アプリの撮影保存・旧NFC/QR共有は利用できません。アプリの更新が必要です。

## Firebaseの反映

対象プロジェクトは `sotugyou-7ea16` です。作業前のFirestoreとStorageはいずれも全公開のルールだったため、今回の招待制に合わせたルールをリポジトリへ追加しました。

```sh
# 読み取りのみの移行対象確認
python3 firebase/scripts/migrate_image_access.py
# メタデータのバックアップ、既存画像の所有者登録、旧公開トークンの無効化
python3 firebase/scripts/migrate_image_access.py --apply
firebase deploy --only firestore:rules,storage,hosting --project sotugyou-7ea16
```

StorageからFirestoreの招待権限を参照するため、Storageサービスアカウント `service-592210612826@gcp-sa-firebasestorage.iam.gserviceaccount.com` に `roles/firebaserules.firestoreServiceAgent` が必要です。今回は利用者の明示承認後に付与済みです。[Firebase公式手順](https://firebase.google.com/docs/rules/manage-deploy#manage_permissions_for_cross-service)に基づくFirestore読み取り用の権限です。

移行処理は写真本体や写真ドキュメントを変更・削除しません。バックアップは `/tmp/pictune-image-access-backup-*.json` にアクセス制限付きで保存します。既存写真から参照されない画像のファイル名も予約し、第三者による所有権の取得を防ぎます。公開URLの旧トークンは無効になります。

## 検証

```sh
npm --prefix firebase ci
firebase emulators:exec --config firebase/emulators.json --project demo-pictune-invites \
  --only firestore,storage 'node --test firebase/tests/invitations.test.mjs'
```

実サービスの検証は `firebase/scripts/verify_live_invitation.mjs` にあります。明示的な環境変数と `/tmp` の接続設定を使い、新規の確認用アカウント・フォルダ・画像だけを作成し、確認後に削除します。所有権レコードは不正な再登録防止のためクライアントから削除できないので、検証後は管理APIで該当レコードを削除します。

画面・テスト・本番反映の結果は [確認記録](verification/invite-links/README.md) を参照してください。
