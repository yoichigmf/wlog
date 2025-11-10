# Google Cloud接続先変更ガイド

Google Cloud Projectを変更した場合の対処手順です。

## 必要な手順

### 1. 新しいGoogle Cloud Projectでの設定

#### A. APIの有効化
新しいGoogle Cloud Projectで以下のAPIを有効にしてください：

1. [Google Sheets API](https://console.cloud.google.com/apis/library/sheets.googleapis.com)
2. [Google Drive API](https://console.cloud.google.com/apis/library/drive.googleapis.com)
3. [People API](https://console.cloud.google.com/apis/library/people.googleapis.com) (Web版のみ)

#### B. OAuth同意画面の設定

1. https://console.cloud.google.com/apis/credentials/consent にアクセス
2. ユーザータイプを選択（外部）
3. アプリ情報を入力：
   - アプリ名: flog
   - ユーザーサポートメール: あなたのメールアドレス
   - デベロッパーの連絡先: あなたのメールアドレス
4. スコープを追加：
   - `https://www.googleapis.com/auth/spreadsheets`
   - `https://www.googleapis.com/auth/drive`
   - `https://www.googleapis.com/auth/userinfo.email`
   - `https://www.googleapis.com/auth/userinfo.profile`
5. **重要**: テストユーザーを追加（あなたのGoogleアカウント）

#### C. OAuth 2.0クライアントIDの作成

**デスクトップアプリ用（Windows）:**

1. https://console.cloud.google.com/apis/credentials にアクセス
2. 「認証情報を作成」→「OAuth 2.0 クライアント ID」
3. アプリケーションの種類: **デスクトップアプリ**
4. 名前: `flog-desktop`
5. 作成後、クライアントIDとクライアントシークレットをコピー

**ウェブアプリケーション用（Web版）:**

1. https://console.cloud.google.com/apis/credentials にアクセス
2. 「認証情報を作成」→「OAuth 2.0 クライアント ID」
3. アプリケーションの種類: **ウェブアプリケーション**
4. 名前: `flog-web`
5. 承認済みのJavaScript生成元を追加:
   - `http://localhost`
   - `http://localhost:8080`
6. 承認済みのリダイレクトURIを追加:
   - `http://localhost`
   - `http://localhost:8080`
7. 作成後、クライアントIDをコピー

**Android用:**

1. https://console.cloud.google.com/apis/credentials にアクセス
2. 「認証情報を作成」→「OAuth 2.0 クライアント ID」
3. アプリケーションの種類: **Android**
4. パッケージ名: `com.example.flog`
5. SHA-1フィンガープリント（デバッグ用）:
   ```
   B9:FB:8F:D6:75:7F:62:45:11:53:FE:B5:DE:8D:A6:84:26:E7:27:EE
   ```
   取得方法:
   ```bash
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
   ```
6. 作成

### 2. `.env`ファイルの更新

プロジェクトルートの`.env`ファイルを編集して、新しいクライアントID・シークレットを設定：

```env
# Google OAuth認証情報
# このファイルはGit管理から除外されています (.gitignore参照)

# Web版のクライアントID
GOOGLE_WEB_CLIENT_ID=新しいWeb版のクライアントID.apps.googleusercontent.com

# デスクトップ版（Windows/Linux）のクライアントID
GOOGLE_DESKTOP_CLIENT_ID=新しいデスクトップ版のクライアントID.apps.googleusercontent.com

# デスクトップ版のクライアントシークレット
GOOGLE_DESKTOP_CLIENT_SECRET=新しいデスクトップ版のクライアントシークレット
```

### 3. Android用のgoogle-services.json更新（Android版のみ）

もしAndroid版でGoogle Sign-Inを使用している場合、`google-services.json`も更新が必要です。

1. https://console.firebase.google.com/ にアクセス
2. 新しいプロジェクトを作成またはインポート
3. Androidアプリを追加
4. `google-services.json`をダウンロード
5. `android/app/google-services.json`に配置

### 4. キャッシュのクリア

古い認証情報がキャッシュされている可能性があるため、以下を実行：

```bash
# Flutterのビルドキャッシュをクリア
flutter clean

# 依存関係を再取得
flutter pub get

# アプリを再起動（デバッグモード）
flutter run
```

**重要**: アプリを完全にアンインストールしてから再インストールすることを推奨します。
古い認証トークンがデバイスに残っている場合があります。

### 5. サインアウトとサインイン

1. アプリの設定画面でサインアウト
2. アプリを完全に終了
3. アプリを再起動
4. 新しいクライアントIDで再度サインイン

## よくあるエラーと対処法

### エラー: "redirect_uri_mismatch"

**原因**: リダイレクトURIが登録されていない

**対処**:
- Google Cloud Consoleで承認済みのリダイレクトURIを追加
- Web版: `http://localhost`, `http://localhost:8080`

### エラー: "access_denied"

**原因**: OAuth同意画面でテストユーザーが登録されていない

**対処**:
- Google Cloud Console → OAuth同意画面 → テストユーザー → あなたのGoogleアカウントを追加

### エラー: "API has not been used in project before"

**原因**: 必要なAPIが有効になっていない

**対処**:
1. Google Sheets APIを有効化
2. Google Drive APIを有効化
3. People API（Web版のみ）を有効化

### エラー: "invalid_client"

**原因**: クライアントIDまたはシークレットが間違っている

**対処**:
- `.env`ファイルのクライアントIDとシークレットを確認
- コピー時にスペースや改行が入っていないか確認
- アプリを再起動して`.env`ファイルを再読み込み

### キャッシュされた認証情報のクリア

**Windows:**
```bash
# アプリデータを削除
flutter clean
# アプリをアンインストール（Android/iOS）
```

**Web:**
- ブラウザのキャッシュとCookieをクリア
- シークレットモードで開いて再度サインイン

## 確認チェックリスト

- [ ] Google Sheets API が有効
- [ ] Google Drive API が有効
- [ ] People API が有効（Web版のみ）
- [ ] OAuth同意画面が設定済み
- [ ] テストユーザーが登録済み
- [ ] デスクトップアプリ用のOAuth 2.0クライアントIDを作成
- [ ] Web版用のOAuth 2.0クライアントIDを作成（Web版を使用する場合）
- [ ] Android用のOAuth 2.0クライアントIDを作成（Android版を使用する場合）
- [ ] `.env`ファイルに新しいクライアントIDとシークレットを設定
- [ ] `flutter clean`を実行
- [ ] `flutter pub get`を実行
- [ ] アプリを再起動
- [ ] 古い認証情報をクリア（サインアウト）
- [ ] 新しいクライアントIDでサインイン

## デバッグ方法

サインイン時のログを確認：

```bash
flutter run --verbose
```

ログに表示されるエラーメッセージを確認して、適切に対処してください。

## 参考リンク

- [Google Cloud Console](https://console.cloud.google.com/)
- [Google OAuth 2.0 ドキュメント](https://developers.google.com/identity/protocols/oauth2)
- [Flutter Google Sign-In](https://pub.dev/packages/google_sign_in)
