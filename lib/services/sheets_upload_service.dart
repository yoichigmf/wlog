import 'package:googleapis/sheets/v4.dart' as sheets;
import 'package:timezone/timezone.dart' as tz;
import '../data/database.dart';
import 'google_auth_service.dart';
import 'file_service.dart';
import 'drive_upload_service.dart';

/// Google Sheetsへのアップロードサービス
class SheetsUploadService {
  /// UTC DateTimeを東京タイムゾーンのISO8601文字列に変換
  static String _toJstString(DateTime utcDateTime) {
    // 東京タイムゾーン（+09:00）に変換
    final jst = tz.TZDateTime.from(utcDateTime, tz.getLocation('Asia/Tokyo'));
    // ISO8601形式の文字列として返す（タイムゾーン情報付き）
    return jst.toIso8601String();
  }

  /// 使用するシート名を決定（ActivityLogsが存在しない場合は「シート1」を使用）
  static Future<String> _determineSheetName(
    String spreadsheetId,
    String preferredSheetName,
  ) async {
    try {
      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        return preferredSheetName;
      }

      // Spreadsheetのメタデータを取得
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);

      // 優先シート名が存在するか確認
      final preferredSheetExists = spreadsheet.sheets?.any(
        (sheet) => sheet.properties?.title == preferredSheetName,
      ) ?? false;

      if (preferredSheetExists) {
        return preferredSheetName;
      }

      // 「シート1」が存在するか確認
      final sheet1Exists = spreadsheet.sheets?.any(
        (sheet) => sheet.properties?.title == 'シート1',
      ) ?? false;

      if (sheet1Exists) {
        print('「$preferredSheetName」が存在しないため、「シート1」を使用します');
        return 'シート1';
      }

      // どちらも存在しない場合は最初のシートを使用
      final firstSheetName = spreadsheet.sheets?.first.properties?.title;
      if (firstSheetName != null) {
        print('「$preferredSheetName」も「シート1」も存在しないため、「$firstSheetName」を使用します');
        return firstSheetName;
      }

