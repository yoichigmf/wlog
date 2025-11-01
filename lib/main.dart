import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'data/database.dart';
import 'pages/log_list_page.dart';

void main() async {
  // Flutterバインディングの初期化（環境変数読み込み前に必要）
  WidgetsFlutterBinding.ensureInitialized();

  // 環境変数を読み込む
  await dotenv.load(fileName: ".env");

  // タイムゾーンデータベースを初期化
  tz.initializeTimeZones();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AppDatabase database;

  @override
  void initState() {
    super.initState();
    database = AppDatabase();
  }

  @override
  void dispose() {
    database.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '活動ログアプリ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: LogListPage(database: database),
    );
  }
}
