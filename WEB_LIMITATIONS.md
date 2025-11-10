# Web版とWindows版の制限事項と対応方法

## 重要: Google Sign-Inのloopbackフロー廃止による影響

**2024年以降、Googleがセキュリティ上の理由でloopback（localhost）認証フローを廃止しました。**

これにより、**以前は動作していたWindows版とWeb版のGoogle Sign-Inが突然使用できなくなりました**。アプリ側のコードは変更していませんが、Google側のポリシー変更により動作しなくなっています。

### 推奨プラットフォーム
- ✅ **Android** - 全機能利用可能（最推奨）
- ✅ **iOS** - 全機能利用可能
- ⚠️ **Windows** - Google Sign-In不可（loopbackフロー廃止）
- ⚠️ **macOS** - Google Sign-In不可の可能性
- ❌ **Web** - Google Sign-In不可、メディアファイル非対応

## Windows版の制限事項

### 1. Google Sign-In のloopbackフロー廃止（重大）

**エラー内容:**
```
エラー 400: invalid_request
The loopback flow has been blocked in order to keep users secure.
Follow the Loopback IP Address flow migration guide linked in the developer docs below to migrate your app to an alternative method.
リクエストの詳細: flowName=GeneralOAuthFlow
```

**原因:**
- `google_sign_in_all_platforms`パッケージがloopback（localhost）を使った認証フローを使用
- **以前（〜2023年）は正常に動作していた**
- **Googleがセキュリティ上の理由で2024年にこのフローをブロック**
- アプリ側のコードは変更していないが、Google側のポリシー変更で動作しなくなった
- 現在、Flutter Windows版で標準的なGoogle Sign-In実装方法がない

**影響:**
- Windows版ではGoogle Sign-Inが完全に使用不可
- Spreadsheetへのアップロード機能が使用不可
- ローカルでのログ記録のみ可能

**対応方法:**
- ✅ **Android版を使用**（最推奨）
- ❌ 手動でOAuth 2.0フローを実装（非常に複雑、推奨しない）

### 2. その他の制限

- カメラ機能非対応（`image_picker`の制限）
- その他の機能（録音、位置情報、データベース）は正常動作

## Web版の制限事項

### 1. Google Sign-In のloopbackフロー廃止（Windows版と同様）

**エラー内容:**
```
エラー 400: invalid_request
The loopback flow has been blocked in order to keep users secure.
Follow the Loopback IP Address flow migration guide linked in the developer docs below to migrate your app to an alternative method.
リクエストの詳細: flowName=GeneralOAuthFlow
```

**原因:**
- Googleがloopback（localhost）を使った認証フローをセキュリティ上の理由で廃止
- `google_sign_in`パッケージの古いバージョンや設定ではこのフローを使用している

**対応方法:**

#### オプション1: Web用のOAuthクライアントIDを作成（推奨しない）

Web版で動作させるには、以下の手順が必要ですが、複雑で制限も多いため推奨しません：

1. **Google Cloud Consoleで「ウェブアプリケーション」タイプのOAuthクライアントIDを作成**
   - https://console.cloud.google.com/
   - 「APIとサービス」→「認証情報」
   - 「認証情報を作成」→「OAuth 2.0 クライアントID」
   - アプリケーションの種類: **ウェブアプリケーション**

2. **承認済みのJavaScript生成元を設定**
   ```
   http://localhost:8080
   http://localhost
   https://your-domain.com
   ```

3. **承認済みのリダイレクトURIを設定**
   ```
   http://localhost:8080
   http://localhost
   https://your-domain.com
   ```

4. **.envファイルに設定**
   ```bash
   GOOGLE_WEB_CLIENT_ID=your-web-client-id.apps.googleusercontent.com
   ```

5. **People APIを有効化**
   - https://console.developers.google.com/apis/api/people.googleapis.com
   - 「有効にする」をクリック

**注意事項:**
- デスクトップアプリのクライアントIDはWeb版では使用できません
- Web版専用のクライアントIDが必要です
- 開発サーバー（`flutter run -d chrome`）と本番ビルド（`flutter build web`）で異なるURIが必要になる場合があります

#### オプション2: デスクトップアプリまたはモバイルアプリを使用（推奨）

Web版の制限を避けるため、以下のプラットフォームを使用することを推奨します：

