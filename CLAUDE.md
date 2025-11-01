# CLAUDE.md

このファイルは、Claude Code (claude.ai/code) がこのリポジトリで作業する際のガイダンスを提供します。

## プロジェクト概要

Dart SDK ^3.9.2を使用した「flog」というFlutterアプリケーションです。オフラインでも動作する活動ログ収集アプリケーションで、テキスト、音声、画像、動画を位置情報と共に記録できます。

### 主な特徴
- **テキストは全種類のログに記入可能**: すべてのログにテキストとメディアの両方を添付できます
- **デフォルトはテキスト入力**: ボタンで音声録音、画像、動画を追加
- **音声録音**: その場で録音できるモードがデフォルト
- **プラットフォーム対応**: モバイルとデスクトップで適切なUIを表示
- **完全オフライン**: ネットワーク不要で動作
- **Google Sheets連携**: ログをGoogle Sheetsにアップロード
- **Google Drive連携**: メディアファイルをGoogle Driveにアップロードし、URLをSheetsに記録

## 開発コマンド

### 依存関係の取得
```bash
flutter pub get
```

### アプリケーションの実行
```bash
# デフォルトデバイスで実行
flutter run

# 特定のデバイスで実行
flutter devices  # 利用可能なデバイスを一覧表示
flutter run -d <device-id>

# ホットリロードを有効にして実行（デフォルト）
flutter run

# リリースモードで実行
flutter run --release
```

### テスト
```bash
# すべてのテストを実行
flutter test

# 特定のテストファイルを実行
flutter test test/widget_test.dart

# カバレッジ付きでテストを実行
flutter test --coverage
```

### コード品質
```bash
# コードを分析（静的解析）
flutter analyze

# コードをフォーマット
dart format .

# フォーマットを適用せずにチェック
dart format --set-exit-if-changed .
```

### ビルド
```bash
# Android用にビルド
flutter build apk          # APKをビルド
flutter build appbundle    # App Bundle（Play Store用）をビルド

# iOS用にビルド
flutter build ios

# Web用にビルド
flutter build web

# Windows用にビルド
flutter build windows

# Linux用にビルド
flutter build linux

# macOS用にビルド
flutter build macos
```

## コードアーキテクチャ

### プロジェクト構造
```
lib/
├── main.dart              # アプリケーションのエントリーポイント
├── data/
│   ├── database.dart      # Driftデータベース定義（ActivityLogsテーブル）
│   └── database.g.dart    # Drift生成ファイル
├── services/
│   ├── file_service.dart           # メディアファイル管理サービス
│   ├── location_service.dart       # 位置情報取得サービス
│   ├── audio_recorder_service.dart # 音声録音サービス
│   ├── google_auth_service.dart    # Google OAuth認証サービス
│   ├── sheets_upload_service.dart  # Google Sheetsアップロードサービス
│   └── drive_upload_service.dart   # Google Driveファイルアップロードサービス
└── pages/
    ├── log_list_page.dart    # ログ一覧画面
    ├── add_log_page.dart     # ログ追加画面
    ├── log_detail_page.dart  # ログ詳細画面
    └── settings_page.dart    # 設定画面（Google認証、Spreadsheet ID設定）
```

### データベーススキーマ
**ActivityLogsテーブル (Drift) - Schema Version 4**
- `id`: 主キー（自動生成）
- `uuid`: UUID（ログの一意識別子、アップロード時の重複チェックに使用）
- `textContent`: テキストコンテンツ（**すべてのログで利用可能**、nullable）
- `mediaType`: メディアタイプ（audio, image, video）（nullable - nullの場合はテキストのみ）
- `fileName`: メディアファイル名（音声/画像/動画の場合、UUIDベース）
- `latitude`: 緯度（位置情報、nullable）
- `longitude`: 経度（位置情報、nullable）
- `createdAt`: 登録日時（UTC標準時で保存、表示時はローカルタイムゾーンに変換）
- `uploadedAt`: アップロード日時（nullable、アップロード未実施の場合はnull）

**重要な設計変更:**
- **Schema V1からV2への変更**: `logType`を廃止し、`mediaType`に変更
- **テキストはすべてのログで利用可能**: テキストのみ、またはメディア+テキストの組み合わせが可能
- **MediaType enum**: audio, image, video（textは削除 - nullで表現）
- **Schema V2からV3への変更**: `uploadedAt`カラムを追加（アップロード機能の準備）
- **Schema V3からV4への変更**: `uuid`カラムを追加（重複チェック機能）
- **マイグレーション履歴**:
  - V1→V2: テーブルを再作成（既存データは削除）
  - V2→V3: `uploadedAt`カラムを追加（既存データは保持）
  - V3→V4: `uuid`カラムを追加、既存レコードにUUIDを生成

