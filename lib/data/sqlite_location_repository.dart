import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_database.dart';
import 'location_records.dart';

/// SQLite-backed repository for the location tables (Generals and the
/// one Specific list per General). The first of the per-entity
/// repositories built during the migration from the old JSON store.
///
/// Version 4 (build 60) merged the two Specific lists into one:
/// a spot is a spot, whether the thing on it is stored or inventoried.
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

  Future<List<Specific>> getSpecifics() async {
    if (kIsWeb) return [];
    final db = await AppDatabase.instance.database;
    final rows = await db.query('specifics', orderBy: 'id ASC');
    return rows.map(Specific.fromMap).toList();
  }

  Future<bool> isDuplicateGeneral(String name) async {
    final lower = name.trim().toLowerCase();
    final generals = await getGenerals();
    return generals.any((g) => g.name.toLowerCase() == lower);
  }

  Future<bool> isDuplicateSpecific(int generalId, String name) async {
    final lower = name.trim().toLowerCase();
    final specifics = await getSpecifics();
    return specifics.any((s) => s.generalId == generalId && s.name.toLowerCase() == lower);
  }

  /// Returns the new row's id, or null on web.
  Future<int?> addGeneral(String name) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    return db.insert('general_locations', GeneralLocation(name: name.trim()).toMap());
  }

  Future<int?> addSpecific(int generalId, String name) async {
    if (kIsWeb) return null;
    final db = await AppDatabase.instance.database;
    return db.insert('specifics', Specific(generalId: generalId, name: name.trim()).toMap());
  }

  Future<void> renameGeneral(int id, String name) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update('general_locations', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> renameSpecific(int id, String name) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.update('specifics', {'name': name.trim()}, where: 'id = ?', whereArgs: [id]);
  }

  /// The foreign key refuses this delete while Specifics still reference
  /// the General; the screen checks first and explains, as it always has.
  Future<void> deleteGeneral(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('general_locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteSpecific(int id) async {
    if (kIsWeb) return;
    final db = await AppDatabase.instance.database;
    await db.delete('specifics', where: 'id = ?', whereArgs: [id]);
  }
}
