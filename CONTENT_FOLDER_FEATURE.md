# コンテンツフォルダID設定機能

## 概要

アップロード用スプレッドシート設定に「コンテンツフォルダ」項目を追加しました。この機能により、メディアファイル（音声、画像、動画）のアップロード先Google Driveフォルダを個別に指定できるようになります。

## 使用方法

### 1. マスタースプレッドシートの設定（任意）

登録済設定のシート（マスタースプレッドシート）に4列目「コンテンツフォルダ」を追加してください：

| ID (A列) | 名前 (B列) | 備考 (C列) | コンテンツフォルダ (D列) |
|---------|----------|----------|---------------------|
| 1kB8... | プロジェクトA | テスト用 | 1AB2CD3EF4GH5IJ6... |
| 2mN3... | プロジェクトB | 本番用 | 7KL8MN9OP0QR1ST2... |

**D列の値:**
- Google DriveのフォルダIDを記入
- 空欄の場合は、従来通りSpreadsheetの親フォルダ内の`files`サブフォルダにアップロード
- フォルダIDの取得方法: Google Driveでフォルダを開き、URLから取得
  ```
  https://drive.google.com/drive/folders/[フォルダID]
  ```

### 2. アプリでの設定

#### 方法A: 登録済み設定から選択

1. **設定画面を開く**
   - ログ一覧画面の右上「⚙️」アイコンをタップ

2. **「登録済み設定から選択」ボタンをタップ**
   - マスタースプレッドシートから設定一覧が読み込まれます

3. **設定を選択**
   - 各設定にコンテンツフォルダIDが表示されます（設定されている場合）
   - 📁アイコンと共にフォルダIDが表示されます
   - 選択すると、Spreadsheet IDとコンテンツフォルダIDが自動的に入力欄に設定されます

4. **「保存」ボタンをタップ**
   - 設定が保存されます

#### 方法B: 手動入力

1. **設定画面を開く**
   - ログ一覧画面の右上「⚙️」アイコンをタップ

2. **Spreadsheet IDを入力**
   - SpreadsheetのURLから「/d/」と「/edit」の間の文字列を入力

3. **コンテンツフォルダID（任意）を入力**
   - Google DriveフォルダのURLから「/folders/」の後の文字列を入力
   - 空欄の場合は、Spreadsheetの親フォルダ内のfilesフォルダにアップロード

4. **「保存」ボタンをタップ**
   - 設定が保存されます

**注意**: どちらの方法でも、設定は入力欄に反映されるだけで、「保存」ボタンを押すまで実際には保存されません。

### 3. アップロード時の動作

**コンテンツフォルダIDが設定されている場合:**
- メディアファイルは指定されたGoogle Driveフォルダに**直接**アップロードされます
- `DriveUploadService.uploadFile(folderId: contentFolderId)`が使用されます
- サブフォルダは作成されません

**コンテンツフォルダIDが設定されていない場合（従来通り）:**
- Spreadsheetの親フォルダ内の`files`サブフォルダにアップロードされます
- `DriveUploadService.uploadFileToSpreadsheetFolder()`が使用されます
- 親フォルダにアクセスできない場合は、マイドライブのルートにフォールバック

## 実装詳細

### 変更されたファイル

#### 1. `lib/services/sheets_upload_service.dart`

**SpreadsheetConfig クラス**
```dart
class SpreadsheetConfig {
  final String id;
  final String name;
  final String note;
  final String? contentFolderId; // 追加

  SpreadsheetConfig({
    required this.id,
    required this.name,
    required this.note,
    this.contentFolderId,
  });
}
```

**getSpreadsheetConfigs メソッド**
- A:D列を読み込むように変更（従来はA:C）
- 4列目からcontentFolderIdを取得

**uploadLogs メソッド**
- `contentFolderId`パラメータを追加
- ファイルアップロード時に`contentFolderId`の有無で処理を分岐:
  ```dart
  final uploadedUrl = contentFolderId != null
      ? await DriveUploadService.uploadFile(
          file: file,
          fileName: log.fileName!,
          folderId: contentFolderId,  // 指定フォルダに直接アップロード
        )
      : await DriveUploadService.uploadFileToSpreadsheetFolder(
          file: file,
          fileName: log.fileName!,
          spreadsheetId: spreadsheetId,  // 親フォルダのfilesサブフォルダにアップロード
        );
  ```

**uploadUnuploadedLogs メソッド**
- `contentFolderId`パラメータを追加
- `uploadLogs`に`contentFolderId`を渡す

#### 2. `lib/pages/spreadsheet_config_selector_page.dart`

**UI表示の変更**
- リストアイテムにコンテンツフォルダIDを表示（設定されている場合のみ）
- 📁アイコンと共にフォルダIDを表示

**戻り値の変更**
- `String`（ID）から`SpreadsheetConfig`オブジェクトに変更
- 手動入力の場合は`contentFolderId`なしのConfigを返す