### 主要機能
1. **ログ記録**
   - **テキスト**: すべてのログで入力可能、データベースに直接保存
   - **音声録音**: その場で録音（デフォルト）、AAC-LC形式、44.1kHz/128kbps
     - リアルタイム録音時間表示
     - 録音の終了（破棄）と完了（保存）ボタン
   - **画像/動画**:
     - **モバイル（Android/iOS）**: カメラ撮影またはギャラリー選択
     - **デスクトップ（Windows）**: ファイルピッカーのみ（カメラ非対応）
   - **ファイル管理**: UUID（v4）ベースのユニークファイル名で保存

2. **位置情報**
   - 各ログ作成時に自動的に現在位置を取得・記録
   - Google Mapsで位置を開く機能（`url_launcher`使用）
   - 位置情報の取得失敗時も記録可能（緯度/経度がnull）

3. **オフライン対応**
   - すべてのデータはローカルのSQLiteデータベースに保存
   - メディアファイルはアプリのDocumentsディレクトリに保存
   - ネットワーク不要で完全に動作

4. **プラットフォーム対応**
   - **モバイル（Android/iOS）**: カメラ機能を含む全機能利用可能
   - **デスクトップ（Windows）**: カメラ以外の全機能利用可能
   - **Web**: ネイティブ機能制限のため非推奨（録音、カメラ、位置情報に制限あり）
   - プラットフォーム検出により適切なUIを表示

5. **Google連携機能**
   - **Google Sheets アップロード**:
     - 未アップロードのログをGoogle Sheetsに一括アップロード
     - UUID重複チェック機能（既存ログの検出と上書き確認）
     - アップロード列: UUID、登録日時、テキスト、メディアタイプ、ファイル名、ファイルURL、緯度、経度、アップロード日時、アップロードユーザー
   - **Google Drive ファイルアップロード**:
     - メディアファイル（音声、画像、動画）を自動的にGoogle Driveにアップロード
     - Spreadsheetと同じフォルダ内の`files`サブフォルダに保存
     - 共有リンク生成（リンクを知っている人全員が閲覧可能）
     - ファイルURLをSpreadsheetに記録
   - **設定項目**:
     - Google Sign-In（Sheets & Drive API権限）
     - Spreadsheet ID設定
   - **重要**: Google Cloud ConsoleでGoogle Drive APIを有効にする必要があります（詳細は`DRIVE_API_SETUP.md`参照）

6. **アップロード管理**
   - `uploadedAt`カラムでアップロード状態を管理
   - `uuid`カラムで重複チェック
   - **未アップロード**: `uploadedAt`がnullのログ
   - **アップロード済み**: `uploadedAt`に日時が記録されたログ
   - **提供メソッド**:
     - `markAsUploaded(int id)`: ログをアップロード済みとしてマーク
     - `getUnuploadedLogs()`: 未アップロードのログを取得
     - `getUploadedLogs()`: アップロード済みのログを取得
     - `checkDuplicateLogs()`: UUID重複チェック

### UI/UX設計の重要ポイント

#### ログ追加画面 (AddLogPage)
**基本方針**: デフォルトはテキスト入力、ボタンでメディアを追加

1. **テキスト入力**
   - 常に表示（録音中を除く）
   - 複数行対応（5行表示）
   - すべてのメディアタイプと組み合わせ可能

2. **メディア追加ボタン**
   - 音声: 録音ボタン（デフォルトはその場で録音）
   - 画像: カメラ撮影（モバイルのみ）/ファイル選択
   - 動画: カメラ撮影（モバイルのみ）/ファイル選択

3. **録音モード**
   - ボタン押下で録音開始
   - リアルタイム録音時間表示
   - 2つの終了オプション:
     - 「終了(破棄)」: 録音をキャンセルしてテキスト入力に戻る
     - 「完了(保存)」: 録音を保存

4. **位置情報**
   - ログ保存時に自動取得
   - 取得失敗時もログ作成可能（位置情報なしで保存）

#### ログ一覧画面 (LogListPage)
- メディアタイプ別のアイコンと色分け
- フィルタリング機能（すべて/テキストのみ/音声/画像/動画）
- スワイプで削除（確認ダイアログ付き）
- タップで詳細画面へ遷移

#### ログ詳細画面 (LogDetailPage)
- すべての情報を表示（日時、テキスト、メディア、位置情報）
- 画像はプレビュー表示
- 位置情報からGoogle Mapsを起動
- ファイルサイズの表示

