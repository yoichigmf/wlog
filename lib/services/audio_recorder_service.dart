import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

class AudioRecorderService {
  static final AudioRecorder _recorder = AudioRecorder();
  static const _uuid = Uuid();

  // 録音を開始
  static Future<bool> startRecording() async {
    try {
      // パーミッションを確認
      if (await _recorder.hasPermission()) {
        // 一時ディレクトリに録音ファイルを保存
        final tempDir = await getTemporaryDirectory();
        final fileName = '${_uuid.v4()}.m4a';
        final filePath = p.join(tempDir.path, fileName);

        await _recorder.start(
          const RecordConfig(
            encoder: AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );

        return true;
      }

      return false;
    } catch (e) {
      return false;
    }
  }

  // 録音を停止して、録音ファイルのパスを返す
  static Future<String?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      return path;
    } catch (e) {
      return null;
    }
  }

  // 録音中かどうかを確認
  static Future<bool> isRecording() async {
    try {
      return await _recorder.isRecording();
    } catch (e) {
      return false;
    }
  }

  // 録音をキャンセル（ファイルを削除）
  static Future<void> cancelRecording() async {
    try {
      final path = await _recorder.stop();
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
      }
    } catch (e) {
      // エラーが発生しても処理を継続
    }
  }

  // 録音のパーミッションを確認
  static Future<bool> hasPermission() async {
    return await _recorder.hasPermission();
  }

  // リソースを解放
  static Future<void> dispose() async {
    await _recorder.dispose();
  }

  // 録音の一時停止
  static Future<void> pause() async {
    try {
      await _recorder.pause();
    } catch (e) {
      // エラーが発生しても処理を継続
    }
  }

  // 録音の再開
  static Future<void> resume() async {
    try {
      await _recorder.resume();
    } catch (e) {
      // エラーが発生しても処理を継続
    }
  }

  // 録音時間を取得（ストリーム）
  Stream<Duration> getRecordingDuration() {
    return Stream.periodic(const Duration(milliseconds: 100), (count) {
      return Duration(milliseconds: count * 100);
    });
  }
}
