import 'dart:io';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// カメラサービス
class CameraService {
  static List<CameraDescription>? _cameras;
  static bool _initialized = false;

  /// 利用可能なカメラを初期化
  static Future<bool> initialize() async {
    if (_initialized) return _cameras != null && _cameras!.isNotEmpty;

    try {
      _cameras = await availableCameras();
      _initialized = true;
      print('カメラ初期化成功: ${_cameras!.length}台のカメラを検出');
      return _cameras!.isNotEmpty;
    } catch (e) {
      print('カメラ初期化エラー: $e');
      _cameras = [];
      _initialized = true;
      return false;
    }
  }

  /// カメラが利用可能かチェック
  static Future<bool> isCameraAvailable() async {
    if (!_initialized) {
      await initialize();
    }
    return _cameras != null && _cameras!.isNotEmpty;
  }

  /// 利用可能なカメラのリストを取得
  static Future<List<CameraDescription>> getCameras() async {
    if (!_initialized) {
      await initialize();
    }
    return _cameras ?? [];
  }

  /// 写真を撮影
  static Future<File?> takePicture(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) {
        print('カメラが初期化されていません');
        return null;
      }

      // 一時ディレクトリに保存
      final directory = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.jpg';
      final filePath = '${directory.path}/$fileName';

      final XFile image = await controller.takePicture();

      // 一時ファイルを指定パスにコピー
      final File file = File(filePath);
      await File(image.path).copy(filePath);

      print('写真を撮影しました: $filePath');
      return file;
    } catch (e) {
      print('写真撮影エラー: $e');
      return null;
    }
  }

  /// 動画を録画
  static Future<File?> startVideoRecording(CameraController controller) async {
    try {
      if (!controller.value.isInitialized) {
        print('カメラが初期化されていません');
        return null;
      }

      if (controller.value.isRecordingVideo) {
        print('既に録画中です');
        return null;
      }

      await controller.startVideoRecording();
      print('録画を開始しました');
      return null; // 録画中はnullを返す
    } catch (e) {
      print('録画開始エラー: $e');
      return null;
    }
  }

  /// 動画録画を停止
  static Future<File?> stopVideoRecording(CameraController controller) async {
    try {
      if (!controller.value.isRecordingVideo) {
        print('録画していません');
        return null;
      }

      final XFile video = await controller.stopVideoRecording();

      // 一時ディレクトリに保存
      final directory = await getTemporaryDirectory();
      final fileName = '${const Uuid().v4()}.mp4';
      final filePath = '${directory.path}/$fileName';

      // 一時ファイルを指定パスにコピー
      final File file = File(filePath);
      await File(video.path).copy(filePath);

      print('動画を保存しました: $filePath');
      return file;
    } catch (e) {
      print('録画停止エラー: $e');
      return null;
    }
  }
}
