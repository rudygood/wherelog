import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_database.dart';
import 'poi_records.dart';

/// SQLite-backed repository for the poi_items table.
///
/// Same boundary duties as the other repositories: system stamps are
/// written here, in UTC ISO-8601 with the Z marker. On web every
/// operation is a no-op returning empty results.
class SqlitePoiRepository {
  SqlitePoiRepository._();
  static final SqlitePoiRepository instance = SqlitePoiRepository._();

  String _nowUtc() => DateTime.now().toUtc().toIso8601String();

  Future<List<PoiItem>> getAll() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('poi_items', orderBy: 'id ASC');
    return rows.map(PoiItem.fromMap).toList();
  }

  Future<PoiItem?> getById(int id) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final rows = await db.query('poi_items', where: 'id = ?', whereArgs: [id], limit: 1);
    if (rows.isEmpty) return null;
    return PoiItem.fromMap(rows.first);
  }

  /// Inserts the place with fresh stamps. Returns the new row's id, or
  /// null on web.
  Future<int?> add(PoiItem item) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    final now = _nowUtc();
    map['created_at'] = now;
    map['modified_at'] = now;
    return db.insert('poi_items', map);
  }

  Future<void> update(PoiItem item) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    final map = item.toMap();
    map['modified_at'] = _nowUtc();
    await db.update('poi_items', map, where: 'id = ?', whereArgs: [item.id]);
  }

  Future<void> delete(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('poi_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteMany(List<int> ids) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    for (final id in ids) {
      await db.delete('poi_items', where: 'id = ?', whereArgs: [id]);
    }
  }
}
