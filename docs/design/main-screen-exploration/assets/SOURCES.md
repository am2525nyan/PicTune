# 使用素材

写真は画面比較のための代替素材です。利用者の写真ではありません。2026年10月19日に各作品ページの配布条件と画像の取得を確認しました。日付や楽曲の紐づけは架空です。

| ファイル | 写真家 | 作品ページ |
|---|---|---|
| coast.jpg | Seungmin Yoon | https://unsplash.com/photos/coastal-town-with-train-tracks-and-mount-fuji-in-distance-cdVJkgjkHvA |
| beach.jpg | Shuto Araki | https://unsplash.com/photos/calm-blue-body-of-water-surrounded-by-mountains-HND8I5UpYFs |
| cafe.jpg | Leongsan | https://unsplash.com/photos/people-sit-at-tables-by-a-large-window-2-yrpoyXS_8 |

写真：Unsplash License https://unsplash.com/license 。リサイズ済みJPEGを比較資料用に保存しています。元ファイルには加工を加えず、表示時のみ切り抜きます。

`zen-maru-display.ttf`：Google FontsのZen Maru Gothic Bold。見出しに必要な文字のサブセットです。全言語・全画面に使えるフォントではありません。
配布元：https://github.com/google/fonts/tree/main/ofl/zenmarugothic 。ライセンス：同梱 `ZenMaruGothic-OFL.txt`（SIL Open Font License）。

`device.css`・`device.js`：ユーザーが指定したapp-designerスキルのdevice kitを同梱。SF Pro／New YorkはmacOS上のシステムフォントを参照し、フォント本体を再配布しません。日本語明朝はOSの游明朝／ヒラギノ明朝にfallbackします。
アイコン：explore.js内で作図したSF Symbols風のSVG（stroke 1.8pt）。実装時の対応：`camera`、`music.note`、`photo.on.rectangle`、`folder`、`gearshape`、`chevron.right`、`xmark`。

既存画面の参照：`docs/screenshots/photo-folder-toolbar/photos.png`。既存チェキ枠とAppIconは監査しましたが、画面案でAppIconの改変・差し替えは行っていません。

## ポップ＆キュート版の追加素材

`mochiy-pop-display.ttf`：Google FontsのMochiy Pop One Regular。`PicTune`と`写真`だけの表示用サブセットです。配布元：https://github.com/google/fonts/tree/main/ofl/mochiypopone 。ライセンス：同梱 `MochiyPopOne-OFL.txt`（SIL Open Font License）。

リボン・花・ハート・手描き線は、既存チェキフレームのモチーフを参考にexplore.js内で作図したSVGです。既存JPGの黒背景を透明化したり、生成画像で置き換えたりしていません。トイカメラはCSSで構成した表示用の図形です。
