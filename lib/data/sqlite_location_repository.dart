import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_database.dart';
import 'location_records.dart';

/// SQLite-backed repository for the location tables (Generals and the two
/// Specifics lists). The first of the per-entity repositories built
/// during the migration from the old JSON store.
///
/// Semantics deliberately match the old repository's location behaviour:
/// names are trimmed by callers, duplicate checks are case-insensitive,
/// and on web every operation is a no-op returning empty results.
class SqliteLocationRepository {
  SqliteLocationRepository._();
  static final SqliteLocationRepository instance = SqliteLocationRepository._();

  Future<List<GeneralLocation>> getGenerals() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('general_locations', orderBy: 'id ASC');
    return rows.map(GeneralLocation.fromMap).toList();
  }

  Future<List<StorageSpecific>> getStorageSpecifics() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('storage_specifics', orderBy: 'id ASC');
    return rows.map(StorageSpecific.fromMap).toList();
  }

  Future<List<InventorySpecific>> getInventorySpecifics() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('inventory_specifics', orderBy: 'id ASC');
    return rows.map(InventorySpecific.fromMap).toList();
  }

  Future<bool> isDuplicateGeneral(String name) async {
    final lower = name.trim().toLowerCase();
    final generals = await getGenerals();
    return generals.any((g) => g.name.toLowerCase() == lower);
  }

  Future<bool> isDuplicateStorageSpecific(int generalId, String name) async {
    final lower = name.trim().toLowerCase();
    final specifics = await getStorageSpecifics();
    return specifics.any((s) => s.generalId == generalId && s.name.toLowerCase() == lower);
  }

  Future<bool> isDuplicateInventorySpecific(int generalId, String name) async {
    final lower = name.trim().toLowerCase();
    final specifics = await getInventorySpecifics();
    return specifics.any((s) => s.generalId == generalId && s.name.toLowerCase() == lower);
  }

  /// Returns the new row's id, or null on web.
  Future<int?> addGeneral(String name) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    return db.insert('general_locations', GeneralLocation(name: name.trim()).toMap());
  }

  Future<int?> addStorageSpecific(int generalId, String name) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    return db.insert('storage_specifics', StorageSpecific(generalId: generalId, name: name.trim()).toMap());
  }

  Future<int?> addInventorySpecific(int generalId, String name) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    return db.insert('inventory_specifics', InventorySpecific(generalId: generalId, name: name.trim()).toMap());
  }

  Future<void> renameGeneral(int id, String name) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update('general_locations', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameStorageSpecific(int id, String name) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update('storage_specifics', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameInventorySpecific(int id, String name) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update('inventory_specifics', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  /// The foreign key refuses this delete while Specifics still reference
  /// the General; the screen checks first and explains, as it always has.
  Future<void> deleteGeneral(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('general_locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteStorageSpecific(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('storage_specifics', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteInventorySpecific(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('inventory_specifics', where: 'id = ?', whereArgs: [id]);
  }
}
