# セットアップガイド - Google Sheets & Drive 連携

このガイドでは、flogアプリでGoogle SheetsとGoogle Driveにログをアップロードするための設定方法を説明します。

## 前提条件

- Googleアカウント
- Google Drive APIが有効（[DRIVE_API_SETUP.md](DRIVE_API_SETUP.md)参照）

## 重要な注意事項

**Spreadsheet IDとFolder IDは異なります！**

- **Spreadsheet ID**: Google Sheetsのスプレッドシートの ID
- **Folder ID**: Google Driveのフォルダの ID

両方が必要です。混同しないように注意してください。

## ステップ1: フォルダの作成

1. **Google Driveを開く**
   - https://drive.google.com/ にアクセス

2. **新しいフォルダを作成**
   - 「新規」ボタンをクリック
   - 「フォルダ」を選択
   - フォルダ名を入力（例: "ActivityLogs"）
   - 「作成」をクリック

3. **Folder IDを取得**
   - 作成したフォルダをダブルクリックして開く
   - ブラウザのアドレスバーを確認
   - URLは以下の形式：
     ```
     https://drive.google.com/drive/folders/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms
     ```
   - `folders/` の後ろの部分がFolder ID：
     ```
     1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms
     ```
   - この文字列をコピーしてメモ帳などに保存

## ステップ2: Spreadsheetの作成

1. **同じフォルダ内にSpreadsheetを作成**
   - ステップ1で作成したフォルダを開く（重要！）
   - 「新規」ボタンをクリック
   - 「Google スプレッドシート」を選択
   - 新しいSpreadsheetが作成される

2. **Spreadsheet IDを取得**
   - Spreadsheetが開いた状態で、ブラウザのアドレスバーを確認
   - URLは以下の形式：
     ```
     https://docs.google.com/spreadsheets/d/1Wkb4aijxcUqKvrRaATIvfVywi3JNniEpRBzeLJ53B70/edit
     ```
   - `/d/` と `/edit` の間の部分がSpreadsheet ID：
     ```
     1Wkb4aijxcUqKvrRaATIvfVywi3JNniEpRBzeLJ53B70
     ```
   - この文字列をコピーしてメモ帳などに保存

## ステップ3: アプリでの設定

1. **アプリを起動**
   - flogアプリを開く

2. **設定画面を開く**
   - ログ一覧画面の右上の「設定」アイコンをタップ

3. **Googleアカウントでサインイン**
   - 「Googleでサインイン」ボタンをタップ
   - Googleアカウントを選択
   - 必要な権限を承認
     - Google Sheets API
     - Google Drive API

4. **Spreadsheet IDを入力**
   - 「Spreadsheet ID」の入力欄に、ステップ2で取得したIDをペースト
   - 例: `1Wkb4aijxcUqKvrRaATIvfVywi3JNniEpRBzeLJ53B70`

5. **Folder IDを入力**
   - 「Folder ID」の入力欄に、ステップ1で取得したIDをペースト
   - 例: `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms`

6. **保存**
   - 「保存」ボタンをタップ
   - 設定が検証され、正しければ「設定を保存しました」と表示される

## ステップ4: テストアップロード

1. **ログを作成**
   - ログ一覧画面の「+」ボタンからログを作成
   - テキスト、音声、画像などを追加

2. **アップロード**
   - ログ一覧画面の右上の「アップロード」アイコン（雲）をタップ
   - 確認ダイアログで「アップロード」をタップ

3. **結果確認**
   - 成功すると「Xログをアップロードしました」と表示される
   - Google Sheetsを開いて、データが追加されているか確認
   - Google Driveのフォルダ内に「files」フォルダが作成され、メディアファイルがアップロードされているか確認

## トラブルシューティング

### エラー: "Spreadsheetが見つかりません"

**原因:**
- Spreadsheet IDが間違っている
- Spreadsheet IDとFolder IDを混同している
- サインインしているアカウントにSpreadsheetへのアクセス権がない

**解決方法:**
1. Spreadsheet IDを再確認
   - SpreadsheetのURLから `/d/` と `/edit` の間の文字列をコピー
   - 余計な文字が含まれていないか確認
2. アクセス権限を確認
   - Spreadsheetで「共有」をクリック
   - サインインしているGoogleアカウントが「編集者」権限を持っているか確認

### エラー: "フォルダが見つかりません"

**原因:**
- Folder IDが間違っている
- Folder IDとSpreadsheet IDを混同している
- サインインしているアカウントにフォルダへのアクセス権がない

**解決方法:**
1. Folder IDを再確認
   - Google DriveでフォルダのURLから `folders/` の後ろの文字列をコピー
   - 余計な文字が含まれていないか確認
2. アクセス権限を確認
   - フォルダで「共有」をクリック
   - サインインしているGoogleアカウントが「編集者」権限を持っているか確認

### エラー: "Google Drive APIが有効になっていません"

**解決方法:**
[DRIVE_API_SETUP.md](DRIVE_API_SETUP.md) の手順に従って、Google Drive APIを有効化してください。

### 設定が保存できない

**確認事項:**
1. Googleアカウントでサインインしているか
2. インターネットに接続しているか
3. Spreadsheet IDとFolder IDの両方を入力したか
4. IDに余計なスペースや改行が含まれていないか

## ID取得のチェックリスト

設定を保存する前に、以下を確認してください：

- [ ] Google Driveでフォルダを作成した
- [ ] フォルダを開いた状態でURLからFolder IDをコピーした
- [ ] 同じフォルダ内にSpreadsheetを作成した
- [ ] SpreadsheetのURLからSpreadsheet IDをコピーした
- [ ] Spreadsheet IDとFolder IDを混同していない
- [ ] アプリでGoogleアカウントにサインインした
- [ ] 両方のIDを正しく入力した
- [ ] 「保存」ボタンをクリックした

## よくある質問

### Q: Spreadsheet IDとFolder IDの違いは？

A:
- **Spreadsheet ID**: Google Sheetsのスプレッドシートを識別するID。URLに `docs.google.com/spreadsheets/d/` が含まれる
- **Folder ID**: Google Driveのフォルダを識別するID。URLに `drive.google.com/drive/folders/` が含まれる

### Q: 既存のSpreadsheetとフォルダを使用できますか？

A: はい、できます。ただし、以下の条件を満たす必要があります：
- Spreadsheetがフォルダ内にある
- サインインしているアカウントに両方への編集権限がある

### Q: 複数のSpreadsheetで同じフォルダを使用できますか？

A: はい、可能です。複数のSpreadsheetで同じFolder IDを設定できます。

### Q: フォルダ名やSpreadsheet名は何でも良いですか？

A: はい、任意の名前を使用できます。IDが正しければ問題ありません。

## 参考リンク

- Google Drive: https://drive.google.com/
- Google Sheets: https://docs.google.com/spreadsheets/
- Drive API Setup: [DRIVE_API_SETUP.md](DRIVE_API_SETUP.md)
- Troubleshooting: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)
