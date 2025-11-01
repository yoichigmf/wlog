import 'package:flutter/material.dart';

/// ライセンス情報表示画面
class LicensesPage extends StatelessWidget {
  const LicensesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ライセンス情報'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // アプリ本体のライセンス
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'flog - 災害復旧ボランティアログアプリ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Copyright (c) 2025, flog contributors',
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'ライセンス: BSD 3-Clause License',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'このアプリケーションは、災害復旧・復興ボランティア活動を支援するために開発されました。',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // サードパーティライブラリ
          const Text(
            'サードパーティライブラリ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'このアプリケーションは以下のオープンソースライブラリを使用しています。',
            style: TextStyle(fontSize: 14, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // MIT License
          _buildLicenseCategory(
            'MIT License',
            [
              'drift - SQLiteデータベースORM',
              'geolocator - 位置情報取得',
              'file_picker - ファイル選択',
              'permission_handler - パーミッション管理',
              'record - 音声録音',
              'uuid - UUID生成',
              'cupertino_icons - iOSスタイルアイコン',
            ],
          ),
          const SizedBox(height: 16),

          // BSD 3-Clause License
          _buildLicenseCategory(
            'BSD 3-Clause License',
            [
              'Flutter SDK - アプリケーションフレームワーク',
              'Dart SDK - プログラミング言語',
              'intl - 国際化・日付フォーマット',
              'url_launcher - 外部URL起動',
              'path_provider - ディレクトリパス取得',
              'path - パス操作',
              'google_sign_in - Google認証',
              'googleapis - Google Sheets/Drive API',
              'shared_preferences - ローカル設定保存',
              'flutter_lints - コード品質チェック',
              'build_runner - コード生成',
            ],
          ),
          const SizedBox(height: 16),

          // BSD 2-Clause License
          _buildLicenseCategory(
            'BSD 2-Clause License',
            [
              'timezone - タイムゾーン処理',
            ],
          ),
          const SizedBox(height: 16),

          // Apache License 2.0
          _buildLicenseCategory(
            'Apache License 2.0',
            [
              'image_picker - 画像/動画の選択・撮影',
            ],
          ),
          const SizedBox(height: 16),

          // Flutterのライセンスボタン
          Card(
            child: ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Flutterフレームワークのライセンス'),
              subtitle: const Text('Flutter SDKおよび依存パッケージの詳細なライセンス情報'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                showLicensePage(
                  context: context,
                  applicationName: 'flog',
                  applicationVersion: '1.0.0',
                  applicationLegalese: 'Copyright (c) 2025, flog contributors\n'
                      'BSD 3-Clause License',
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // 詳細情報
          Card(
            color: Colors.blue.shade50,
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.info, color: Colors.blue),
                      SizedBox(width: 8),
                      Text(
                        '詳細なライセンス情報',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 8),
                  Text(
                    '各ライブラリの詳細なライセンス全文については、'
                    'プロジェクトルートの THIRD_PARTY_LICENSES.md ファイルをご参照ください。',
                    style: TextStyle(fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLicenseCategory(String license, List<String> libraries) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              license,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            ...libraries.map((lib) => Padding(
                  padding: const EdgeInsets.only(left: 16, top: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 14)),
                      Expanded(
                        child: Text(
                          lib,
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
