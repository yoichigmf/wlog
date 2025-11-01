import 'dart:io';
import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/database.dart';
import '../services/file_service.dart';
import '../services/location_service.dart';
import '../services/audio_recorder_service.dart';
import '../services/sheets_upload_service.dart';

class AddLogPage extends StatefulWidget {
  final AppDatabase database;

  const AddLogPage({super.key, required this.database});

  @override
  State<AddLogPage> createState() => _AddLogPageState();
}

class _AddLogPageState extends State<AddLogPage> {
  final _textController = TextEditingController();
  final _imagePicker = ImagePicker();

  File? _selectedFile;
  MediaType? _mediaType;
  LocationData? _locationData;
  bool _isLoading = false;
  bool _isRecording = false;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;

  // モバイルプラットフォームかどうかを判定
  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  @override
  void initState() {
    super.initState();
    _getLocation();
  }

  @override
  void dispose() {
    _textController.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  /// バックグラウンドでログをアップロード（UIをブロックしない）
  void _uploadLogInBackground(int logId, String spreadsheetId) async {
    try {
      // データベースから保存したログを直接取得
      final logs = await widget.database.getAllLogs();
      final savedLog = logs.firstWhere((log) => log.id == logId);

      await SheetsUploadService.uploadSingleLog(
        database: widget.database,
        log: savedLog,
        spreadsheetId: spreadsheetId,
      );

      // アップロード成功
      print('バックグラウンドアップロード成功: ログID=$logId');
    } catch (e) {
      // ネットワークエラー時：自動的に手動モードに切り替え
      print('バックグラウンドアップロードエラー: $e');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('auto_upload_enabled', false);
        print('自動アップロードモードを無効にしました');
      } catch (prefsError) {
        print('設定の保存エラー: $prefsError');
      }
    }
  }

  // 位置情報を取得
  Future<void> _getLocation() async {
    final location = await LocationService.getLocationData();
    if (mounted) {
      setState(() {
        _locationData = location;
      });
    }
  }

