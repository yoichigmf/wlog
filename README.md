# flog - オフライン活動ログアプリ

テキスト、音声、画像、動画を位置情報と共に記録できる、オフライン対応の活動ログ収集アプリケーションです。

## ⚠️ 重要: 推奨プラットフォーム

**Google Sign-Inのloopbackフロー廃止により、現在以下のプラットフォームのみ完全サポートしています:**

- ✅ **Android** - 全機能利用可能（最推奨）
- ✅ **iOS** - 全機能利用可能
- ⚠️ **Windows** - ローカルログ記録のみ（Google Sign-In不可）
- ❌ **Web** - 使用不可

### なぜWindows版とWeb版でGoogle Sign-Inが使えないのか？

**以前は動作していましたが、2024年以降にGoogleがポリシー変更を行いました。**

Googleがセキュリティ上の理由でloopback（localhost）を使った認証フローを廃止しました。アプリ側のコードは変更していませんが、Google側のポリシー変更により、Flutter Windows版とWeb版で使用している認証パッケージが動作しなくなりました。

詳細は `WEB_LIMITATIONS.md` を参照してください。

## 主な機能

### ローカル記録（全プラットフォーム対応）
- ✅ テキストログの作成・表示
- ✅ 音声録音（AAC-LC、44.1kHz/128kbps）
- ✅ 画像・動画の記録（モバイル: カメラ/ギャラリー、Windows: ファイル選択）
- ✅ 位置情報の自動取得
- ✅ SQLiteデータベースでオフライン保存
- ✅ Google Mapsで位置を開く

### クラウド連携（Android/iOS版のみ）
- ✅ Google Sheetsへのアップロード
- ✅ Google Driveへのメディアファイルアップロード
- ✅ UUID重複チェック
- ✅ コンテンツフォルダ指定対応
- ❌ Windows版では使用不可
- ❌ Web版では使用不可

## インストールと実行

### Android版（推奨）

```bash
# デバイス/エミュレータを接続
flutter devices

# 実行
flutter run -d <device-id>

# リリースビルド
flutter build apk
```

### iOS版

```bash
# シミュレータ/実機を接続
flutter devices

# 実行
flutter run -d <device-id>

# リリースビルド
flutter build ios
```

**重要**: iOS版でGoogle Sign-Inを使用するには、追加の設定が必要です。詳細は `IOS_GOOGLE_SIGNIN_SETUP.md` を参照してください。

### Windows版（ローカルログのみ）

```bash
# 実行
flutter run -d windows

# リリースビルド
flutter build windows
```

**注意**: Windows版ではGoogle Sign-Inが使用できないため、クラウド連携機能は動作しません。

## 初期設定

### 1. 依存関係のインストール

```bash
flutter pub get
```

### 2. Driftコード生成

```bash
dart run build_runner build --delete-conflicting-outputs
```

### 3. .envファイルの作成（Android/iOS版でGoogle Sign-Inを使用する場合）

プロジェクトルートに`.env`ファイルを作成：

```bash
# Android/iOS用（SHA-1ベースのOAuth）
# Google Cloud Consoleで「Android」または「iOS」タイプのOAuthクライアントIDを作成
# Android版: clientIdは不要（SHA-1フィンガープリントを使用）
# iOS版: Info.plistにURL Schemeを設定

# Web版（使用不可）
GOOGLE_WEB_CLIENT_ID=your-web-client-id

# Windows版（使用不可）
GOOGLE_DESKTOP_CLIENT_ID=your-desktop-client-id
GOOGLE_DESKTOP_CLIENT_SECRET=your-desktop-client-secret
```

### 4. Google Cloud Consoleの設定（Android/iOS版のみ）

1. Google Cloud Consoleでプロジェクト作成
2. Google Sheets APIを有効化
3. Google Drive APIを有効化
4. OAuth同意画面を設定
5. Android用/iOS用OAuth 2.0クライアントIDを作成
6. 必要なスコープを追加

**詳細手順**:
- **Android版**: `GOOGLE_SETUP.md` を参照
- **iOS版**: `IOS_GOOGLE_SIGNIN_SETUP.md` を参照（Info.plist設定が必須）

## 使用方法

### ログの作成

1. ➕ボタンをタップ
2. テキストを入力（任意）
3. メディアを追加（任意）:
   - 🎤 音声録音
   - 📷 画像撮影/選択
   - 🎥 動画撮影/選択
4. 位置情報は自動取得
5. 保存

### ログの表示・編集

- ログ一覧からタップして詳細表示
- スワイプで削除
- フィルタリング（すべて/テキストのみ/音声/画像/動画）

### Google Sheetsへのアップロード（Android/iOS版のみ）

1. 設定画面でGoogleサインイン
2. Spreadsheet IDを設定
3. コンテンツフォルダID（任意）を設定
4. ログ一覧画面の「アップロード」ボタンをタップ

## トラブルシューティング

### Windows版でGoogle Sign-Inエラーが発生する

**エラー内容:**
```
エラー 400: invalid_request
The loopback flow has been blocked...
```

**原因**: Googleがloopbackフローを廃止したため

**対応方法**: **Android版またはiOS版を使用してください**

### Web版でGoogle Sign-Inエラーが発生する

同様の理由により、Web版では使用できません。**Android版またはiOS版を使用してください**。

### Android版で認証エラーが発生する

- SHA-1フィンガープリントが正しいか確認
- パッケージ名が`com.example.flog`になっているか確認
- OAuth同意画面でテストユーザーを追加

詳細は `GOOGLE_SETUP.md` を参照してください。

### iOS版でサインイン時にクラッシュする

**原因**: `Info.plist`にReversed Client IDが設定されていない、または誤っている

**対応方法**:
1. `IOS_GOOGLE_SIGNIN_SETUP.md` の手順に従って設定
2. Google Cloud ConsoleでiOS用クライアントIDを作成
3. `ios/Runner/Info.plist` の73行目にReversed Client IDを設定
4. Xcodeでサインイン設定を完了

詳細は `IOS_GOOGLE_SIGNIN_SETUP.md` を参照してください。

### その他のトラブルシューティング

詳細は `GOOGLE_SETUP.md` と `WEB_LIMITATIONS.md` を参照してください。

## ドキュメント

- `CLAUDE.md` - プロジェクト全体の概要（開発者向け）
- `WEB_LIMITATIONS.md` - Windows版とWeb版の制限事項
- `GOOGLE_SETUP.md` - Android版Google Cloud Console設定手順
- `IOS_GOOGLE_SIGNIN_SETUP.md` - **iOS版Google Sign-In設定手順（必須）**
- `ANDROID_GOOGLE_SETUP.md` - Android版Google Sign-In設定
- `CONTENT_FOLDER_FEATURE.md` - コンテンツフォルダID機能
- `WORKSPACE_SPREADSHEET_GUIDE.md` - 組織ワークスペース対応

## 技術スタック

- **Flutter**: ^3.6.0
- **Dart SDK**: ^3.9.2
- **データベース**: Drift (SQLite)
- **認証**: google_sign_in (Android/iOS), google_sign_in_all_platforms (Windows - 非推奨)
- **API**: Google Sheets API, Google Drive API

## ライセンス

このプロジェクトのライセンスについては、開発者に確認してください。

## サポートとフィードバック

問題が発生した場合は、以下を確認してください：
1. 推奨プラットフォーム（Android/iOS）を使用しているか
2. Google Cloud Consoleが正しく設定されているか
3. 該当するドキュメントを読んだか

Windows版やWeb版でGoogle Sign-Inが使えないのは、Google側のポリシー変更によるものです。ご理解ください。
