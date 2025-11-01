import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:uuid/uuid.dart';

part 'database.g.dart';

// メディアタイプを定義
enum MediaType {
  audio,
  image,
  video,
}

// 活動ログテーブル
class ActivityLogs extends Table {
  // 主キー
  IntColumn get id => integer().autoIncrement()();

  // UUID（ログの一意識別子、アップロード時のキーとして使用）
  TextColumn get uuid => text().nullable().withDefault(const Constant(''))();

  // テキストコンテンツ（すべてのログで使用可能）
  TextColumn get textContent => text().nullable()();

  // メディアタイプ（audio, image, video、メディアがない場合はnull）
  TextColumn get mediaType => text().nullable()();

  // メディアファイル名（メディアがある場合のみ）
  TextColumn get fileName => text().nullable()();

  // 緯度
  RealColumn get latitude => real().nullable()();

  // 経度
  RealColumn get longitude => real().nullable()();

  // 登録時刻
  DateTimeColumn get createdAt => dateTime()();

  // アップロード日時（アップロードされていない場合はnull）
  DateTimeColumn get uploadedAt => dateTime().nullable()();
}

// データベースクラス
@DriftDatabase(tables: [ActivityLogs])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 4;

  // スキーマ変更時のマイグレーション処理
  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onCreate: (Migrator m) async {
        await m.createAll();
      },
      onUpgrade: (Migrator m, int from, int to) async {
        if (from < 2) {
          // バージョン2へのマイグレーション：既存データをクリア
          await m.deleteTable('activity_logs');
          await m.createTable(activityLogs);
        }
        if (from < 3) {
          // バージョン3へのマイグレーション：uploadedAtカラムを追加
          await m.addColumn(activityLogs, activityLogs.uploadedAt);
        }
        if (from < 4) {
          // バージョン4へのマイグレーション：uuidカラムを追加
          // ステップ1: nullable TEXT として追加
          await customStatement(
            'ALTER TABLE activity_logs ADD COLUMN uuid TEXT',
          );

          // ステップ2: 既存レコードにUUIDを生成して設定
          final existingLogs = await customSelect(
            'SELECT id FROM activity_logs',
            readsFrom: {activityLogs},
          ).get();

          const uuidGenerator = Uuid();
          for (final row in existingLogs) {
            final id = row.read<int>('id');
            await customUpdate(
              'UPDATE activity_logs SET uuid = ? WHERE id = ?',
              updates: {activityLogs},
              variables: [Variable<String>(uuidGenerator.v4()), Variable<int>(id)],
            );
          }
        }
      },
    );
  }

  // ログを追加
  Future<int> addLog({
    String? textContent,
    MediaType? mediaType,
    String? fileName,
    double? latitude,
    double? longitude,
  }) {
    const uuidGenerator = Uuid();
    return into(activityLogs).insert(
      ActivityLogsCompanion.insert(
        uuid: Value(uuidGenerator.v4()),
        textContent: Value(textContent),
        mediaType: Value(mediaType?.name),
        fileName: Value(fileName),
        latitude: Value(latitude),
        longitude: Value(longitude),
        createdAt: DateTime.now(),
      ),
    );
  }

  // すべてのログを取得（新しい順）
  Future<List<ActivityLog>> getAllLogs() {
    return (select(activityLogs)
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // IDでログを取得
  Future<ActivityLog?> getLogById(int id) {
    return (select(activityLogs)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  // ログを削除
  Future<int> deleteLog(int id) {
    return (delete(activityLogs)..where((t) => t.id.equals(id))).go();
  }

  // 特定のメディアタイプのログを取得
  Future<List<ActivityLog>> getLogsByMediaType(MediaType type) {
    return (select(activityLogs)
          ..where((t) => t.mediaType.equals(type.name))
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // テキストのみのログを取得
  Future<List<ActivityLog>> getTextOnlyLogs() {
    return (select(activityLogs)
          ..where((t) => t.mediaType.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // ログを更新
  Future<bool> updateLog(ActivityLog log) {
    return update(activityLogs).replace(log);
  }

  // ログのアップロード日時を更新
  Future<int> markAsUploaded(int id) {
    return (update(activityLogs)..where((t) => t.id.equals(id))).write(
      ActivityLogsCompanion(
        uploadedAt: Value(DateTime.now()),
      ),
    );
  }

  // 未アップロードのログを取得
  Future<List<ActivityLog>> getUnuploadedLogs() {
    return (select(activityLogs)
          ..where((t) => t.uploadedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm(expression: t.createdAt, mode: OrderingMode.desc)
          ]))
        .get();
  }

  // アップロード済みのログを取得
  Future<List<ActivityLog>> getUploadedLogs() {
    return (select(activityLogs)
          ..where((t) => t.uploadedAt.isNotNull())
          ..orderBy([
            (t) =>
                OrderingTerm(expression: t.uploadedAt, mode: OrderingMode.desc)
          ]))
        .get();
  }
}

// データベース接続を開く
QueryExecutor _openConnection() {
  if (kIsWeb) {
    // Web版: WASMの問題を回避するため、インメモリデータベースを使用
    // 注: ページをリロードするとデータは失われます
    // 永続化が必要な場合は、IndexedDBを直接使用するか、別のストレージソリューションが必要
    return driftDatabase(
      name: 'activity_logs_db',
      web: DriftWebOptions(
        // WASMを使用せず、IndexedDBのみを使用
        sqlite3Wasm: Uri.parse('sqlite3.wasm'),
        driftWorker: Uri.parse('drift_worker.js'),
      ),
    );
  } else {
    // ネイティブ版: 通常のファイルベースのデータベース
    return driftDatabase(name: 'activity_logs_db');
  }
}
