import 'dart:io';
import 'package:googleapis/drive/v3.dart' as drive;
import 'google_auth_service.dart';

/// Google Driveへのファイルアップロードサービス
class DriveUploadService {
  /// Spreadsheetの親フォルダIDを取得
  static Future<String?> getSpreadsheetParentFolderId(
      String spreadsheetId) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Google認証が必要です');
      }

      // Spreadsheetのメタデータを取得
      final file = await driveApi.files.get(
        spreadsheetId,
        $fields: 'parents',
      ) as drive.File;

      // 親フォルダIDを取得
      if (file.parents != null && file.parents!.isNotEmpty) {
        return file.parents!.first;
      }

      return null;
    } catch (e) {
      print('親フォルダID取得エラー: $e');

      // Drive API未有効化エラー
      if (e.toString().contains('Drive API has not been used') ||
          e.toString().contains('drive.googleapis.com')) {
        throw Exception(
            'Google Drive APIが有効になっていません。\n'
            'Google Cloud Console (https://console.cloud.google.com/) で\n'
            '「APIとサービス」→「ライブラリ」から\n'
            '「Google Drive API」を検索して有効にしてください。\n\n'
            '詳細: $e');
      }

      // Spreadsheet not found エラー
      if (e.toString().contains('File not found') ||
          e.toString().contains('status: 404')) {
        throw Exception(
            'Spreadsheetが見つかりません（ID: $spreadsheetId）\n\n'
            '以下を確認してください：\n'
            '1. Spreadsheet IDが正しいか確認\n'
            '   - URLの「/d/」と「/edit」の間の文字列\n'
            '   - 例: https://docs.google.com/spreadsheets/d/【ここ】/edit\n\n'
            '2. このGoogleアカウントでSpreadsheetにアクセスできるか確認\n'
            '   - Spreadsheetを開いて「共有」から権限を確認\n'
            '   - 閲覧権限または編集権限が必要です\n\n'
            '3. Spreadsheetが削除されていないか確認\n\n'
            '詳細: $e');
      }

      rethrow;
    }
  }

  /// 指定フォルダ内の "files" フォルダを取得または作成
  static Future<String?> getOrCreateFilesFolder(String parentFolderId) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Google認証が必要です');
      }

      // "files" という名前のフォルダを検索
      final query =
          "name='files' and '$parentFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
      );

      // 既に存在する場合はそのIDを返す
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        return fileList.files!.first.id;
      }

      // 存在しない場合は新規作成
      final folderMetadata = drive.File()
        ..name = 'files'
        ..mimeType = 'application/vnd.google-apps.folder'
        ..parents = [parentFolderId];

      final folder = await driveApi.files.create(folderMetadata);
      return folder.id;
    } catch (e) {
      print('filesフォルダ取得/作成エラー: $e');

      // Folder not found エラー
      if (e.toString().contains('File not found') ||
          e.toString().contains('status: 404')) {
        throw Exception(
            '指定されたフォルダが見つかりません（Folder ID: $parentFolderId）\n\n'
            '以下を確認してください：\n'
            '1. Folder IDが正しいか確認\n'
            '   - Google Driveでフォルダを開き、URLの最後の部分をコピー\n'
            '   - 例: https://drive.google.com/drive/folders/【ここ】\n\n'
            '2. このGoogleアカウントでフォルダにアクセスできるか確認\n'
            '   - フォルダを開いて「共有」から権限を確認\n'
            '   - 編集権限が必要です\n\n'
            '3. フォルダが削除されていないか確認\n\n'
            '詳細: $e');
      }

      rethrow;
    }
  }

  /// ファイルをGoogle Driveにアップロード
  ///
  /// [file]: アップロードするファイル
  /// [fileName]: ファイル名
  /// [folderId]: アップロード先のフォルダID
  ///
  /// 戻り値: アップロードされたファイルのWebViewLink（共有URL）
  static Future<String?> uploadFile({
    required File file,
    required String fileName,
    required String folderId,
  }) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Google認証が必要です');
      }

      // ファイルメタデータを作成
      final fileMetadata = drive.File()
        ..name = fileName
        ..parents = [folderId];

      // ファイルをアップロード（MIMEタイプは自動判定）
      final media = drive.Media(file.openRead(), file.lengthSync());
      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id, webViewLink, webContentLink',
      );

      // 誰でも閲覧可能にする（リンクを知っている人全員）
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';

      await driveApi.permissions.create(
        permission,
        uploadedFile.id!,
      );

      // WebViewLinkを返す（ブラウザでプレビュー可能なURL）
      return uploadedFile.webViewLink ?? uploadedFile.webContentLink;
    } catch (e) {
      print('ファイルアップロードエラー: $e');
      rethrow;
    }
  }

  /// フォルダの存在とアクセス権限を確認
  static Future<bool> checkFolderExists(String folderId) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        return false;
      }

      // フォルダのメタデータを取得
      await driveApi.files.get(
        folderId,
        $fields: 'id, name',
      );
      return true;
    } catch (e) {
      print('フォルダ確認エラー: $e');
      return false;
    }
  }

  /// 指定されたフォルダ内の "files" フォルダにファイルをアップロード
  ///
  /// [file]: アップロードするファイル
  /// [fileName]: ファイル名
  /// [parentFolderId]: 親フォルダのID（ユーザー指定）
  ///
  /// 戻り値: アップロードされたファイルのWebViewLink（共有URL）
  static Future<String?> uploadFileToFolder({
    required File file,
    required String fileName,
    required String parentFolderId,
  }) async {
    try {
      // 1. "files" フォルダを取得または作成
      final filesFolderId = await getOrCreateFilesFolder(parentFolderId);
      if (filesFolderId == null) {
        throw Exception('filesフォルダの作成に失敗しました');
      }

      // 2. ファイルをアップロード
      final fileUrl = await uploadFile(
        file: file,
        fileName: fileName,
        folderId: filesFolderId,
      );

      return fileUrl;
    } catch (e) {
      print('フォルダへのファイルアップロードエラー: $e');
      rethrow;
    }
  }

  /// Spreadsheetの親フォルダ内の "files" フォルダにファイルをアップロード
  ///
  /// [file]: アップロードするファイル
  /// [fileName]: ファイル名
  /// [spreadsheetId]: SpreadsheetのID
  ///
  /// 戻り値: アップロードされたファイルのWebViewLink（共有URL）
  static Future<String?> uploadFileToSpreadsheetFolder({
    required File file,
    required String fileName,
    required String spreadsheetId,
  }) async {
    try {
      // 1. Spreadsheetの親フォルダIDを取得
      final parentFolderId = await getSpreadsheetParentFolderId(spreadsheetId);
      if (parentFolderId == null) {
        throw Exception('Spreadsheetの親フォルダが見つかりません');
      }

      // 2. "files" フォルダを取得または作成
      final filesFolderId = await getOrCreateFilesFolder(parentFolderId);
      if (filesFolderId == null) {
        throw Exception('filesフォルダの作成に失敗しました');
      }

      // 3. ファイルをアップロード
      final fileUrl = await uploadFile(
        file: file,
        fileName: fileName,
        folderId: filesFolderId,
      );

      return fileUrl;
    } catch (e) {
      print('Spreadsheetフォルダへのファイルアップロードエラー: $e');
      rethrow;
    }
  }
}