### Driftコード生成
データベーススキーマを変更した場合、以下のコマンドでコード生成：
```bash
dart run build_runner build --delete-conflicting-outputs
```

**重要**: スキーマを変更した場合は`schemaVersion`をインクリメントし、`onUpgrade`でマイグレーション処理を実装すること。

### リンティング
`flutter_lints` (^5.0.0)を使用。`analysis_options.yaml`でカスタマイズ可能。

## 依存関係

### 本番環境
- `drift: ^2.22.0`: SQLiteデータベースORM
- `drift_flutter: ^0.2.0`: Flutter用のDriftサポート（Web対応含む）
- `geolocator: ^13.0.2`: 位置情報取得
- `image_picker: ^1.1.2`: 画像/動画の選択・撮影
- `file_picker: ^8.1.6`: ファイル選択
- `permission_handler: ^11.3.1`: パーミッション管理
- `record: ^6.1.2`: 音声録音（**v5からv6にアップグレード**: `record_linux`互換性修正）
- `uuid: ^4.5.1`: ユニークID生成（ファイル名用）
- `intl: ^0.19.0`: 日付フォーマット
- `url_launcher: ^6.3.1`: 外部URLを開く（Google Maps）
- `path_provider: ^2.1.5`: アプリディレクトリパス取得
- `path: ^1.9.0`: パス操作
- `cupertino_icons: ^1.0.8`: iOSスタイルのアイコン
- `google_sign_in: ^6.2.2`: Google OAuth認証（Android/iOS/Web）
- `google_sign_in_all_platforms: ^1.0.1`: Google OAuth認証（Windows/Linux対応）
- `googleapis: ^13.2.0`: Google Sheets & Drive API
- `extension_google_sign_in_as_googleapis_auth: ^2.0.12`: 認証ブリッジ
- `shared_preferences: ^2.3.3`: 設定の永続化（Spreadsheet ID等）

### 開発環境
- `flutter_lints: ^5.0.0`: Flutterリンティングルール
- `drift_dev: ^2.22.0`: Driftコード生成
- `build_runner: ^2.4.13`: コード生成ランナー

## 開発時の重要な修正履歴

### 1. recordパッケージのバージョンアップグレード
**問題**: `record: ^5.1.2`使用時に`record_linux`で互換性エラー
```
The non-abstract class 'RecordLinux' is missing implementations for these members:
- RecordMethodChannelPlatformInterface.startStream
```
**解決**: `record: ^6.1.2`にアップグレード

### 2. キーボード入力の修正
**問題**: テキストフィールドでペーストは可能だがキーボードからの直接入力ができない
**解決**: TextFieldに以下のプロパティを追加
```dart
TextField(
  keyboardType: TextInputType.multiline,
  textInputAction: TextInputAction.newline,
  enableInteractiveSelection: true,
  autocorrect: true,
  enableSuggestions: true,
)
```
また、Scaffoldに`resizeToAvoidBottomInset: true`を追加

### 3. Windowsでのカメラ非対応への対応
**問題**: Windows版で`ImageSource.camera`を使用すると`CameraDelegate`エラー
```
Bad state: This implementation of ImagePickedPlatform requires a 'CameraDelegate'
```
**解決**: プラットフォーム検出を実装
```dart
bool get _isMobilePlatform {
  if (kIsWeb) return false;
  return Platform.isAndroid || Platform.isIOS;
}
```
モバイルではカメラボタンを表示、デスクトップではファイルピッカーのみ表示

### 4. 録音UIの改善
**要件**: 録音中にキャンセルまたは保存を選択できるようにする
**実装**:
- 「終了(破棄)」ボタン: 録音をキャンセルしてテキスト入力に戻る
- 「完了(保存)」ボタン: 録音を保存してログに追加
- リアルタイムで録音時間を表示

### 5. アップロード日時カラムの追加（Schema V3）
**目的**: 将来のアップロード機能実装の準備
**実装内容**:
- `uploadedAt`カラムを追加（DateTime型、nullable）
- スキーマバージョンを2から3に更新
- マイグレーション処理を実装（既存データを保持したまま新カラムを追加）
- アップロード管理用メソッドを追加:
  ```dart
  Future<int> markAsUploaded(int id)  // ログをアップロード済みとしてマーク
  Future<List<ActivityLog>> getUnuploadedLogs()  // 未アップロードのログを取得
  Future<List<ActivityLog>> getUploadedLogs()  // アップロード済みのログを取得
  ```
**注意**: アプリ再起動時にマイグレーションが自動実行され、既存のログに`uploadedAt`カラムが追加される（初期値null）

