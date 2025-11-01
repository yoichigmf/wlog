# Google Cloud Console 設定手順

このドキュメントでは、Google Sheets APIを使用するための Google Cloud Console の設定手順を説明します。

## 前提条件

- Googleアカウント
- Google Cloud Consoleへのアクセス権限

## 手順

### 1. Google Cloud Consoleにアクセス

https://console.cloud.google.com/ にアクセスしてログインします。

### 2. プロジェクトを作成

1. 画面上部の「プロジェクトを選択」をクリック
2. 「新しいプロジェクト」をクリック
3. プロジェクト名を入力（例: `flog-app`）
4. 「作成」をクリック

### 3. Google Sheets APIを有効化

1. 左側メニューから「APIとサービス」→「ライブラリ」を選択
2. 検索ボックスに「Google Sheets API」と入力
3. 「Google Sheets API」を選択
4. 「有効にする」をクリック

### 4. OAuth同意画面を設定

1. 左側メニューから「APIとサービス」→「OAuth 同意画面」を選択
2. User Type で「外部」を選択して「作成」をクリック
3. アプリ情報を入力：
   - アプリ名: `flog`
   - ユーザーサポートメール: 自分のメールアドレス
   - デベロッパーの連絡先情報: 自分のメールアドレス
4. 「保存して次へ」をクリック
5. スコープ画面はそのまま「保存して次へ」
6. テストユーザー画面で自分のメールアドレスを追加
7. 「保存して次へ」をクリック

### 5. Androidアプリ用のOAuth 2.0クライアントIDを作成

1. 左側メニューから「APIとサービス」→「認証情報」を選択
2. 「認証情報を作成」→「OAuth クライアント ID」をクリック
3. アプリケーションの種類で「Android」を選択
4. 以下の情報を入力：
   - 名前: `flog Android`
   - パッケージ名: `com.example.flog`（実際のパッケージ名に合わせる）
   - SHA-1証明書フィンガープリント: 下記のコマンドで取得した値を入力

#### SHA-1フィンガープリントの取得方法

**方法1: Gradleを使用（推奨）**
```bash
cd android
./gradlew signingReport
```

出力から「Variant: debug」セクションの「SHA1」の値をコピーします。

**方法2: keytoolを使用**
```bash
# Windows
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android

# Mac/Linux
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
```

5. 「作成」をクリック

### 6. iOS/Webアプリ用のOAuth 2.0クライアントID（オプション）

iOSやWebでも使用する場合は、同様に以下を作成します：

#### iOS
1. アプリケーションの種類で「iOS」を選択
2. Bundle ID: `com.example.flog`（実際のBundle IDに合わせる）
3. 作成後、クライアントIDの詳細画面で「iOS URL スキーム」をコピー
4. `ios/Runner/Info.plist`の以下の行を更新：
   ```xml
   <string>com.googleusercontent.apps.REVERSED_CLIENT_ID</string>
   ```
   を実際の値に置き換える

#### Web（Webアプリとして実行する場合）
1. アプリケーションの種類で「ウェブ アプリケーション」を選択
2. 承認済みのJavaScript生成元とリダイレクトURIを設定

### 7. Spreadsheetを準備

1. Google Sheets（https://sheets.google.com）で新しいSpreadsheetを作成
2. URLから Spreadsheet ID をコピー
   - URL例: `https://docs.google.com/spreadsheets/d/1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms/edit`
   - Spreadsheet ID: `/d/` と `/edit` の間の文字列
   - 上記例では: `1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms`

### 8. アプリで設定

1. アプリを起動
2. ログ一覧画面の右上「設定」アイコンをタップ
3. 「Googleでサインイン」をタップしてログイン
4. Spreadsheet IDを入力して「保存」をタップ
5. ログ一覧画面の「アップロード」ボタンでログをアップロード

## トラブルシューティング

### サインインエラーが発生する場合

1. SHA-1フィンガープリントが正しいか確認
2. パッケージ名が正しいか確認（`android/app/build.gradle`の`applicationId`）
3. OAuth同意画面でテストユーザーにメールアドレスが追加されているか確認

### Spreadsheetが見つからないエラー

1. Spreadsheet IDが正しいか確認
2. サインインしたGoogleアカウントがSpreadsheetにアクセス権限を持っているか確認
3. Google Sheets APIが有効になっているか確認

## 注意事項

- デバッグビルドとリリースビルドではSHA-1が異なります
- リリースビルド用には別途リリースkeystoreのSHA-1を登録する必要があります
- OAuth同意画面が「公開」状態でない場合、テストユーザー以外はサインインできません
