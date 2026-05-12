// lib/data/repositories/sensor_buffer_repository.dart
// SQLite-backed implementation of ISensorBufferRepository.
// Uses sqflite. Opened lazily on first access (singleton via locator).

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;

import '../../domain/entities/sensor_packet.dart';
import '../../domain/repositories/i_sensor_buffer_repository.dart';

class SensorBufferRepository implements ISensorBufferRepository {
  static const _dbName = 'sensor_bridge.db';
  static const _table = 'packets';

  Database? _db;

  Future<Database> _getDb() async {
    if (_db != null) return _db!;
    final path = p.join(await getDatabasesPath(), _dbName);
    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, _) async {
        await db.execute('''
          CREATE TABLE $_table (
            id          TEXT PRIMARY KEY,
            timestamp   INTEGER NOT NULL,
            ax          REAL    NOT NULL,
            ay          REAL    NOT NULL,
            az          REAL    NOT NULL,
            transmitted INTEGER NOT NULL DEFAULT 0
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_transmitted ON $_table (transmitted)');
      },
    );
    return _db!;
  }

  @override
  Future<void> save(SensorPacket packet) async {
    final db = await _getDb();
    await db.insert(
      _table,
      packet.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<List<SensorPacket>> getPending() async {
    final db = await _getDb();
    final rows = await db.query(
      _table,
      where: 'transmitted = 0',
      orderBy: 'timestamp ASC',
      limit: 200, // safety cap per flush cycle
    );
    return rows.map(SensorPacket.fromMap).toList();
  }

  @override
  Future<void> markTransmitted(List<String> ids) async {
    if (ids.isEmpty) return;
    final db = await _getDb();
    final placeholders = List.filled(ids.length, '?').join(',');
    await db.rawUpdate(
      'UPDATE $_table SET transmitted = 1 WHERE id IN ($placeholders)',
      ids,
    );
  }

  @override
  Future<void> pruneTransmitted() async {
    final db = await _getDb();
    await db.delete(_table, where: 'transmitted = 1');
  }

  @override
  Future<int> pendingCount() async {
    final db = await _getDb();
    final result = await db.rawQuery(
        'SELECT COUNT(*) as cnt FROM $_table WHERE transmitted = 0');
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
