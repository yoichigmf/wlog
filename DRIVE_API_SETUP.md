# Google Drive API セットアップ手順

このアプリでファイルのアップロード機能を使用するには、Google Cloud ConsoleでGoogle Drive APIを有効にする必要があります。

## エラーメッセージ

以下のようなエラーが表示された場合、Drive APIが有効になっていません：

```
Google Drive API has not been used in project XXXXXX before or it is disabled.
```

または

```
Google Drive APIが有効になっていません。
```

## セットアップ手順

### 1. Google Cloud Consoleにアクセス

https://console.cloud.google.com/ にアクセスしてください。

### 2. プロジェクトを選択

- 画面上部のプロジェクト選択ドロップダウンから、このアプリで使用しているプロジェクトを選択します
- エラーメッセージに表示されているプロジェクト番号（例: `498406748569`）と一致するプロジェクトを選択してください

### 3. APIとサービスに移動

- 左側のハンバーガーメニュー（☰）をクリック
- 「APIとサービス」→「ライブラリ」を選択

または、直接以下のURLにアクセス：
https://console.cloud.google.com/apis/library

### 4. Google Drive APIを検索

- 検索ボックスに「Google Drive API」と入力
- 検索結果から「Google Drive API」を選択

### 5. APIを有効化

- 「有効にする」ボタンをクリック
- 有効化には数分かかる場合があります

### 6. アプリを再起動

- APIが有効になったら、アプリからサインアウトして再度サインインしてください
- これにより、新しいDrive API権限が適用されます

## 確認方法

APIが正しく有効になっているかを確認するには：

1. Google Cloud Consoleで「APIとサービス」→「ダッシュボード」に移動
2. 有効なAPIのリストに「Google Drive API」が表示されていることを確認

## トラブルシューティング

### APIを有効にしてもエラーが出る場合

1. **数分待つ**: APIの有効化には最大10分かかる場合があります
2. **サインアウト/サインイン**: アプリから完全にサインアウトして、再度サインインしてください
3. **権限の再承認**: 初回サインイン時に、Drive APIへのアクセス許可を求めるダイアログが表示されます。「許可」をクリックしてください

### プロジェクトが見つからない場合

- Google Sign-Inで使用しているOAuth2クライアントIDが正しいプロジェクトに紐付いているか確認してください
- `android/app/google-services.json`（Android）または `ios/Runner/GoogleService-Info.plist`（iOS）が正しいプロジェクトのものか確認してください

## 必要な権限

このアプリは以下のGoogle API権限を使用します：

- **Google Sheets API**: Spreadsheetへのログデータの書き込み
- **Google Drive API**: メディアファイル（画像、音声、動画）のアップロードと管理

## セキュリティに関する注意

- アップロードされたファイルは「リンクを知っている人全員」が閲覧可能な設定になります
- ファイルはSpreadsheetと同じフォルダ内の`files`サブフォルダに保存されます
- 機密情報を含むファイルをアップロードする場合は、適切なフォルダ権限を設定してください
