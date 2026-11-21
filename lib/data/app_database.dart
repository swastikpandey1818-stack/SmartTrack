import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../domain/models.dart';

class AppDatabase {
  Database? _db;

  Future<Database> get _database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'smart_track.db');
    return openDatabase(
      path,
      version: 1,
      onCreate: (db, v) async {
        await db.execute('''CREATE TABLE readings(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts INTEGER NOT NULL, moisture INTEGER NOT NULL,
          tank INTEGER NOT NULL, distance REAL NOT NULL, pump INTEGER NOT NULL)''');
        await db.execute('CREATE INDEX idx_readings_ts ON readings(ts)');
        await db.execute('''CREATE TABLE events(
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          ts INTEGER NOT NULL, kind TEXT NOT NULL, type TEXT NOT NULL,
          title TEXT NOT NULL, detail TEXT NOT NULL,
          severity INTEGER NOT NULL, dismissed INTEGER NOT NULL DEFAULT 0)''');
        await db.execute('CREATE INDEX idx_events_ts ON events(ts)');
      },
    );
  }

  Future<void> insertReading(DateTime t, SensorStatus s) async {
    final db = await _database;
    await db.insert('readings', {
      'ts': t.millisecondsSinceEpoch,
      'moisture': s.moisture,
      'tank': s.tank,
      'distance': s.distance,
      'pump': s.pump ? 1 : 0,
    });
  }

  Future<List<Reading>> readingsSince(DateTime since) async {
    final db = await _database;
    final rows = await db.query('readings',
        where: 'ts >= ?',
        whereArgs: [since.millisecondsSinceEpoch],
        orderBy: 'ts ASC');
    return [
      for (final r in rows)
        Reading(
          DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
          r['moisture'] as int,
          r['tank'] as int,
          (r['pump'] as int) == 1,
        ),
    ];
  }

  Future<int> insertEvent({
    required DateTime time,
    required String kind,
    required String type,
    required String title,
    required String detail,
    required int severity,
  }) async {
    final db = await _database;
    return db.insert('events', {
      'ts': time.millisecondsSinceEpoch,
      'kind': kind,
      'type': type,
      'title': title,
      'detail': detail,
      'severity': severity,
      'dismissed': 0,
    });
  }

  EventRecord _event(Map<String, Object?> r) => EventRecord(
        id: r['id'] as int,
        time: DateTime.fromMillisecondsSinceEpoch(r['ts'] as int),
        kind: r['kind'] as String,
        type: r['type'] as String,
        title: r['title'] as String,
        detail: r['detail'] as String,
        severity: r['severity'] as int,
      );

  Future<List<EventRecord>> history({int limit = 300}) async {
    final db = await _database;
    final rows = await db.query('events', orderBy: 'ts DESC', limit: limit);
    return rows.map(_event).toList();
  }

  Future<List<EventRecord>> activeAlerts({int limit = 100}) async {
    final db = await _database;
    final rows = await db.query('events',
        where: "kind = 'alert' AND dismissed = 0", orderBy: 'ts DESC', limit: limit);
    return rows.map(_event).toList();
  }

  Future<void> dismissAlerts() async {
    final db = await _database;
    await db.update('events', {'dismissed': 1}, where: "kind = 'alert'");
  }

  /// Keeps the database small: 30 days of readings, 90 days of events.
  Future<void> prune() async {
    final db = await _database;
    final now = DateTime.now();
    await db.delete('readings',
        where: 'ts < ?',
        whereArgs: [now.subtract(const Duration(days: 30)).millisecondsSinceEpoch]);
    await db.delete('events',
        where: 'ts < ?',
        whereArgs: [now.subtract(const Duration(days: 90)).millisecondsSinceEpoch]);
  }

  Future<void> clearAll() async {
    final db = await _database;
    await db.delete('readings');
    await db.delete('events');
  }
}