#### 3. `lib/pages/settings_page.dart`

**追加フィールドとコントローラー**
- `_contentFolderIdController`: コンテンツフォルダIDの入力欄コントローラー
- `_contentFolderIdKey`: SharedPreferencesのキー定数

**_loadSettings メソッド**
- SharedPreferencesから`content_folder_id`を読み込み
- 保存されている値を入力欄に設定

**_saveSettings メソッド**
- コンテンツフォルダIDを取得してSharedPreferencesに保存:
  ```dart
  final contentFolderId = _contentFolderIdController.text.trim();
  if (contentFolderId.isNotEmpty) {
    await prefs.setString(_contentFolderIdKey, contentFolderId);
  } else {
    await prefs.remove(_contentFolderIdKey);
  }
  ```

**_openConfigSelector メソッド**
- 戻り値の型を`String`から`SpreadsheetConfig`に変更
- 選択された設定のコンテンツフォルダIDを入力欄に設定:
  ```dart
  if (selectedConfig.contentFolderId != null && selectedConfig.contentFolderId!.isNotEmpty) {
    _contentFolderIdController.text = selectedConfig.contentFolderId!;
  } else {
    _contentFolderIdController.clear();
  }
  ```
- **重要**: SharedPreferencesには保存せず、入力欄に設定のみ（保存ボタンで保存）

**UI追加**
- Spreadsheet ID入力欄の下にコンテンツフォルダID入力欄を追加
- ラベル: 「コンテンツフォルダID（任意）」
- ヘルパーテキスト: メディアファイルのアップロード先の説明

#### 4. `lib/pages/log_list_page.dart`

**_uploadLogs メソッド**
- SharedPreferencesから`content_folder_id`を取得
- `uploadUnuploadedLogs`に`contentFolderId`を渡す:
  ```dart
  final contentFolderId = prefs.getString('content_folder_id');

  final count = await SheetsUploadService.uploadUnuploadedLogs(
    database: widget.database,
    spreadsheetId: spreadsheetId,
    contentFolderId: contentFolderId,
    onDuplicateFound: (duplicates) async { ... },
  );
  ```

## データフロー

```
マスタースプレッドシート (A:D列)
    ↓
getSpreadsheetConfigs()
    ↓
SpreadsheetConfig (id, name, note, contentFolderId)
    ↓
設定選択画面で選択
    ↓
SharedPreferences ('content_folder_id' キー)
    ↓
アップロード時に取得
    ↓
uploadUnuploadedLogs(contentFolderId: ...)
    ↓
uploadLogs(contentFolderId: ...)
    ↓
contentFolderId != null
  ? uploadFile(folderId: contentFolderId)  // 指定フォルダに直接
  : uploadFileToSpreadsheetFolder(spreadsheetId: ...)  // filesサブフォルダに
```

## 既存機能への影響

- **後方互換性**: コンテンツフォルダIDが設定されていない場合は従来通りの動作
- **手動入力**: 手動でSpreadsheet IDを入力する場合は`contentFolderId`なしで動作
- **エラーハンドリング**: 既存のDrive APIエラーハンドリングはそのまま継承

## 使用例

### 例1: 組織のワークスペースで制限がある場合

**問題**: Spreadsheetの親フォルダにアクセスできない

**解決策**:
1. アクセス可能な別のGoogle Driveフォルダを用意
2. そのフォルダIDをマスタースプレッドシートの「コンテンツフォルダ」列に設定
3. アプリで設定を選択してアップロード

### 例2: プロジェクトごとに別フォルダに保存

**シナリオ**: 複数のプロジェクトで同じアプリを使用、メディアファイルは各プロジェクト専用フォルダに保存したい

**設定**:
```
プロジェクトA: SpreadsheetA + DriveフォルダA
プロジェクトB: SpreadsheetB + DriveフォルダB
```

マスタースプレッドシートで各プロジェクトの設定を管理し、切り替えが簡単に。

## トラブルシューティング

### コンテンツフォルダIDが保存されない

- 設定選択画面で「登録済み設定から選択」を使用していることを確認
- 手動入力では`contentFolderId`は保存されません

### 指定したフォルダにアップロードされない

1. フォルダIDが正しいか確認
2. サインインしているGoogleアカウントにそのフォルダへの書き込み権限があるか確認
3. Drive APIが有効になっているか確認

### フォルダにアクセスできないエラー

- `DriveUploadService.uploadFileToFolder()`は親フォルダアクセスチェックとフォールバック機能があります
- 指定したフォルダにアクセスできない場合、マイドライブのルートにアップロードされます

## 関連ドキュメント

- `DRIVE_API_SETUP.md` - Drive API初期設定
- `WORKSPACE_SPREADSHEET_GUIDE.md` - 組織のワークスペーストラブルシューティング
- `CLAUDE.md` - プロジェクト全体の概要