### 6. Google Sheets連携機能の実装
**目的**: ログデータをGoogle Spreadsheetsにアップロード
**実装内容**:

#### 追加パッケージ
- `google_sign_in: ^6.2.2` - Google OAuth認証
- `googleapis: ^13.2.0` - Google Sheets API
- `extension_google_sign_in_as_googleapis_auth: ^2.0.12` - 認証ブリッジ
- `shared_preferences: ^2.3.3` - Spreadsheet ID保存

#### 新規作成ファイル
1. **`lib/services/google_auth_service.dart`**
   - Google OAuth認証の管理
   - Sheets APIインスタンスの取得
   - サインイン/サインアウト機能

2. **`lib/services/sheets_upload_service.dart`**
   - Google Sheetsへのログアップロード
   - 未アップロードログの一括アップロード
   - Spreadsheet存在確認

3. **`lib/pages/settings_page.dart`**
   - Google認証UI
   - Spreadsheet ID設定
   - 設定の保存・読み込み

4. **`GOOGLE_SETUP.md`**
   - Google Cloud Consoleの設定手順書
   - OAuth 2.0クライアントID作成手順
   - トラブルシューティング

#### 既存ファイルの更新
- **`lib/pages/log_list_page.dart`**
  - アップロードボタンを追加
  - 設定画面へのナビゲーション追加
  - 未アップロードログのアップロード処理

- **`ios/Runner/Info.plist`**
  - Google Sign-In用のURL Schemeを追加

#### アップロードデータ形式
Google Sheetsに以下の情報を記録：
- **レコードID**: 元のデータベースレコードのID
- **登録日時**: ログの作成日時
- **テキスト**: テキストコンテンツ
- **メディアタイプ**: audio/image/video
- **ファイル名**: メディアファイル名
- **緯度/経度**: 位置情報
- **アップロード日時**: アップロード実行時の日時（全ログで同一）
- **アップロードユーザー**: サインインしているGoogleアカウントのメールアドレス

#### Google Cloud Consoleの設定
**必要な情報**:
- パッケージ名: `com.example.flog`
- SHA-1フィンガープリント: `B9:FB:8F:D6:75:7F:62:45:11:53:FE:B5:DE:8D:A6:84:26:E7:27:EE`（デバッグ用）

**設定手順**:
1. Google Cloud Consoleでプロジェクト作成
2. Google Sheets APIを有効化
3. OAuth同意画面を設定（テストユーザー追加必須）
4. Android用OAuth 2.0クライアントIDを作成
5. 必要なスコープを追加: `https://www.googleapis.com/auth/spreadsheets`

**使用方法**:
1. アプリの設定画面でGoogleサインイン
2. Google SheetsでSpreadsheetを作成
3. シート名を「ActivityLogs」に変更
4. Spreadsheet IDを設定画面に入力・保存
5. ログ一覧画面の「アップロード」ボタンで未アップロードログをアップロード

**トラブルシューティング**:
- **403 access_denied**: OAuth同意画面でテストユーザーを追加
- **400 Unable to parse range**: シート名を「ActivityLogs」に変更
- **認証エラー**: SHA-1フィンガープリントとパッケージ名を確認

## プラットフォーム固有の注意事項

### Android
- **パーミッション**: `AndroidManifest.xml`で位置情報、カメラ、ストレージ、マイクの権限を定義
- **ストレージ権限**: Android 13+では`READ_MEDIA_*`権限を使用
- 全機能が利用可能

### iOS
- **パーミッション**: `Info.plist`で各権限の使用目的を記述必須
- 全機能が利用可能
- App Storeへの提出時は実際に使用する機能の説明が必要

### Windows
- **カメラ非対応**: `image_picker`のカメラ機能は利用不可
- ファイルピッカーで画像/動画を選択可能
- その他の機能（録音、位置情報、データベース）は正常動作
- **推奨実行方法**: `flutter run -d windows`
- **Google Sign-In対応**:
  - `google_sign_in_all_platforms: ^1.0.1`パッケージを使用
  - デスクトップアプリ用のOAuth 2.0クライアントIDが必要
  - 認証情報はキャッシュされ、画面遷移後も保持される
  - スコープ: userinfo.email, userinfo.profile, drive, spreadsheets

### Web
- **制限付き対応**: ネイティブ機能（カメラ、録音、ファイルアクセス）に制限あり
- **Google Sign-In対応**:
  - ウェブアプリケーション用のOAuth 2.0クライアントIDが必要
  - 承認済みのJavaScript生成元とリダイレクトURIの設定が必要
  - **People API有効化が必須**: Google Cloud ConsoleでPeople APIを有効にする必要あり
