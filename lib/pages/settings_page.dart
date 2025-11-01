import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/google_auth_service.dart';
import '../services/sheets_upload_service.dart';
import '../data/database.dart';
import 'database_debug_page.dart';
import 'licenses_page.dart';
import 'spreadsheet_config_selector_page.dart';

/// 設定画面
class SettingsPage extends StatefulWidget {
  final AppDatabase? database;

  const SettingsPage({super.key, this.database});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TextEditingController _spreadsheetIdController =
      TextEditingController();
  bool _isSignedIn = false;
  String? _userEmail;
  String? _spreadsheetTitle;
  bool _isLoading = false;
  bool _autoUploadEnabled = false;

  static const String _spreadsheetIdKey = 'spreadsheet_id';
  static const String _autoUploadKey = 'auto_upload_enabled';

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _checkSignInStatus();
  }

  @override
  void dispose() {
    _spreadsheetIdController.dispose();
    super.dispose();
  }

  /// 設定を読み込む
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final spreadsheetId = prefs.getString(_spreadsheetIdKey);
    if (spreadsheetId != null) {
      _spreadsheetIdController.text = spreadsheetId;
      _loadSpreadsheetTitle(spreadsheetId);
    }
    setState(() {
      _autoUploadEnabled = prefs.getBool(_autoUploadKey) ?? false;
    });
  }

  /// サインイン状態を確認
  Future<void> _checkSignInStatus() async {
    // Windows/Linux版の場合は非同期で確認
    final isSignedIn = await GoogleAuthService.checkDesktopSignInStatus();
    final userEmail = await GoogleAuthService.getUserEmail();

    setState(() {
      _isSignedIn = isSignedIn;
      _userEmail = userEmail;
    });
  }

  /// Spreadsheetのタイトルを読み込む
  Future<void> _loadSpreadsheetTitle(String spreadsheetId) async {
    if (spreadsheetId.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final title =
          await SheetsUploadService.getSpreadsheetTitle(spreadsheetId);
      setState(() {
        _spreadsheetTitle = title;
      });
    } catch (e) {
      // エラーは無視（認証されていない場合など）
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Spreadsheet IDを保存
  Future<void> _saveSettings() async {
    final spreadsheetId = _spreadsheetIdController.text.trim();

    if (spreadsheetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Spreadsheet IDを入力してください')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Spreadsheetが存在するか確認
      final spreadsheetExists =
          await SheetsUploadService.checkSpreadsheetExists(spreadsheetId);

      if (!spreadsheetExists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Spreadsheetが見つかりません。IDを確認してください'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // 保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_spreadsheetIdKey, spreadsheetId);
      await prefs.setBool(_autoUploadKey, _autoUploadEnabled);

      // タイトルを読み込む
      await _loadSpreadsheetTitle(spreadsheetId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('設定を保存しました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('エラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Googleサインイン
  Future<void> _signIn() async {
    setState(() => _isLoading = true);
    try {
      final account = await GoogleAuthService.signIn();

      // Windows/Linuxの場合はaccountがnullなので、再度状態確認が必要
      if (account != null) {
        // モバイル版: アカウント情報を直接使用
        setState(() {
          _isSignedIn = true;
          _userEmail = account.email;
        });
      } else {
        // デスクトップ版: サインイン後に状態を確認
        await _checkSignInStatus();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('サインインしました'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('サインインエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// Googleサインアウト
  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    try {
      await GoogleAuthService.signOut();
      setState(() {
        _isSignedIn = false;
        _userEmail = null;
        _spreadsheetTitle = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('サインアウトしました'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('サインアウトエラー: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  /// スプレッドシート設定選択画面を開く
  Future<void> _openConfigSelector() async {
    final selectedId = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (context) => const SpreadsheetConfigSelectorPage(),
      ),
    );

    if (selectedId != null && selectedId.isNotEmpty) {
      _spreadsheetIdController.text = selectedId;
      await _loadSpreadsheetTitle(selectedId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('設定'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Google認証セクション
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Google認証',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_isSignedIn) ...[
                          ListTile(
                            leading: const Icon(Icons.account_circle),
                            title: const Text('サインイン中'),
                            subtitle: Text(_userEmail ?? ''),
                          ),
                          const SizedBox(height: 8),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _signOut,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.grey,
                              ),
                              child: const Text('サインアウト'),
                            ),
                          ),
                        ] else ...[
                          const Text(
                            'Google SheetsにアップロードするにはGoogleアカウントでサインインしてください',
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _signIn,
                              icon: const Icon(Icons.login),
                              label: const Text('Googleでサインイン'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Spreadsheet設定セクション
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Spreadsheet設定',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _spreadsheetIdController,
                          decoration: const InputDecoration(
                            labelText: 'Spreadsheet ID',
                            hintText:
                                '1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgvE2upms',
                            helperText:
                                'SpreadsheetのURLから「/d/」と「/edit」の間の文字列\n'
                                '例: https://docs.google.com/spreadsheets/d/【ここ】/edit',
                            helperMaxLines: 3,
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 2,
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSignedIn ? _openConfigSelector : null,
                            icon: const Icon(Icons.list),
                            label: const Text('登録済み設定から選択'),
                          ),
                        ),
                        if (_spreadsheetTitle != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            '📄 $_spreadsheetTitle',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        // 自動アップロード設定
                        SwitchListTile(
                          title: const Text('ログ登録時に自動アップロード'),
                          subtitle: const Text(
                            'ログを1件登録するごとに即座にSpreadsheetにアップロードします\n'
                            '※ネットワークエラー時は自動的に手動モードに切り替わります',
                          ),
                          value: _autoUploadEnabled,
                          onChanged: _isSignedIn
                              ? (value) {
                                  setState(() {
                                    _autoUploadEnabled = value;
                                  });
                                }
                              : null,
                          secondary: const Icon(Icons.cloud_upload),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSignedIn ? _saveSettings : null,
                            icon: const Icon(Icons.save),
                            label: const Text('保存'),
                          ),
                        ),
                        if (!_isSignedIn) ...[
                          const SizedBox(height: 8),
                          const Text(
                            '※ 設定を保存するには先にサインインしてください',
                            style: TextStyle(
                              color: Colors.orange,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 使い方
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '使い方',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Googleアカウントでサインイン\n'
                          '2. Google Driveで新しいフォルダを作成\n'
                          '3. そのフォルダ内にGoogle Sheetsで新しいSpreadsheetを作成\n'
                          '4. SpreadsheetのURLから「/d/」と「/edit」の間の文字列をコピーして「Spreadsheet ID」欄にペースト\n'
                          '5. 保存ボタンをクリック\n'
                          '6. ログ一覧画面からアップロード\n\n'
                          '※ ファイルは自動的にSpreadsheetと同じフォルダ内の「files」フォルダにアップロードされます',
                          style: TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // アプリ情報
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'アプリ情報',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: const Text('ライセンス情報'),
                          subtitle: const Text('使用しているライブラリのライセンス'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const LicensesPage(),
                              ),
                            );
                          },
                        ),
                        const Divider(),
                        const ListTile(
                          leading: Icon(Icons.copyright),
                          title: Text('flog'),
                          subtitle: Text('災害復旧ボランティアログアプリ\n'
                              'Version 1.0.0\n'
                              'Copyright (c) 2025, flog contributors\n'
                              'BSD 3-Clause License'),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 開発者向け
                if (widget.database != null)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '開発者向け',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            leading: const Icon(Icons.bug_report),
                            title: const Text('データベースデバッグ'),
                            subtitle: const Text('データベースの内容を表示'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => DatabaseDebugPage(
                                    database: widget.database!,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // アプリ終了ボタン
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('アプリを終了'),
                              content: const Text('アプリケーションを終了しますか?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text('キャンセル'),
                                ),
                                TextButton(
                                  onPressed: () {
                                    if (Platform.isAndroid) {
                                      SystemNavigator.pop();
                                    } else {
                                      exit(0);
                                    }
                                  },
                                  child: const Text('終了'),
                                ),
                              ],
                            ),
                          );
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text('アプリを終了'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
