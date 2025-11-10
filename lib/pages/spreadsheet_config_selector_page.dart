import 'package:flutter/material.dart';
import '../services/sheets_upload_service.dart';

/// スプレッドシート設定選択画面
class SpreadsheetConfigSelectorPage extends StatefulWidget {
  const SpreadsheetConfigSelectorPage({super.key});

  @override
  State<SpreadsheetConfigSelectorPage> createState() =>
      _SpreadsheetConfigSelectorPageState();
}

class _SpreadsheetConfigSelectorPageState
    extends State<SpreadsheetConfigSelectorPage> {
  final TextEditingController _manualIdController = TextEditingController();
  List<SpreadsheetConfig>? _configs;
  bool _isLoading = false;
  String? _errorMessage;

  // マスタースプレッドシートID
  static const String _masterSpreadsheetId =
      '1m52FpNl4x4a3TlbjcBIZEuPUpEGf8SnqG3Dn04fLSco';

  @override
  void initState() {
    super.initState();
    _loadConfigs();
  }

  @override
  void dispose() {
    _manualIdController.dispose();
    super.dispose();
  }

  /// 設定一覧を読み込む
  Future<void> _loadConfigs() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final configs = await SheetsUploadService.getSpreadsheetConfigs(
        masterSpreadsheetId: _masterSpreadsheetId,
      );
      setState(() {
        _configs = configs;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'エラー: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 手動入力されたIDを返す
  void _returnManualId() {
    final id = _manualIdController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('IDを入力してください')),
      );
      return;
    }
    // 手動入力の場合はコンテンツフォルダIDなしの設定を返す
    Navigator.of(context).pop(SpreadsheetConfig(
      id: id,
      name: '手動入力',
      note: '',
    ));
  }

  /// 選択された設定を返す
  void _returnSelectedConfig(SpreadsheetConfig config) {
    Navigator.of(context).pop(config);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('アップロード先を選択'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Column(
        children: [
          // 手動入力セクション
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '手動入力',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _manualIdController,
                    decoration: const InputDecoration(
                      labelText: 'Spreadsheet ID',
                      hintText: '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _returnManualId,
                      icon: const Icon(Icons.keyboard),
                      label: const Text('この ID を使用'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // リストセクション
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  '登録済み設定',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: _isLoading ? null : _loadConfigs,
                  tooltip: '再読み込み',
                ),
              ],
            ),
          ),

          // 設定一覧
          Expanded(
            child: _buildConfigList(),
          ),
        ],
      ),
    );
  }

  Widget _buildConfigList() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadConfigs,
                icon: const Icon(Icons.refresh),
                label: const Text('再試行'),
              ),
            ],
          ),
        ),
      );
    }

    if (_configs == null || _configs!.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            '登録済みの設定がありません',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _configs!.length,
      itemBuilder: (context, index) {
        final config = _configs![index];
        return Card(
          child: ListTile(
            leading: const Icon(Icons.table_chart),
            title: Text(
              config.name.isNotEmpty ? config.name : '(名前なし)',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  'ID: ${config.id}',
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                  ),
                ),
                if (config.note.isNotEmpty) ...{
                  const SizedBox(height: 4),
                  Text(
                    config.note,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                },
                if (config.contentFolderId != null && config.contentFolderId!.isNotEmpty) ...{
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.folder, size: 14, color: Colors.blue),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'コンテンツフォルダ: ${config.contentFolderId}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.blue,
                            fontFamily: 'monospace',
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                },
              ],
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () => _returnSelectedConfig(config),
          ),
        );
      },
    );
  }
}
