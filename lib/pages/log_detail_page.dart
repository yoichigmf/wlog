import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:drift/drift.dart' as drift;

import '../data/database.dart';
import '../services/file_service.dart';
import '../services/location_service.dart';

class LogDetailPage extends StatefulWidget {
  final ActivityLog log;
  final AppDatabase database;

  const LogDetailPage({
    super.key,
    required this.log,
    required this.database,
  });

  @override
  State<LogDetailPage> createState() => _LogDetailPageState();
}

class _LogDetailPageState extends State<LogDetailPage> {
  File? _mediaFile;
  Uint8List? _mediaBytes; // Web版用のバイトデータ
  bool _isLoading = true;
  bool _isEditMode = false;

  // Edit mode controllers
  late TextEditingController _textController;
  late TextEditingController _latitudeController;
  late TextEditingController _longitudeController;
  String? _newFileName;
  File? _newMediaFile;
  Uint8List? _newMediaBytes; // Web版用の新しいファイルのバイトデータ
  String? _newMediaType;
  bool _removeFile = false;
  bool _clearUploadTimestamp = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.log.textContent ?? '');
    _latitudeController = TextEditingController(
        text: widget.log.latitude?.toString() ?? '');
    _longitudeController = TextEditingController(
        text: widget.log.longitude?.toString() ?? '');
    _loadMediaFile();
  }

  @override
  void dispose() {
    _textController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    super.dispose();
  }

  // メディアファイルを読み込む
  Future<void> _loadMediaFile() async {
    if (widget.log.fileName != null) {
      if (kIsWeb) {
        // Web版: ファイルをバイトデータとして読み込む
        // Web版ではFileServiceが使えないため、データベースに保存する必要がある
        // または、Blobストレージを使用する
        // 現時点ではWeb版でのファイル表示はサポート外とする
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        // ネイティブ版: 通常のFile操作
        final file = await FileService.getFile(widget.log.fileName!);
        if (file != null) {
          final bytes = await file.readAsBytes();
          if (mounted) {
            setState(() {
              _mediaFile = file;
              _mediaBytes = bytes;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _isLoading = false;
            });
          }
        }
      }
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Google Mapsで位置を開く
  Future<void> _openInMaps() async {
    final lat = _isEditMode
        ? double.tryParse(_latitudeController.text)
        : widget.log.latitude;
    final lon = _isEditMode
        ? double.tryParse(_longitudeController.text)
        : widget.log.longitude;

    if (lat != null && lon != null) {
      final location = LocationData(
        latitude: lat,
        longitude: lon,
      );
      final url = location.toGoogleMapsUrl();
      final uri = Uri.parse(url);

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('マップを開けませんでした')),
          );
        }
      }
    }
  }

  // メディアタイプの表示名を取得
  String _getMediaTypeName(String? mediaType) {
    if (mediaType == null) return 'テキストのみ';

    switch (mediaType) {
      case 'audio':
        return '音声';
      case 'image':
        return '画像';
      case 'video':
        return '動画';
      default:
        return 'テキストのみ';
    }
  }

  // プラットフォーム判定
  bool get _isMobilePlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid || Platform.isIOS;
  }

  // ファイル選択（画像）
  Future<void> _pickImage() async {
    if (_isMobilePlatform) {
      // モバイルではカメラまたはギャラリーを選択
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('画像を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('ギャラリーから選択'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final picker = ImagePicker();
        final XFile? pickedFile = await picker.pickImage(source: source);

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final bytes = await pickedFile.readAsBytes();
          final uuid = const Uuid();
          final fileName = '${uuid.v4()}.jpg';

          setState(() {
            _newMediaFile = file;
            _newMediaBytes = bytes;
            _newFileName = fileName;
            _newMediaType = 'image';
            _removeFile = false;
          });
        }
      }
    } else {
      // デスクトップ/Web版ではファイルピッカーのみ
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
      );

      if (result != null) {
        final fileData = result.files.single;
        final uuid = const Uuid();
        final extension = fileData.extension ?? 'jpg';
        final fileName = '${uuid.v4()}.$extension';

        setState(() {
          if (kIsWeb) {
            // Web版: バイトデータを使用
            _newMediaBytes = fileData.bytes;
            _newMediaFile = null;
          } else {
            // デスクトップ版: ファイルパスを使用
            if (fileData.path != null) {
              _newMediaFile = File(fileData.path!);
            }
          }
          _newFileName = fileName;
          _newMediaType = 'image';
          _removeFile = false;
        });
      }
    }
  }

  // ファイル選択（動画）
  Future<void> _pickVideo() async {
    if (_isMobilePlatform) {
      // モバイルではカメラまたはギャラリーを選択
      final source = await showDialog<ImageSource>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('動画を選択'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('カメラで撮影'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.video_library),
                title: const Text('ギャラリーから選択'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
            ],
          ),
        ),
      );

      if (source != null) {
        final picker = ImagePicker();
        final XFile? pickedFile = await picker.pickVideo(source: source);

        if (pickedFile != null) {
          final file = File(pickedFile.path);
          final uuid = const Uuid();
          final fileName = '${uuid.v4()}.mp4';

          setState(() {
            _newMediaFile = file;
            _newFileName = fileName;
            _newMediaType = 'video';
            _removeFile = false;
          });
        }
      }
    } else {
      // デスクトップではファイルピッカーのみ
      final result = await FilePicker.platform.pickFiles(
        type: FileType.video,
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final uuid = const Uuid();
        final extension = result.files.single.extension ?? 'mp4';
        final fileName = '${uuid.v4()}.$extension';

        setState(() {
          _newMediaFile = file;
          _newFileName = fileName;
          _newMediaType = 'video';
          _removeFile = false;
        });
      }
    }
  }

  // ファイル選択（音声）
  Future<void> _pickAudio() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
    );

    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final uuid = const Uuid();
      final extension = result.files.single.extension ?? 'm4a';
      final fileName = '${uuid.v4()}.$extension';

      setState(() {
        _newMediaFile = file;
        _newFileName = fileName;
        _newMediaType = 'audio';
        _removeFile = false;
      });
    }
  }

  // ファイル削除
  void _removeMediaFile() {
    setState(() {
      _removeFile = true;
      _newMediaFile = null;
      _newFileName = null;
      _newMediaType = null;
    });
  }

  // 保存処理
  Future<void> _saveChanges() async {
    try {
      // 入力値の検証
      double? newLatitude;
      double? newLongitude;

      if (_latitudeController.text.trim().isNotEmpty) {
        newLatitude = double.tryParse(_latitudeController.text.trim());
        if (newLatitude == null || newLatitude < -90 || newLatitude > 90) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('緯度は-90から90の範囲で入力してください')),
          );
          return;
        }
      }

      if (_longitudeController.text.trim().isNotEmpty) {
        newLongitude = double.tryParse(_longitudeController.text.trim());
        if (newLongitude == null || newLongitude < -180 || newLongitude > 180) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('経度は-180から180の範囲で入力してください')),
          );
          return;
        }
      }

      // 新しいファイルがある場合は保存
      String? finalFileName = widget.log.fileName;
      String? finalMediaType = widget.log.mediaType;

      if (_newMediaFile != null && _newFileName != null) {
        // 古いファイルを削除
        if (widget.log.fileName != null) {
          await FileService.deleteFile(widget.log.fileName!);
        }

        // 新しいファイルを保存
        await FileService.saveFileWithName(_newMediaFile!, _newFileName!);
        finalFileName = _newFileName;
        finalMediaType = _newMediaType;
      } else if (_removeFile) {
        // ファイル削除
        if (widget.log.fileName != null) {
          await FileService.deleteFile(widget.log.fileName!);
        }
        finalFileName = null;
        finalMediaType = null;
      }

      // データベースを更新
      final updatedCount = await (widget.database.update(widget.database.activityLogs)
            ..where((t) => t.id.equals(widget.log.id)))
          .write(
        ActivityLogsCompanion(
          textContent: drift.Value(_textController.text.trim().isEmpty
              ? null
              : _textController.text.trim()),
          latitude: drift.Value(newLatitude),
          longitude: drift.Value(newLongitude),
          fileName: drift.Value(finalFileName),
          mediaType: drift.Value(finalMediaType),
          uploadedAt: drift.Value(_clearUploadTimestamp ? null : widget.log.uploadedAt),
        ),
      );

      if (updatedCount > 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログを更新しました')),
        );

        // 編集モードを終了し、データを再読み込み
        setState(() {
          _isEditMode = false;
          _newMediaFile = null;
          _newFileName = null;
          _newMediaType = null;
          _removeFile = false;
          _clearUploadTimestamp = false;
        });

        // ページをリロード（親ウィジェットの log を更新するため、一度戻って再度開く）
        Navigator.pop(context, true); // trueを返して更新を通知
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('ログの更新に失敗しました')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラーが発生しました: $e')),
        );
      }
    }
  }

  // キャンセル処理
  void _cancelEdit() {
    setState(() {
      _isEditMode = false;
      _textController.text = widget.log.textContent ?? '';
      _latitudeController.text = widget.log.latitude?.toString() ?? '';
      _longitudeController.text = widget.log.longitude?.toString() ?? '';
      _newMediaFile = null;
      _newFileName = null;
      _newMediaType = null;
      _removeFile = false;
      _clearUploadTimestamp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy年MM月dd日 HH:mm:ss');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditMode ? 'ログ編集' : 'ログ詳細'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          if (!_isEditMode)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                setState(() {
                  _isEditMode = true;
                });
              },
              tooltip: '編集',
            ),
          if (_isEditMode) ...[
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: _cancelEdit,
              tooltip: 'キャンセル',
            ),
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _saveChanges,
              tooltip: '保存',
            ),
          ],
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 登録日時
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '登録日時',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(Icons.access_time, size: 20),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  dateFormat.format(widget.log.createdAt.toLocal()),
                                  style: const TextStyle(fontSize: 16),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // テキストコンテンツ
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'テキスト',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isEditMode)
                            TextField(
                              controller: _textController,
                              maxLines: 5,
                              decoration: const InputDecoration(
                                hintText: 'テキストを入力',
                                border: OutlineInputBorder(),
                              ),
                            )
                          else
                            Text(
                              widget.log.textContent?.isNotEmpty == true
                                  ? widget.log.textContent!
                                  : 'テキストなし',
                              style: TextStyle(
                                fontSize: 16,
                                color: widget.log.textContent?.isNotEmpty == true
                                    ? null
                                    : Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // メディアコンテンツ
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                (_newMediaType ?? widget.log.mediaType) == 'audio'
                                    ? Icons.audiotrack
                                    : (_newMediaType ?? widget.log.mediaType) == 'image'
                                        ? Icons.image
                                        : (_newMediaType ?? widget.log.mediaType) == 'video'
                                            ? Icons.videocam
                                            : Icons.text_fields,
                                color: (_newMediaType ?? widget.log.mediaType) == 'audio'
                                    ? Colors.orange
                                    : (_newMediaType ?? widget.log.mediaType) == 'image'
                                        ? Colors.green
                                        : (_newMediaType ?? widget.log.mediaType) == 'video'
                                            ? Colors.purple
                                            : Colors.grey,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _getMediaTypeName(_newMediaType ?? widget.log.mediaType),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // ファイル表示または選択
                          if (_isEditMode) ...[
                            if (_newMediaFile != null) ...[
                              // 新しいファイルが選択されている
                              if (_newMediaType == 'image') ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _newMediaBytes != null
                                      ? Image.memory(
                                          _newMediaBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : (_newMediaFile != null && !kIsWeb
                                          ? Image.file(
                                              _newMediaFile!,
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(Icons.image, size: 100)),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text('新しいファイル: $_newFileName'),
                            ] else if (!_removeFile && (_mediaFile != null || _mediaBytes != null)) ...[
                              // 既存ファイルを表示
                              if (widget.log.mediaType == 'image') ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _mediaBytes != null
                                      ? Image.memory(
                                          _mediaBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : (_mediaFile != null && !kIsWeb
                                          ? Image.file(
                                              _mediaFile!,
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(Icons.image, size: 100)),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text('ファイル名: ${widget.log.fileName}'),
                              FutureBuilder<int?>(
                                future: FileService.getFileSize(widget.log.fileName!),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Text(
                                      'サイズ: ${FileService.formatFileSize(snapshot.data!)}',
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ] else if (_removeFile || widget.log.mediaType == null) ...[
                              Text(
                                'ファイルなし',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
                                  icon: const Icon(Icons.image, size: 20),
                                  label: const Text('画像'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickVideo,
                                  icon: const Icon(Icons.videocam, size: 20),
                                  label: const Text('動画'),
                                ),
                                ElevatedButton.icon(
                                  onPressed: _pickAudio,
                                  icon: const Icon(Icons.audiotrack, size: 20),
                                  label: const Text('音声'),
                                ),
                                if ((_newMediaFile != null || (!_removeFile && widget.log.fileName != null)))
                                  ElevatedButton.icon(
                                    onPressed: _removeMediaFile,
                                    icon: const Icon(Icons.delete, size: 20),
                                    label: const Text('削除'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.red[100],
                                      foregroundColor: Colors.red[900],
                                    ),
                                  ),
                              ],
                            ),
                          ] else ...[
                            // 表示モード
                            if ((_mediaFile != null || _mediaBytes != null) && widget.log.mediaType != null) ...[
                              if (widget.log.mediaType == 'image') ...[
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: _mediaBytes != null
                                      ? Image.memory(
                                          _mediaBytes!,
                                          fit: BoxFit.contain,
                                        )
                                      : (_mediaFile != null && !kIsWeb
                                          ? Image.file(
                                              _mediaFile!,
                                              fit: BoxFit.contain,
                                            )
                                          : const Icon(Icons.image, size: 100)),
                                ),
                                const SizedBox(height: 8),
                              ],
                              Text('ファイル名: ${widget.log.fileName}'),
                              FutureBuilder<int?>(
                                future: FileService.getFileSize(widget.log.fileName!),
                                builder: (context, snapshot) {
                                  if (snapshot.hasData && snapshot.data != null) {
                                    return Text(
                                      'サイズ: ${FileService.formatFileSize(snapshot.data!)}',
                                      style: const TextStyle(fontSize: 14),
                                    );
                                  }
                                  return const SizedBox.shrink();
                                },
                              ),
                            ] else
                              Text(
                                'ファイルなし',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // 位置情報
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '位置情報',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          if (_isEditMode) ...[
                            TextField(
                              controller: _latitudeController,
                              decoration: const InputDecoration(
                                labelText: '緯度 (-90 ~ 90)',
                                border: OutlineInputBorder(),
                                hintText: '例: 35.681236',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _longitudeController,
                              decoration: const InputDecoration(
                                labelText: '経度 (-180 ~ 180)',
                                border: OutlineInputBorder(),
                                hintText: '例: 139.767125',
                              ),
                              keyboardType: const TextInputType.numberWithOptions(
                                  decimal: true, signed: true),
                            ),
                          ] else ...[
                            if (widget.log.latitude != null &&
                                widget.log.longitude != null)
                              Row(
                                children: [
                                  const Icon(Icons.location_on, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '緯度: ${widget.log.latitude!.toStringAsFixed(6)}\n経度: ${widget.log.longitude!.toStringAsFixed(6)}',
                                      style: const TextStyle(fontSize: 14),
                                    ),
                                  ),
                                ],
                              )
                            else
                              Text(
                                '位置情報が記録されていません',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            onPressed: _openInMaps,
                            icon: const Icon(Icons.map),
                            label: const Text('Google Mapsで開く'),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // アップロード状態
                  if (widget.log.uploadedAt != null || _isEditMode)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'アップロード状態',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (widget.log.uploadedAt != null && !_clearUploadTimestamp)
                              Text(
                                'アップロード済み: ${dateFormat.format(widget.log.uploadedAt!.toLocal())}',
                                style: const TextStyle(fontSize: 14),
                              )
                            else
                              Text(
                                '未アップロード',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            if (_isEditMode && widget.log.uploadedAt != null) ...[
                              const SizedBox(height: 12),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _clearUploadTimestamp = !_clearUploadTimestamp;
                                  });
                                },
                                icon: Icon(_clearUploadTimestamp
                                    ? Icons.undo
                                    : Icons.delete),
                                label: Text(_clearUploadTimestamp
                                    ? '削除を取り消す'
                                    : 'アップロード日時を削除'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _clearUploadTimestamp
                                      ? Colors.blue[100]
                                      : Colors.red[100],
                                  foregroundColor: _clearUploadTimestamp
                                      ? Colors.blue[900]
                                      : Colors.red[900],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}