- **Drift Web対応**:
  - WebAssembly版SQLiteを使用
  - `DriftWebOptions`で`sqlite3.wasm`と`drift_worker.js`を指定
- **推奨**: モバイルまたはデスクトップでの実行を推奨（機能制限のため）

## トラブルシューティング

### Driftコード生成エラーが発生した場合
```bash
flutter clean
flutter pub get
dart run build_runner clean
dart run build_runner build --delete-conflicting-outputs
```

### パッケージの競合エラー
```bash
flutter clean
flutter pub get
```

### プラットフォーム固有のエラー
- **Android**: `flutter clean` → Android Studioでプロジェクトをクリーン＆リビルド
- **iOS**: `cd ios && pod install && cd ..` → `flutter clean` → `flutter run`
- **Windows**: `flutter clean` → `flutter run -d windows`

### Windows版 Google Sign-In のトラブルシューティング

#### 問題: サインイン後、認証情報が保持されない
**原因**: `getUserEmail()`で`ensureSignedIn()`を呼んでいる、または`signIn()`で毎回`signOut()`している
**解決**:
- `getUserEmail()`では既存の認証クライアントのみを使用（`ensureSignedIn()`を呼ばない）
- `signIn()`で自動的に`signOut()`しない

#### 問題: 401 Unauthorized エラー
**原因**: アクセストークンに必要なスコープが含まれていない
**解決**:
- `google_sign_in_all_platforms`の初期化時に正しいスコープを設定
- 必要なスコープ: `https://www.googleapis.com/auth/userinfo.email`, `https://www.googleapis.com/auth/userinfo.profile`

### Web版 Google Sign-In のトラブルシューティング

#### 問題: "When compiling to the web, the `web` parameter needs to be set"
**原因**: `drift_flutter`のWeb対応設定が不足
**解決**:
```dart
QueryExecutor _openConnection() {
  return driftDatabase(
    name: 'activity_logs_db',
    web: DriftWebOptions(
      sqlite3Wasm: Uri.parse('sqlite3.wasm'),
      driftWorker: Uri.parse('drift_worker.js'),
    ),
  );
}
```

#### 問題: "People API has not been used in project"
**原因**: Google Cloud ConsoleでPeople APIが有効になっていない
**解決**:
1. https://console.developers.google.com/apis/api/people.googleapis.com を開く
2. 「有効にする」をクリック
3. 数分待ってから再試行

#### 問題: OAuth設定エラー
**原因**: Web用のクライアントIDに承認済みURIが設定されていない
**解決**:
- Google Cloud Consoleで以下を設定:
  - 承認済みのJavaScript生成元: `http://localhost`, `http://localhost:8080`
  - 承認済みのリダイレクトURI: `http://localhost`, `http://localhost:8080`

#### 問題: "Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type"
**原因**: Drift FlutterのWebAssemblyファイルのMIMEタイプ設定
**詳細**:
- このエラーは警告であり、実際のデータベース操作には通常影響しません
- Driftは自動的にフォールバックメカニズム（IndexedDB）を使用します
- `flutter run -d chrome`の開発サーバーではWASMファイルのMIMEタイプが正しく設定されない場合があります

**解決**:
1. エラーが表示されても、データベース操作が正常に動作するか確認してください
2. 本番環境では`flutter build web`を使用し、適切なWebサーバー（Nginxなど）で配信してください
3. 開発時にエラーを回避したい場合:
   - `flutter clean`を実行
   - `flutter pub get`を実行
   - `flutter run -d chrome`を再起動

**注意**: Web版は制限が多いため、主要なプラットフォームとしてはWindows/Android/iOSを推奨します

#### 問題: ログ保存時のWebAssemblyエラー
**原因**: Drift FlutterがWASMファイルの読み込みに失敗する
**エラーメッセージ**: "Failed to execute 'compile' on 'WebAssembly': Incorrect response MIME type"

**Web版の制限事項**:
- データベースはIndexedDBを使用しますが、WASMエラーが発生する場合があります
- ファイルシステムアクセス不可（`dart:io`が使えない）
- メディアファイル（画像/音声/動画）の保存・表示に制限があります
- **テキストのみのログ**の使用を推奨します

**対処法**:
1. Web版は現在実験的サポートのみです
2. 本番利用では Windows/Android/iOS 版を使用してください
3. どうしてもWeb版を使用する場合:
   - `flutter build web`でビルドし、適切なWebサーバー（Nginxなど）でホストしてください
   - 開発サーバー（`flutter run -d chrome`）では制限があります