- **Windows版**: `flutter run -d windows`
  - カメラ以外の全機能が利用可能
  - Google Sign-Inが正常動作
  - ローカルストレージが利用可能

- **Android版**: `flutter run -d <device-id>`
  - カメラを含む全機能が利用可能
  - 最も推奨されるプラットフォーム

### 2. ファイルシステムの制限

**問題:**
- Web版では`dart:io`が使用できない
- ファイルシステムへの直接アクセスができない
- メディアファイル（画像、音声、動画）の保存・読み込みに制限

**対応:**
- IndexedDB等のWebストレージを使用する必要がある
- 本アプリではWeb版でのメディアファイル対応は実装していません

### 3. Drift WebAssemblyの問題

**問題:**
```
Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type
```

**説明:**
- Drift FlutterがWASMファイルの読み込みに失敗する場合がある
- 開発サーバー（`flutter run -d chrome`）ではMIMEタイプが正しく設定されない

**対応:**
- データベース操作自体は動作する（IndexedDBにフォールバック）
- 本番環境では`flutter build web`を使用し、適切なWebサーバー（Nginx等）で配信

### 4. カメラとマイクのアクセス

**問題:**
- Web版ではブラウザのメディアAPIを使用
- HTTPSが必要（localhostを除く）
- ユーザーの明示的な許可が必要

**対応:**
- 開発時はlocalhostを使用
- 本番環境ではHTTPS必須

### 5. 位置情報の取得

**問題:**
- ブラウザのGeolocation APIを使用
- HTTPSが必要（localhostを除く）
- 精度がネイティブアプリより低い

**対応:**
- 開発時はlocalhostを使用
- 本番環境ではHTTPS必須

## Web版を使用する場合の推奨設定

### テキストのみモード

Web版を使用する場合は、以下の制限を受け入れてください：

1. **テキストのみのログ作成**
   - 音声録音なし
   - 画像・動画なし
   - テキストと位置情報のみ

2. **Google Sign-Inの設定**
   - Web専用のOAuthクライアントIDを作成
   - 承認済みURIを正しく設定
   - People APIを有効化

3. **本番環境の要件**
   - HTTPS必須
   - 適切なWebサーバー（Nginx、Apache等）
   - 正しいMIMEタイプ設定

## 推奨される開発・運用環境

### 開発時

```bash
# Windows版（推奨）
flutter run -d windows

# Android実機/エミュレータ
flutter run -d <device-id>

# Web版（テスト用のみ）
flutter run -d chrome
```

### 本番環境

1. **Androidアプリ（最推奨）**
   ```bash
   flutter build apk
   # または
   flutter build appbundle
   ```

2. **Windowsアプリ**
   ```bash
   flutter build windows
   ```

3. **Web版（推奨しない）**
   ```bash
   flutter build web
   # 適切なWebサーバーで配信
   ```

## トラブルシューティング

### Q: Web版でどうしてもGoogle Sign-Inを使いたい

**A:** 以下の手順を完了してください：

1. Google Cloud Consoleでウェブアプリケーション用のOAuthクライアントIDを作成
2. 承認済みのJavaScript生成元とリダイレクトURIを設定
3. People APIを有効化
4. .envファイルに正しいWeb用クライアントIDを設定
5. デスクトップアプリのクライアントIDと混同しないように注意

それでもエラーが発生する場合は、**Windows版またはAndroid版の使用を強く推奨**します。

### Q: Web版でメディアファイルは使えないのか

**A:** 現在の実装では対応していません。以下の理由により：

1. `dart:io`が使用できない
2. ファイルシステムへの直接アクセスができない
3. IndexedDBへの対応が必要（未実装）

メディアファイルを使用する場合は、**Android版またはWindows版**を使用してください。

### Q: なぜWeb版を実装したのか

**A:** 実験的なサポートとして実装しましたが、以下の理由で推奨していません：

- Googleの認証フロー変更による制限
- ブラウザのセキュリティ制限
- ネイティブ機能の制限
- 複雑な設定要件

**結論: 本番利用はWindows版またはAndroid版を使用してください。**

## 参考リンク

- [Google Sign-In for Web - Migration Guide](https://developers.google.com/identity/sign-in/web/migration)
- [google_sign_in package](https://pub.dev/packages/google_sign_in)
- [Flutter Web Limitations](https://docs.flutter.dev/platform-integration/web/faq)
