import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../services/camera_service.dart';

/// カメラ撮影画面
class CameraPage extends StatefulWidget {
  final bool isVideo; // true: 動画, false: 写真

  const CameraPage({super.key, this.isVideo = false});

  @override
  State<CameraPage> createState() => _CameraPageState();
}

class _CameraPageState extends State<CameraPage> {
  CameraController? _controller;
  bool _isInitialized = false;
  bool _isRecording = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await CameraService.getCameras();
      if (cameras.isEmpty) {
        setState(() {
          _errorMessage = 'カメラが見つかりません';
        });
        return;
      }

      // 最初のカメラを使用、解像度を下げて試す
      _controller = CameraController(
        cameras[0],
        ResolutionPreset.medium, // highからmediumに変更
        enableAudio: widget.isVideo,
        imageFormatGroup: ImageFormatGroup.jpeg, // 明示的にフォーマット指定
      );

      await _controller!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
    } catch (e) {
      print('カメラ初期化エラー: $e');

      // 解像度を下げて再試行
      if (_controller == null && mounted) {
        try {
          final cameras = await CameraService.getCameras();
          if (cameras.isNotEmpty) {
            _controller = CameraController(
              cameras[0],
              ResolutionPreset.low, // さらに低解像度で試行
              enableAudio: false, // オーディオを無効化
              imageFormatGroup: ImageFormatGroup.jpeg,
            );
            await _controller!.initialize();
            if (mounted) {
              setState(() {
                _isInitialized = true;
              });
              return;
            }
          }
        } catch (e2) {
          print('低解像度での再試行も失敗: $e2');
        }
      }

      setState(() {
        _errorMessage = 'カメラ初期化エラー: $e\n\n'
            'Windows版ではカメラが正常に動作しない場合があります。\n'
            'ファイルピッカーで画像を選択してください。';
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  /// 写真を撮影
  Future<void> _takePicture() async {
    if (_controller == null || !_isInitialized) return;

    try {
      final file = await CameraService.takePicture(_controller!);
      if (file != null && mounted) {
        Navigator.of(context).pop(file);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('撮影エラー: $e')),
        );
      }
    }
  }

  /// 動画録画を開始/停止
  Future<void> _toggleVideoRecording() async {
    if (_controller == null || !_isInitialized) return;

    try {
      if (_isRecording) {
        // 録画停止
        final file = await CameraService.stopVideoRecording(_controller!);
        if (file != null && mounted) {
          Navigator.of(context).pop(file);
        }
      } else {
        // 録画開始
        await CameraService.startVideoRecording(_controller!);
        setState(() {
          _isRecording = true;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('録画エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isVideo ? '動画を撮影' : '写真を撮影'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ],
                ),
              ),
            )
          : !_isInitialized
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    // カメラプレビュー
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _controller!.value.aspectRatio,
                          child: CameraPreview(_controller!),
                        ),
                      ),
                    ),

                    // 録画中インジケーター
                    if (_isRecording)
                      Container(
                        padding: const EdgeInsets.all(8),
                        color: Colors.red,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.fiber_manual_record, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              '録画中',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 撮影/録画ボタン
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // キャンセルボタン
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, size: 32),
                            tooltip: 'キャンセル',
                          ),

                          // 撮影/録画ボタン
                          IconButton(
                            onPressed: widget.isVideo
                                ? _toggleVideoRecording
                                : _takePicture,
                            icon: Icon(
                              widget.isVideo
                                  ? (_isRecording
                                      ? Icons.stop_circle
                                      : Icons.videocam)
                                  : Icons.camera,
                              size: 64,
                              color: _isRecording ? Colors.red : Colors.blue,
                            ),
                            tooltip: widget.isVideo
                                ? (_isRecording ? '録画停止' : '録画開始')
                                : '撮影',
                          ),

                          // スペーサー
                          const SizedBox(width: 32),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}
