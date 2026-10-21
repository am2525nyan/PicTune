# オンボーディング比較用のチェキ

`onboarding-five-patterns.html` は、ご本人のPicTuneに保存されているデコチェキを使用します。02・03にはiOS 27から取得した別の2枚を使用します。

| ファイル | 内容 |
| --- | --- |
| `user-cheki-pink.jpg` | ピンクの手描きでデコったチェキ |
| `user-cheki-yellow.jpg` | 黄色とラベンダーの手描きでデコったチェキ（01・04〜09） |
| `user-cheki-pink-pair.jpg` | ピンクの手描きと猫のイラストを添えた2人のチェキ（02・03） |
| `user-cheki-purple-pair.jpg` | 黄色と紫の手描きを添えた2人のチェキ（02・03） |

従来の `user-cheki-pink.jpg` と `user-cheki-yellow.jpg` は、iOS 18.5で取得したユーザーのアカウント内の写真です。写真詳細に表示されたチェキの部分だけを切り出し、JPEGに変換しました。比較用に作成した以前のサンプル画像は今回のHTMLでは使用しません。


02・03の新しい2枚は、2026年10月19日に「PicTune Onboarding iOS 27」（iOS 27.0）で表示を確認し、ログイン済みアプリが取得したJPEGデータをそのまま保存しました。撮影日時はそれぞれ2024年1月12日16:24・16:26です。トリミング・再圧縮・追加の画像加工はしていません。一時的な書き出し処理は取得後に撤去し、シミュレーターも通常版へ戻しています。

HTMLでは元の縦横比を保ってチェキ全体を表示します。02は新しい縦長画像に合わせて位置とサイズを調整しました。以前比較に使った花・コーヒーのストック写真は使用しません。

## 02のフォント

- **Zen Maru Gothic Bold** — The Zen Maru Gothic Authors
- [Google Fonts 配布元](https://github.com/google/fonts/tree/main/ofl/zenmarugothic)
- `ZenMaruGothic-Bold.ttf` を同梱し、02の日本語の見出し・ボタン・手紙のメモに使用。
- SIL Open Font License 1.1。ライセンス全文は `ZenMaruGothic-OFL.txt` に同梱。
- 02の英語の飾り文句（TO YOU・GOOD TIMES・FOR YOU）は削除。筆記体・セリフ体・イタリック体を使用していません。
