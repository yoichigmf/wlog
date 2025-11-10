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

      print('Drive APIでSpreadsheetメタデータ取得中: $spreadsheetId');

      // Spreadsheetのメタデータを取得
      // supportsAllDrivesを追加して共有ドライブもサポート
      final file = await driveApi.files.get(
        spreadsheetId,
        $fields: 'parents',
        supportsAllDrives: true,
      ) as drive.File;

      print('取得成功: 親フォルダ = ${file.parents}');

      // 親フォルダIDを取得
      if (file.parents != null && file.parents!.isNotEmpty) {
        return file.parents!.first;
      }

      return null;
    } catch (e) {
      print('親フォルダID取得エラー: $e');
      print('エラー詳細: ${e.runtimeType}');

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

      // Spreadsheet not found エラー（Drive API）
      if (e.toString().contains('File not found') ||
          e.toString().contains('status: 404')) {
        print('Drive APIでのアクセスエラー。Sheets APIでは成功しているため、Drive API権限の問題の可能性があります。');
        throw Exception(
            'Drive APIでSpreadsheetにアクセスできません（ID: $spreadsheetId）\n\n'
            '※ Sheets APIでは読み取れているため、以下が原因と考えられます：\n\n'
            '【組織のワークスペースの場合】\n'
            '1. Drive APIの権限が不足している可能性\n'
            '   - Google Cloud Consoleで Drive API が有効か確認\n'
            '   - OAuth同意画面のスコープに Drive が含まれているか確認\n\n'
            '2. 組織のセキュリティポリシーで制限されている可能性\n'
            '   - 組織管理者に Drive API へのアクセスが許可されているか確認\n\n'
            '【回避策】\n'
            '- ファイルアップロード機能を無効化して、テキストデータのみアップロード\n'
            '- Spreadsheetを個人のGoogleドライブにコピーして使用\n\n'
            '詳細: $e');
      }

      rethrow;
    }
  }

  /// 指定フォルダ内の "files" フォルダを取得または作成
  ///
  /// 組織のワークスペースで親フォルダへのアクセス権限がない場合は、
  /// nullを返してマイドライブのルートに直接アップロードする
  static Future<String?> getOrCreateFilesFolder(String parentFolderId) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Google認証が必要です');
      }

      print('親フォルダへのアクセス確認中: $parentFolderId');

      // まず親フォルダにアクセスできるか確認
      try {
        await driveApi.files.get(
          parentFolderId,
          $fields: 'id, name',
          supportsAllDrives: true,
        );
        print('親フォルダへのアクセス成功');
      } catch (e) {
        print('親フォルダへのアクセス失敗: $e');
        // 親フォルダにアクセスできない場合はnullを返す（マイドライブのルートを使用）
        if (e.toString().contains('File not found') || e.toString().contains('status: 404')) {
          print('親フォルダにアクセスできないため、マイドライブのルートにアップロードします');
          return null;
        }
        rethrow;
      }

      // "files" という名前のフォルダを検索
      final query =
          "name='files' and '$parentFolderId' in parents and mimeType='application/vnd.google-apps.folder' and trashed=false";

      final fileList = await driveApi.files.list(
        q: query,
        spaces: 'drive',
        $fields: 'files(id, name)',
        supportsAllDrives: true,
      );

      // 既に存在する場合はそのIDを返す
      if (fileList.files != null && fileList.files!.isNotEmpty) {
        print('既存のfilesフォルダを使用: ${fileList.files!.first.id}');
        return fileList.files!.first.id;
      }

      // 存在しない場合は新規作成を試みる
      try {
        final folderMetadata = drive.File()
          ..name = 'files'
          ..mimeType = 'application/vnd.google-apps.folder'
          ..parents = [parentFolderId];

        final folder = await driveApi.files.create(
          folderMetadata,
          supportsAllDrives: true,
        );
        print('filesフォルダを作成: ${folder.id}');
        return folder.id;
      } catch (e) {
        print('filesフォルダ作成失敗: $e');
        // フォルダ作成に失敗した場合はnullを返す（マイドライブのルートを使用）
        print('フォルダ作成できないため、マイドライブのルートにアップロードします');
        return null;
      }
    } catch (e) {
      print('filesフォルダ取得/作成エラー: $e');
      // エラーの場合もnullを返して続行（マイドライブのルートを使用）
      return null;
    }
  }

  /// ファイルをGoogle Driveにアップロード
  ///
  /// [file]: アップロードするファイル
  /// [fileName]: ファイル名
  /// [folderId]: アップロード先のフォルダID（nullの場合はマイドライブのルート）
  ///
  /// 戻り値: アップロードされたファイルのWebViewLink（共有URL）
  static Future<String?> uploadFile({
    required File file,
    required String fileName,
    String? folderId,
  }) async {
    try {
      final driveApi = await GoogleAuthService.getDriveApi();
      if (driveApi == null) {
        throw Exception('Google認証が必要です');
      }

      // ファイルメタデータを作成
      final fileMetadata = drive.File()..name = fileName;

      // folderIdが指定されている場合のみparentsを設定
      if (folderId != null) {
        fileMetadata.parents = [folderId];
        print('フォルダにアップロード: $folderId');
      } else {
        print('マイドライブのルートにアップロード');
      }

      // ファイルをアップロード（MIMEタイプは自動判定）
      final media = drive.Media(file.openRead(), file.lengthSync());
      final uploadedFile = await driveApi.files.create(
        fileMetadata,
        uploadMedia: media,
        $fields: 'id, webViewLink, webContentLink',
        supportsAllDrives: true,
      );

      // 誰でも閲覧可能にする（リンクを知っている人全員）
      final permission = drive.Permission()
        ..type = 'anyone'
        ..role = 'reader';

      await driveApi.permissions.create(
        permission,
        uploadedFile.id!,
        supportsAllDrives: true,
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

      print('フォルダ確認中: $folderId');

      // フォルダのメタデータを取得
      await driveApi.files.get(
        folderId,
        $fields: 'id, name, mimeType',
        supportsAllDrives: true,
      );
      print('フォルダ確認成功: $folderId');
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
  ///
  /// 組織のワークスペースで親フォルダにアクセスできない場合は、
  /// マイドライブのルートに直接アップロードします
  static Future<String?> uploadFileToSpreadsheetFolder({
    required File file,
    required String fileName,
    required String spreadsheetId,
  }) async {
    try {
      // 1. Spreadsheetの親フォルダIDを取得
      final parentFolderId = await getSpreadsheetParentFolderId(spreadsheetId);

      String? filesFolderId;

      if (parentFolderId != null) {
        // 2. "files" フォルダを取得または作成
        filesFolderId = await getOrCreateFilesFolder(parentFolderId);
        // filesフォルダが作成できなかった場合はnull（マイドライブのルートを使用）
      } else {
        print('親フォルダが見つからないため、マイドライブのルートにアップロードします');
      }

      // 3. ファイルをアップロード（filesFolderIdがnullの場合はマイドライブのルート）
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
