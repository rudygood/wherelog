import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'inventory_records.dart';

/// SQLite-backed repository for the inventory_items table.
///
/// Same boundary duties as the storage repository: system stamps are
/// written here, in UTC ISO-8601 with the Z marker, and money crosses
/// the boundary only as integer cents. Acquisition dates arrive
/// date-only (YYYY-MM-DD) from the screens and are stored as given.
/// On web every operation is a no-op returning empty results.
class SqliteInventoryRepository {
  SqliteInventoryRepository._();
  static final SqliteInventoryRepository instance = SqliteInventoryRepository._();

  String _nowUtc() => DateTime.now().toUtc().toIso8601String();

  Future<List<InventoryItem>> getAll() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inventory_items', orderBy: 'id ASC');
    return rows.map(InventoryItem.fromMap).toList();
  }

  Future<InventoryItem?> getById(int id) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inventory_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return InventoryItem.fromMap(rows.first);
  }

  /// Inserts the item with fresh stamps. Returns the new row's id, or
  /// null on web.
  Future<int?> add(InventoryItem item) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    final now = _nowUtc();
    map['created_at'] = now;
    map['modified_at'] = now;
    return db.insert('inventory_items', map);
  }

  Future<void> update(InventoryItem item) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    map['modified_at'] = _nowUtc();
    await db.update('inventory_items', map, where: 'id = ?', whereArgs: [item.id]);
  }

  /// The move flow: repoint an item at a (possibly different) General
  /// and Specific. A null specificId means "General only".
  Future<void> updateLocation(int id, int generalId, int? specificId) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update(
      'inventory_items',
      {'general_id': generalId, 'specific_id': specificId, 'modified_at': _nowUtc()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> delete(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMany(List<int> ids) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    for (final id in ids) {
      await db.delete('inventory_items', where: 'id = ?', whereArgs: [id]);
    }
  }

  Future<int> countForGeneral(int generalId) async {
    if (kIsWeb) return 0;
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM inventory_items WHERE general_id = ?', [generalId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> countForSpecific(int specificId) async {
    if (kIsWeb) return 0;
    final db = await AppDatabase.instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM inventory_items WHERE specific_id = ?', [specificId]);
    return Sqflite.firstIntValue(result) ?? 0;
  }
}
