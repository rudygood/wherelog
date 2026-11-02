import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'storage_records.dart';

/// SQLite-backed repository for the storage_items table.
///
/// Boundary duties (settled in the schema): the system stamps are written
/// here, in UTC ISO-8601 with the Z marker — created on insert, modified
/// refreshed on every update — and the database only ever sees integer
/// cents for money. On web every operation is a no-op returning empty
/// results, mirroring the location repository.
class SqliteStorageRepository {
  SqliteStorageRepository._();
  static final SqliteStorageRepository instance = SqliteStorageRepository._();

  String _nowUtc() => DateTime.now().toUtc().toIso8601String();

  Future<List<StorageItem>> getAll() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('storage_items', orderBy: 'id ASC');
    return rows.map(StorageItem.fromMap).toList();
  }

  Future<StorageItem?> getById(int id) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('storage_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return StorageItem.fromMap(rows.first);
  }

  /// Inserts the item with fresh stamps. Returns the new row's id, or
  /// null on web.
  Future<int?> add(StorageItem item) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    final now = _nowUtc();
    map['created_at'] = now;
    map['modified_at'] = now;
    return db.insert('storage_items', map);
  }

  /// Writes the item back, preserving its created stamp and refreshing
  /// the modified stamp.
  Future<void> update(StorageItem item) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    map['modified_at'] = _nowUtc();
    await db.update('storage_items', map, where: 'id = ?', whereArgs: [item.id]);
  }

  /// The move flow: repoint an item at a (possibly different) General and
  /// Specific. A null specificId means "General only".
  Future<void> updateLocation(int id, int generalId, int? specificId) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update(
      'storage_items',
      {'general_id': generalId, 'specific_id': specificId, 'modified_at': _nowUtc()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('storage_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMany(List<int> ids) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    for (final id in ids) {
      await db.delete('storage_items', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> countForGeneral(int generalId) async {
    if (kIsWeb) return 0;
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM storage_items WHERE general_id = ?', [generalId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countForSpecific(int specificId) async {
    if (kIsWeb) return 0;
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM storage_items WHERE specific_id = ?', [specificId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
