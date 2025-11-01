import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

class FileService {
  static const _uuid = Uuid();

  // アプリケーションのドキュメントディレクトリを取得
  static Future<Directory> getAppDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final logsDir = Directory(p.join(appDir.path, 'activity_logs'));

    if (!await logsDir.exists()) {
      await logsDir.create(recursive: true);
    }

    return logsDir;
  }

  // メディアファイルを保存して、保存したファイル名を返す
  static Future<String> saveMediaFile(File sourceFile, String extension) async {
    final logsDir = await getAppDirectory();

    // ユニークなファイル名を生成
    final fileName = '${_uuid.v4()}.$extension';
    final destinationPath = p.join(logsDir.path, fileName);

    // ファイルをコピー
    await sourceFile.copy(destinationPath);

    return fileName;
  }

  // 指定したファイル名でファイルを保存
  static Future<void> saveFileWithName(File sourceFile, String fileName) async {
    final logsDir = await getAppDirectory();
    final destinationPath = p.join(logsDir.path, fileName);

    // ファイルをコピー
    await sourceFile.copy(destinationPath);
  }

  // ファイル名からフルパスを取得
  static Future<String> getFilePath(String fileName) async {
    final logsDir = await getAppDirectory();
    return p.join(logsDir.path, fileName);
  }

  // ファイルを取得
  static Future<File?> getFile(String fileName) async {
    final filePath = await getFilePath(fileName);
    final file = File(filePath);

    if (await file.exists()) {
      return file;
    }

    return null;
  }

  // ファイルを削除
  static Future<bool> deleteFile(String fileName) async {
    try {
      final filePath = await getFilePath(fileName);
      final file = File(filePath);

      if (await file.exists()) {
        await file.delete();
        return true;
      }

      return false;
    } catch (e) {
      // エラーが発生しても処理を継続
      return false;
    }
  }

  // ファイル拡張子を取得
  static String getFileExtension(String path) {
    return p.extension(path).replaceAll('.', '');
  }

  // ファイルサイズを取得（バイト単位）
  static Future<int?> getFileSize(String fileName) async {
    final file = await getFile(fileName);
    if (file != null && await file.exists()) {
      return await file.length();
    }
    return null;
  }

  // ファイルサイズを人間が読みやすい形式に変換
  static String formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(2)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
    }
  }
}