  // 録音を開始
  Future<void> _startRecording() async {
    final hasPermission = await AudioRecorderService.hasPermission();
    if (!hasPermission) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('マイクのパーミッションが必要です')));
      }
      return;
    }

    final started = await AudioRecorderService.startRecording();
    if (started) {
      setState(() {
        _isRecording = true;
        _recordingDuration = Duration.zero;
      });

      // 録音時間をカウント
      _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(seconds: timer.tick);
          });
        }
      });
    }
  }

  // 録音を停止して保存
  Future<void> _stopRecording() async {
    _recordingTimer?.cancel();

    final path = await AudioRecorderService.stopRecording();
    if (path != null) {
      setState(() {
        _selectedFile = File(path);
        _mediaType = MediaType.audio;
        _isRecording = false;
      });
    }
  }

  // 録音をキャンセルして終了
  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await AudioRecorderService.cancelRecording();

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
      _selectedFile = null;
      _mediaType = null;
    });
  }

  // 画像を選択
  Future<void> _pickImage() async {
    try {
      final XFile? image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
      );
      if (image != null) {
        setState(() {
          _selectedFile = File(image.path);
          _mediaType = MediaType.image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('画像選択エラー: $e')));
      }
    }
  }

  // カメラで写真を撮影
  Future<void> _takePhoto() async {
    try {
      final XFile? photo = await _imagePicker.pickImage(
        source: ImageSource.camera,
      );
      if (photo != null) {
        setState(() {
          _selectedFile = File(photo.path);
          _mediaType = MediaType.image;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('カメラエラー: $e')));
      }
    }
  }

  // 動画を選択
  Future<void> _pickVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.gallery,
      );
      if (video != null) {
        setState(() {
          _selectedFile = File(video.path);
          _mediaType = MediaType.video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('動画選択エラー: $e')));
      }
    }
  }

  // カメラで動画を録画
  Future<void> _recordVideo() async {
    try {
      final XFile? video = await _imagePicker.pickVideo(
        source: ImageSource.camera,
      );
      if (video != null) {
        setState(() {
          _selectedFile = File(video.path);
          _mediaType = MediaType.video;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('カメラエラー: $e')));
      }
    }
  }

  // メディアを削除
  void _removeMedia() {
    setState(() {
      _selectedFile = null;
      _mediaType = null;
    });
  }

  // ログを保存
  Future<void> _saveLog() async {
    // テキストもメディアも空の場合はエラー
    if (_textController.text.trim().isEmpty && _selectedFile == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('テキストまたはメディアを入力してください')));
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? fileName;
      String? textContent = _textController.text.trim();
      if (textContent.isEmpty) {
        textContent = null;
      }

      // メディアファイルを保存
      if (_selectedFile != null && _mediaType != null) {
        final extension = FileService.getFileExtension(_selectedFile!.path);
        fileName = await FileService.saveMediaFile(_selectedFile!, extension);
      }

      // データベースに保存
      final logId = await widget.database.addLog(
        textContent: textContent,
        mediaType: _mediaType,
        fileName: fileName,
        latitude: _locationData?.latitude,
        longitude: _locationData?.longitude,
      );

      // 自動アップロード設定をチェック
      final prefs = await SharedPreferences.getInstance();
      final autoUploadEnabled = prefs.getBool('auto_upload_enabled') ?? false;
      final spreadsheetId = prefs.getString('spreadsheet_id');

      if (autoUploadEnabled && spreadsheetId != null && spreadsheetId.isNotEmpty) {
        // 自動アップロードモード：バックグラウンドで1件のログをアップロード
        // UIをブロックしないように即座にメッセージを表示して画面を閉じる
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(
            content: Text('ログを保存しました（バックグラウンドでアップロード中...）'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 2),
          ));
        }

        // バックグラウンドでアップロード処理を実行（UIをブロックしない）
        _uploadLogInBackground(logId, spreadsheetId);
      } else {
        // 手動モード：ローカルに保存のみ
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('ログを保存しました')));
        }
      }

      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('保存エラー: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // 録音時間のフォーマット
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ログを追加'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      resizeToAvoidBottomInset: true,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // テキスト入力
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _textController,
                            decoration: InputDecoration(
                              labelText: 'テキストを入力',
                              hintText: '活動内容を記録...',
                              border: const OutlineInputBorder(),
                              helperText: _isRecording
                                  ? '録音中はテキスト入力できません。下の「終了」ボタンで録音を終了してください。'
                                  : 'テキストのみ、またはメディアと一緒に記録できます',
                              helperMaxLines: 2,
                            ),
                            maxLines: 5,
                            minLines: 5,
                            enabled: !_isRecording,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            enableInteractiveSelection: true,
                            autocorrect: true,
                            enableSuggestions: true,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // メディア追加ボタン
                  if (!_isRecording && _selectedFile == null) ...[
                    const Text(
                      'メディアを追加',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 音声録音ボタン
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.mic, color: Colors.red),
                        title: const Text('音声を録音'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _startRecording,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 画像ボタン
                    if (_isMobilePlatform)
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: InkWell(
                                onTap: _takePhoto,
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.camera_alt,
                                        size: 32,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text('写真を撮影'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Card(
                              child: InkWell(
                                onTap: _pickImage,
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.photo_library,
                                        size: 32,
                                        color: Colors.green,
                                      ),
                                      SizedBox(height: 8),
                                      Text('画像を選択'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Card(
                        child: InkWell(
                          onTap: _pickImage,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.photo_library,
                                  size: 32,
                                  color: Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text('画像を選択', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 8),

                    // 動画ボタン
                    if (_isMobilePlatform)
                      Row(
                        children: [
                          Expanded(
                            child: Card(
                              child: InkWell(
                                onTap: _recordVideo,
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.videocam,
                                        size: 32,
                                        color: Colors.purple,
                                      ),
                                      SizedBox(height: 8),
                                      Text('動画を録画'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Card(
                              child: InkWell(
                                onTap: _pickVideo,
                                child: const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.video_library,
                                        size: 32,
                                        color: Colors.purple,
                                      ),
                                      SizedBox(height: 8),
                                      Text('動画を選択'),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Card(
                        child: InkWell(
                          onTap: _pickVideo,
                          child: const Padding(
                            padding: EdgeInsets.all(16),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.video_library,
                                  size: 32,
                                  color: Colors.purple,
                                ),
                                SizedBox(width: 8),
                                Text('動画を選択', style: TextStyle(fontSize: 16)),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],

                  // 録音中の表示
                  if (_isRecording) ...[
                    Card(
                      color: Colors.red[50],
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.mic, size: 64, color: Colors.red),
                            const SizedBox(height: 16),
                            const Text(
                              '録音中...',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _formatDuration(_recordingDuration),
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.red,
                              ),
                            ),
                            const SizedBox(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _cancelRecording,
                                      icon: const Icon(Icons.close),
                                      label: const Text(
                                        '終了\n(破棄)',
                                        textAlign: TextAlign.center,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.grey,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    child: ElevatedButton.icon(
                                      onPressed: _stopRecording,
                                      icon: const Icon(Icons.check),
                                      label: const Text(
                                        '完了\n(保存)',
                                        textAlign: TextAlign.center,
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '※「終了」でテキスト入力に戻ります',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],

                  // 選択されたメディアの表示
                  if (_selectedFile != null && _mediaType != null) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _mediaType == MediaType.audio
                                      ? Icons.audiotrack
                                      : _mediaType == MediaType.image
                                      ? Icons.image
                                      : Icons.videocam,
                                  color: _mediaType == MediaType.audio
                                      ? Colors.orange
                                      : _mediaType == MediaType.image
                                      ? Colors.green
                                      : Colors.purple,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  '添付ファイル',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete,
                                    color: Colors.red,
                                  ),
                                  onPressed: _removeMedia,
                                  tooltip: '削除',
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(fontSize: 12),
                            ),
                            if (_mediaType == MediaType.image) ...[
                              const SizedBox(height: 16),
                              Image.file(
                                _selectedFile!,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // 位置情報表示
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 20),
                              const SizedBox(width: 8),
                              const Text(
                                '位置情報',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(Icons.refresh),
                                onPressed: _getLocation,
                                tooltip: '位置情報を更新',
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _locationData != null
                                ? _locationData.toString()
                                : '位置情報を取得できませんでした',
                            style: TextStyle(
                              color: _locationData != null
                                  ? Colors.black87
                                  : Colors.red,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // 保存ボタン
                  ElevatedButton(
                    onPressed: _isRecording ? null : _saveLog,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('保存', style: TextStyle(fontSize: 18)),
                  ),
                ],
              ),
            ),
    );
  }
}
