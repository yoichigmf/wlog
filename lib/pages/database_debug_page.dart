import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/database.dart';

/// データベースデバッグ画面
class DatabaseDebugPage extends StatefulWidget {
  final AppDatabase database;

  const DatabaseDebugPage({super.key, required this.database});

  @override
  State<DatabaseDebugPage> createState() => _DatabaseDebugPageState();
}

class _DatabaseDebugPageState extends State<DatabaseDebugPage> {
  List<ActivityLog> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllLogs();
  }

  Future<void> _loadAllLogs() async {
    setState(() => _isLoading = true);
    try {
      final logs = await widget.database.getAllLogs();
      if (mounted) {
        setState(() {
          _logs = logs;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('エラー: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('データベースデバッグ'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAllLogs,
            tooltip: '再読み込み',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _logs.isEmpty
              ? const Center(
                  child: Text(
                    'データベースにログがありません',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    // 統計情報
                    Container(
                      padding: const EdgeInsets.all(16),
                      color: Colors.grey[200],
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '統計情報',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatCard(
                                '総レコード数',
                                '${_logs.length}',
                                Icons.storage,
                              ),
                              _buildStatCard(
                                'アップロード済み',
                                '${_logs.where((log) => log.uploadedAt != null).length}',
                                Icons.cloud_done,
                              ),
                              _buildStatCard(
                                '未アップロード',
                                '${_logs.where((log) => log.uploadedAt == null).length}',
                                Icons.cloud_upload,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    // テーブルヘッダー
                    Container(
                      color: Colors.blue[100],
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          headingRowHeight: 40,
                          dataRowMinHeight: 30,
                          dataRowMaxHeight: 60,
                          columnSpacing: 16,
                          columns: const [
                            DataColumn(label: Text('UUID', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('登録日時', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('テキスト', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('メディア', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('ファイル名', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('緯度', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('経度', style: TextStyle(fontWeight: FontWeight.bold))),
                            DataColumn(label: Text('アップロード日時', style: TextStyle(fontWeight: FontWeight.bold))),
                          ],
                          rows: [],
                        ),
                      ),
                    ),
                    // テーブルデータ
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            dataRowMinHeight: 30,
                            dataRowMaxHeight: 60,
                            columnSpacing: 16,
                            columns: const [
                              DataColumn(label: Text('UUID')),
                              DataColumn(label: Text('登録日時')),
                              DataColumn(label: Text('テキスト')),
                              DataColumn(label: Text('メディア')),
                              DataColumn(label: Text('ファイル名')),
                              DataColumn(label: Text('緯度')),
                              DataColumn(label: Text('経度')),
                              DataColumn(label: Text('アップロード日時')),
                            ],
                            rows: _logs.map((log) => _buildDataRow(log)).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon, size: 24, color: Colors.blue),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  DataRow _buildDataRow(ActivityLog log) {
    final dateFormat = DateFormat('yyyy-MM-dd HH:mm:ss');

    return DataRow(
      cells: [
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              log.uuid ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 140,
            child: Text(
              dateFormat.format(log.createdAt.toLocal()),
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 200,
            child: Text(
              log.textContent ?? '',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ),
        DataCell(
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getMediaTypeColor(log.mediaType),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              log.mediaType ?? 'text',
              style: const TextStyle(fontSize: 11, color: Colors.white),
            ),
          ),
        ),
        DataCell(
          SizedBox(
            width: 150,
            child: Text(
              log.fileName ?? '-',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        DataCell(
          Text(
            log.latitude?.toStringAsFixed(6) ?? '-',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          Text(
            log.longitude?.toStringAsFixed(6) ?? '-',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        DataCell(
          SizedBox(
            width: 140,
            child: log.uploadedAt != null
                ? Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        dateFormat.format(log.uploadedAt!),
                        style: const TextStyle(fontSize: 11, color: Colors.green),
                      ),
                      const Icon(Icons.cloud_done, size: 12, color: Colors.green),
                    ],
                  )
                : const Row(
                    children: [
                      Icon(Icons.cloud_upload, size: 12, color: Colors.orange),
                      SizedBox(width: 4),
                      Text(
                        '未アップロード',
                        style: TextStyle(fontSize: 11, color: Colors.orange),
                      ),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  Color _getMediaTypeColor(String? mediaType) {
    if (mediaType == null) return Colors.blue;
    switch (mediaType) {
      case 'audio':
        return Colors.orange;
      case 'image':
        return Colors.green;
      case 'video':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
}
