# Android版 Google Cloud設定ガイド

Android版アプリでGoogle Sign-Inを使用するための設定手順です。

## 必要な情報

### アプリケーション情報
- **パッケージ名**: `com.example.flog`

### SHA-1フィンガープリント

**デバッグ用（開発時）:**
```
B9:FB:8F:D6:75:7F:62:45:11:53:FE:B5:DE:8D:A6:84:26:E7:27:EE
```

**リリース用（本番配布時）:**
```
17:C1:5B:B6:8D:6E:7F:94:AA:05:55:B2:AF:69:8F:85:7C:13:D1:55
```

## Google Cloud Consoleでの設定手順

### ステップ1: Google Cloud Projectを選択

1. [Google Cloud Console](https://console.cloud.google.com/) にアクセス
2. 新しいプロジェクトを選択（または作成）

### ステップ2: APIの有効化

以下のAPIを有効にしてください：

1. **Google Sheets API**
   - https://console.cloud.google.com/apis/library/sheets.googleapis.com
   - 「有効にする」をクリック

2. **Google Drive API**
   - https://console.cloud.google.com/apis/library/drive.googleapis.com
   - 「有効にする」をクリック

### ステップ3: OAuth同意画面の設定

1. https://console.cloud.google.com/apis/credentials/consent にアクセス

2. ユーザータイプを選択:
   - **外部** を選択（個人用アプリの場合）
   - 「作成」をクリック

3. **アプリ情報** を入力:
   - アプリ名: `flog`
   - ユーザーサポートメール: あなたのメールアドレス
   - アプリのロゴ: （オプション）
   - デベロッパーの連絡先情報: あなたのメールアドレス
   - 「保存して次へ」

4. **スコープ** を追加:
   - 「スコープを追加または削除」をクリック
   - 以下のスコープを検索して追加:
     - `https://www.googleapis.com/auth/spreadsheets`（Google Sheets API）
     - `https://www.googleapis.com/auth/drive`（Google Drive API）
   - 「更新」→「保存して次へ」

5. **テストユーザー** を追加:
   - 「テストユーザーを追加」をクリック
   - あなたのGoogleアカウントのメールアドレスを入力
   - 「追加」→「保存して次へ」

6. 概要を確認して「ダッシュボードに戻る」

### ステップ4: Android用OAuth 2.0クライアントIDの作成

#### デバッグ用（開発時）

1. https://console.cloud.google.com/apis/credentials にアクセス

2. 「認証情報を作成」→「OAuth 2.0 クライアント ID」を選択

3. アプリケーションの種類: **Android**

4. 以下の情報を入力:
   - 名前: `flog-android-debug`
   - パッケージ名: `com.example.flog`
   - SHA-1証明書フィンガープリント:
     ```
     B9:FB:8F:D6:75:7F:62:45:11:53:FE:B5:DE:8D:A6:84:26:E7:27:EE
     ```

5. 「作成」をクリック

6. **クライアントIDは自動的に設定されるため、コピーする必要はありません**

#### リリース用（本番配布時）

1. 再度「認証情報を作成」→「OAuth 2.0 クライアント ID」を選択

2. アプリケーションの種類: **Android**

3. 以下の情報を入力:
   - 名前: `flog-android-release`
   - パッケージ名: `com.example.flog`
   - SHA-1証明書フィンガープリント:
     ```
     17:C1:5B:B6:8D:6E:7F:94:AA:05:55:B2:AF:69:8F:85:7C:13:D1:55
     ```

4. 「作成」をクリック

### ステップ5: 設定の確認

https://console.cloud.google.com/apis/credentials で以下が作成されていることを確認:

- [ ] OAuth 2.0 クライアント ID（Android - デバッグ用）
- [ ] OAuth 2.0 クライアント ID（Android - リリース用）

## アプリ側の設定（不要）

Android版では、`.env`ファイルの設定は不要です。`google_sign_in`パッケージが自動的にGoogle Cloud Consoleの設定を使用します。

## テスト方法

### 1. キャッシュのクリア

```bash
flutter clean
flutter pub get
```

### 2. アプリをアンインストール

以前の認証情報が残っている可能性があるため、端末からアプリを完全にアンインストールします。

### 3. アプリを再インストールして実行

```bash
# デバッグモードで実行
flutter run

# または、リリースモードで実行
flutter run --release
```

### 4. Google Sign-Inをテスト

1. アプリの「設定」画面を開く
2. 「Googleでサインイン」ボタンをタップ
3. テストユーザーとして登録したGoogleアカウントを選択
4. 権限を許可

## よくあるエラーと対処法

### エラー: "PlatformException(sign_in_failed, com.google.android.gms.common.api.ApiException: 10: , null, null)"

**原因**: SHA-1フィンガープリントまたはパッケージ名が一致していない

**対処**:
1. Google Cloud Consoleで設定したパッケージ名が`com.example.flog`であることを確認
2. SHA-1フィンガープリントが正しく登録されているか確認
3. デバッグビルドとリリースビルドで異なるSHA-1が必要

### エラー: "ApiException: 12501"

**原因**: OAuth同意画面でテストユーザーが登録されていない、またはキャンセルされた

**対処**:
1. Google Cloud Console → OAuth同意画面 → テストユーザー → あなたのGoogleアカウントを追加
2. サインイン時に「許可」を選択

### エラー: "ApiException: 7"

**原因**: ネットワーク接続の問題

**対処**:
- インターネット接続を確認
- Google Play開発者サービスが最新版か確認

### エラー: "access_denied"

**原因**: OAuth同意画面でアプリの公開ステータスが「本番」になっているが、テストユーザーが登録されていない

**対処**:
- OAuth同意画面で「テスト」ステータスにする
- テストユーザーを追加

## SHA-1フィンガープリントの取得方法

### デバッグ用

```bash
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore -storepass android -keypass android
```

Windowsの場合:
```bash
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias androiddebugkey -keystore "%USERPROFILE%\.android\debug.keystore" -storepass android
```

### リリース用

```bash
keytool -list -v -alias upload -keystore upload-keystore.jks -storepass <your-password>
```

または、プロジェクトルートで:
```bash
"C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -list -v -alias upload -keystore upload-keystore.jks -storepass pokopoko
```

## トラブルシューティング

### 設定変更後もエラーが続く場合

1. **アプリを完全にアンインストール**
   ```bash
   adb uninstall com.example.flog
   ```

2. **キャッシュをクリア**
   ```bash
   flutter clean
   flutter pub get
   ```

3. **Google Play開発者サービスのキャッシュをクリア**
   - Android端末の「設定」→「アプリ」→「Google Play開発者サービス」
   - 「ストレージ」→「キャッシュを削除」

4. **再インストールしてテスト**
   ```bash
   flutter run
   ```

### ログの確認

詳細なログを確認：
```bash
flutter run --verbose
```

エラーメッセージに含まれる`ApiException`のエラーコードを確認してください。

## 参考情報

- [Google Sign-In for Flutter](https://pub.dev/packages/google_sign_in)
- [Google Cloud Console](https://console.cloud.google.com/)
- [OAuth 2.0エラーコード](https://developers.google.com/identity/protocols/oauth2)