      // フォールバック
      return preferredSheetName;
    } catch (e) {
      print('シート名決定エラー: $e');
      return preferredSheetName;
    }
  }

  /// ログをGoogle Sheetsにアップロード
  ///
  /// [spreadsheetId]: アップロード先のSpreadsheet ID
  /// [logs]: アップロードするログのリスト
  /// [sheetName]: シート名（デフォルトは「ActivityLogs」）
  ///
  /// 戻り値: アップロードに成功したログの数
  static Future<int> uploadLogs({
    required String spreadsheetId,
    required List<ActivityLog> logs,
    String sheetName = 'ActivityLogs',
  }) async {
    if (logs.isEmpty) {
      return 0;
    }

    try {
      // 実際に使用するシート名を決定（ActivityLogsが存在しない場合は「シート1」を使用）
      final actualSheetName = await _determineSheetName(spreadsheetId, sheetName);

      // Sheets APIを取得
      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        throw Exception('Google認証が必要です');
      }

      // 現在サインインしているユーザーのメールアドレスを取得
      final userEmail = GoogleAuthService.currentUser?.email ?? '';

      // アップロード日時（現在時刻、UTC）
      final uploadedAt = DateTime.now().toUtc();

      // 既存データの有無を確認（1行目にデータがあるかチェック）
      bool hasExistingData = false;
      try {
        final response = await sheetsApi.spreadsheets.values.get(
          spreadsheetId,
          '$actualSheetName!A1:A1',
        );
        hasExistingData = response.values != null && response.values!.isNotEmpty;
      } catch (e) {
        // エラーの場合は新規シートとして扱う
        hasExistingData = false;
      }

      // ヘッダー行を準備（1行目にデータがない場合のみ）
      final headers = [
        'UUID',
        '登録日時',
        'テキスト',
        'メディアタイプ',
        'ファイル名',
        'ファイルURL',
        '緯度',
        '経度',
        'アップロード日時',
        'アップロードユーザー',
      ];

      // データ行を準備
      final rows = <List<Object>>[];
      if (!hasExistingData) {
        rows.add(headers); // ヘッダー行を追加（1行目が空の場合のみ）
      }

      for (final log in logs) {
        // ファイルがある場合はGoogle Driveにアップロード
        String fileUrl = '';
        if (log.fileName != null && log.fileName!.isNotEmpty) {
          try {
            final file = await FileService.getFile(log.fileName!);
            if (file != null && await file.exists()) {
              final uploadedUrl =
                  await DriveUploadService.uploadFileToSpreadsheetFolder(
                file: file,
                fileName: log.fileName!,
                spreadsheetId: spreadsheetId,
              );
              fileUrl = uploadedUrl ?? '';
            }
          } catch (e) {
            print('ファイルアップロードエラー (${log.fileName}): $e');
            // 重大なエラーの場合は処理を中断
            if (e.toString().contains('Drive API has not been used') ||
                e.toString().contains('Drive APIが有効になっていません') ||
                e.toString().contains('File not found') ||
                e.toString().contains('Spreadsheetが見つかりません')) {
              rethrow; // エラーを上位に伝播して処理を中断
            }
            // その他のエラーは続行（個別ファイルのみスキップ）
          }
        }

        rows.add([
          log.uuid ?? '', // UUID（ログの一意識別子）、nullの場合は空文字
          _toJstString(log.createdAt.toUtc()), // 東京タイムゾーンのISO8601文字列
          log.textContent ?? '',
          log.mediaType ?? '',
          log.fileName ?? '',
          fileUrl, // Google DriveのファイルURL
          log.latitude?.toString() ?? '',
          log.longitude?.toString() ?? '',
          _toJstString(uploadedAt), // アップロード日時（東京タイムゾーンのISO8601文字列）
          userEmail, // アップロードユーザーのメールアドレス
        ]);
      }

      // ValueRangeオブジェクトを作成
      final valueRange = sheets.ValueRange.fromJson({
        'values': rows,
      });

      // Sheetsに書き込み（追記モード）
      await sheetsApi.spreadsheets.values.append(
        valueRange,
        spreadsheetId,
        '$actualSheetName!A1', // シート名と開始セル
        valueInputOption: 'USER_ENTERED',
      );

      return logs.length;
    } catch (e) {
      print('Sheetsアップロードエラー: $e');
      rethrow;
    }
  }

  /// Spreadsheet内の既存UUIDを取得
  static Future<Set<String>> getExistingUuids({
    required String spreadsheetId,
    String sheetName = 'ActivityLogs',
  }) async {
    try {
      // 実際に使用するシート名を決定
      final actualSheetName = await _determineSheetName(spreadsheetId, sheetName);

      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        throw Exception('Google認証が必要です');
      }

      // A列（UUID列）のデータを取得
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$actualSheetName!A:A',
      );

      final values = response.values;
      if (values == null || values.isEmpty) {
        return {};
      }

      // ヘッダー行を除外してUUIDのセットを作成
      final uuids = <String>{};
      for (int i = 1; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] != null) {
          uuids.add(values[i][0].toString());
        }
      }

      return uuids;
    } catch (e) {
      print('既存UUID取得エラー: $e');
      return {};
    }
  }

  /// Spreadsheet内の既存UUIDと行番号のマッピングを取得
  static Future<Map<String, int>> getUuidRowMapping({
    required String spreadsheetId,
    String sheetName = 'ActivityLogs',
  }) async {
    try {
      // 実際に使用するシート名を決定
      final actualSheetName = await _determineSheetName(spreadsheetId, sheetName);

      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        throw Exception('Google認証が必要です');
      }

      // A列（UUID列）のデータを取得
      final response = await sheetsApi.spreadsheets.values.get(
        spreadsheetId,
        '$actualSheetName!A:A',
      );

      final values = response.values;
      if (values == null || values.isEmpty) {
        return {};
      }

      // UUIDと行番号のマッピングを作成（1-indexed）
      final mapping = <String, int>{};
      for (int i = 1; i < values.length; i++) {
        if (values[i].isNotEmpty && values[i][0] != null) {
          final uuid = values[i][0].toString();
          mapping[uuid] = i + 1; // Sheets APIは1-indexedなので+1
        }
      }

      return mapping;
    } catch (e) {
      print('UUIDマッピング取得エラー: $e');
      return {};
    }
  }

  /// 指定した行を削除
  static Future<void> deleteRows({
    required String spreadsheetId,
    required List<int> rowIndices,
    String sheetName = 'ActivityLogs',
  }) async {
    if (rowIndices.isEmpty) return;

    try {
      // 実際に使用するシート名を決定
      final actualSheetName = await _determineSheetName(spreadsheetId, sheetName);

      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        throw Exception('Google認証が必要です');
      }

      // シートIDを取得
      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      final sheet = spreadsheet.sheets?.firstWhere(
        (s) => s.properties?.title == actualSheetName,
        orElse: () => throw Exception('シート "$actualSheetName" が見つかりません'),
      );
      if (sheet == null) {
        throw Exception('シート "$actualSheetName" が見つかりません');
      }
      final sheetId = sheet.properties?.sheetId;
      if (sheetId == null) {
        throw Exception('シートIDが取得できません');
      }

      // 行を降順にソート（後ろから削除しないとインデックスがずれる）
      final sortedIndices = rowIndices.toList()..sort((a, b) => b.compareTo(a));

      // 削除リクエストを作成
      final requests = sortedIndices.map((rowIndex) {
        return sheets.Request(
          deleteDimension: sheets.DeleteDimensionRequest(
            range: sheets.DimensionRange(
              sheetId: sheetId,
              dimension: 'ROWS',
              startIndex: rowIndex - 1, // 0-indexed
              endIndex: rowIndex, // 0-indexed、endIndexは含まれない
            ),
          ),
        );
      }).toList();

      // バッチリクエストを実行
      await sheetsApi.spreadsheets.batchUpdate(
        sheets.BatchUpdateSpreadsheetRequest(requests: requests),
        spreadsheetId,
      );

      print('${rowIndices.length}行を削除しました');
    } catch (e) {
      print('行削除エラー: $e');
      rethrow;
    }
  }

  /// 重複しているログのUUIDを検出
  static Future<List<ActivityLog>> checkDuplicateLogs({
    required String spreadsheetId,
    required List<ActivityLog> logs,
  }) async {
    final existingUuids = await getExistingUuids(spreadsheetId: spreadsheetId);
    return logs
        .where((log) => log.uuid != null && log.uuid!.isNotEmpty && existingUuids.contains(log.uuid))
        .toList();
  }

  /// 1件のログをアップロード（自動アップロードモード用）
  ///
  /// [database]: データベースインスタンス
  /// [log]: アップロードするログ
  /// [spreadsheetId]: アップロード先のSpreadsheet ID
  ///
  /// 戻り値: アップロード成功時はtrue
  /// 例外: ネットワークエラーやその他のエラー時
  static Future<bool> uploadSingleLog({
    required AppDatabase database,
    required ActivityLog log,
    required String spreadsheetId,
  }) async {
    try {
      // Spreadsheetにアクセスできるか事前確認
      final exists = await checkSpreadsheetExists(spreadsheetId);
      if (!exists) {
        throw Exception('Spreadsheetにアクセスできません');
      }

      // 重複チェック
      final duplicates = await checkDuplicateLogs(
        spreadsheetId: spreadsheetId,
        logs: [log],
      );

      // 重複がある場合は既存行を削除
      if (duplicates.isNotEmpty) {
        final uuidRowMapping = await getUuidRowMapping(
          spreadsheetId: spreadsheetId,
        );

        final rowsToDelete = <int>[];
        for (final duplicate in duplicates) {
          if (duplicate.uuid != null &&
              uuidRowMapping.containsKey(duplicate.uuid)) {
            rowsToDelete.add(uuidRowMapping[duplicate.uuid]!);
          }
        }

        if (rowsToDelete.isNotEmpty) {
          await deleteRows(
            spreadsheetId: spreadsheetId,
            rowIndices: rowsToDelete,
          );
        }
      }

      // Sheetsにアップロード
      await uploadLogs(
        spreadsheetId: spreadsheetId,
        logs: [log],
      );

      // アップロード成功したログにマークを付ける
      await database.markAsUploaded(log.id);

      return true;
    } catch (e) {
      print('単一ログのアップロードエラー: $e');
      rethrow;
    }
  }

  /// 未アップロードのログをすべてアップロード
  ///
  /// [database]: データベースインスタンス
  /// [spreadsheetId]: アップロード先のSpreadsheet ID
  /// [onDuplicateFound]: 重複が見つかった時のコールバック（trueで上書き、falseでキャンセル）
  ///
  /// 戻り値: アップロードに成功したログの数
  static Future<int> uploadUnuploadedLogs({
    required AppDatabase database,
    required String spreadsheetId,
    Future<bool> Function(List<ActivityLog> duplicates)? onDuplicateFound,
  }) async {
    try {
      // Spreadsheetにアクセスできるか事前確認
      final exists = await checkSpreadsheetExists(spreadsheetId);
      if (!exists) {
        throw Exception(
            'Spreadsheetにアクセスできません（ID: $spreadsheetId）\n\n'
            '以下を確認してください：\n'
            '1. Spreadsheet IDが正しいか\n'
            '2. このGoogleアカウントでSpreadsheetにアクセスできるか\n'
            '3. Spreadsheetが削除されていないか');
      }

      // 未アップロードのログを取得
      final logs = await database.getUnuploadedLogs();

      if (logs.isEmpty) {
        return 0;
      }

      // 重複チェック
      final duplicates = await checkDuplicateLogs(
        spreadsheetId: spreadsheetId,
        logs: logs,
      );

      if (duplicates.isNotEmpty) {
        // 重複が見つかった場合
        if (onDuplicateFound != null) {
          final shouldContinue = await onDuplicateFound(duplicates);
          if (!shouldContinue) {
            // キャンセルされた
            return 0;
          }

          // 上書きする場合: Spreadsheet側の重複データを削除
          print('重複データを削除します: ${duplicates.length}件');

          // UUIDと行番号のマッピングを取得
          final uuidRowMapping = await getUuidRowMapping(
            spreadsheetId: spreadsheetId,
          );

          // 削除する行番号のリストを作成
          final rowsToDelete = <int>[];
          for (final duplicate in duplicates) {
            if (duplicate.uuid != null && uuidRowMapping.containsKey(duplicate.uuid)) {
              rowsToDelete.add(uuidRowMapping[duplicate.uuid]!);
            }
          }

          // 重複行を削除
          if (rowsToDelete.isNotEmpty) {
            await deleteRows(
              spreadsheetId: spreadsheetId,
              rowIndices: rowsToDelete,
            );
            print('${rowsToDelete.length}行を削除しました');
          }
        } else {
          // コールバックが指定されていない場合はエラー
          throw Exception('${duplicates.length}件の重複ログが見つかりました');
        }
      }

      // Sheetsにアップロード
      final count = await uploadLogs(
        spreadsheetId: spreadsheetId,
        logs: logs,
      );

      // アップロード成功したログにマークを付ける
      for (final log in logs) {
        await database.markAsUploaded(log.id);
      }

      return count;
    } catch (e) {
      print('未アップロードログのアップロードエラー: $e');
      rethrow;
    }
  }

  /// Spreadsheetが存在するか確認
  static Future<bool> checkSpreadsheetExists(String spreadsheetId) async {
    try {
      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        return false;
      }

      // Spreadsheetのメタデータを取得
      await sheetsApi.spreadsheets.get(spreadsheetId);
      return true;
    } catch (e) {
      print('Spreadsheet確認エラー: $e');
      return false;
    }
  }

  /// Spreadsheetのタイトルを取得
  static Future<String?> getSpreadsheetTitle(String spreadsheetId) async {
    try {
      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        return null;
      }

      final spreadsheet = await sheetsApi.spreadsheets.get(spreadsheetId);
      return spreadsheet.properties?.title;
    } catch (e) {
      print('Spreadsheetタイトル取得エラー: $e');
      return null;
    }
  }

  /// 設定マスターから設定一覧を取得
  ///
  /// [masterSpreadsheetId]: 設定マスタースプレッドシートのID
  /// [sheetName]: シート名（デフォルトは「シート1」）
  ///
  /// 戻り値: 設定情報のリスト（ID、名前、備考）
  static Future<List<SpreadsheetConfig>> getSpreadsheetConfigs({
    required String masterSpreadsheetId,
    String sheetName = 'シート1',
  }) async {
    try {
      final sheetsApi = await GoogleAuthService.getSheetsApi();
      if (sheetsApi == null) {
        throw Exception('Google認証が必要です');
      }

      // A列～C列のデータを取得（ID、名前、備考）
      final response = await sheetsApi.spreadsheets.values.get(
        masterSpreadsheetId,
        '$sheetName!A:C',
      );

      final values = response.values;
      if (values == null || values.isEmpty) {
        return [];
      }

      final configs = <SpreadsheetConfig>[];

      // ヘッダー行をスキップ（1行目）
      for (int i = 1; i < values.length; i++) {
        final row = values[i];
        if (row.isEmpty) continue;

        final id = row.isNotEmpty && row[0] != null ? row[0].toString() : '';
        final name = row.length > 1 && row[1] != null ? row[1].toString() : '';
        final note = row.length > 2 && row[2] != null ? row[2].toString() : '';

        // IDが空でない行のみ追加
        if (id.isNotEmpty) {
          configs.add(SpreadsheetConfig(
            id: id,
            name: name,
            note: note,
          ));
        }
      }

      return configs;
    } catch (e) {
      print('設定一覧取得エラー: $e');
      rethrow;
    }
  }
}

/// スプレッドシート設定情報
class SpreadsheetConfig {
  final String id;
  final String name;
  final String note;

  SpreadsheetConfig({
    required this.id,
    required this.name,
    required this.note,
  });
}
