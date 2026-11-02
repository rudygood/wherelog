import 'package:flutter/foundation.dart' show kIsWeb;

import 'app_database.dart';

/// Read-only database access for the hidden inspector screen.
///
/// This is the one place raw SQL exists in the app, and it only runs
/// SELECTs: the statement must start with SELECT, must be a single
/// statement, and must not contain a write keyword. Table browsing goes
/// through the same door. Rows are capped so a big table can't flood
/// the screen.
class DbInspector {
  DbInspector._();
  static final DbInspector instance = DbInspector._();

  static const List<String> tables = [
    'general_locations',
    'storage_specifics',
    'inventory_specifics',
    'storage_items',
    'inventory_items',
    'poi_items',
  ];

  static const int rowCap = 200;

  static const List<String> _banned = [
    'insert', 'update', 'delete', 'drop', 'alter', 'create', 'replace',
    'pragma', 'attach', 'detach', 'vacuum', 'reindex', 'truncate',
  ];

  /// Runs one read-only SELECT and returns up to [rowCap] rows.
  /// Throws a FormatException with a user-readable reason when the
  /// statement is refused; database errors surface as-is.
  Future<List<Map<String, Object?>>> runSelect(String sql) async {
    if (kIsWeb) return [];
    var body = sql.trim();
    if (body.endsWith(';')) body = body.substring(0, body.length - 1).trim();
    if (body.contains(';')) {
      throw const FormatException('One statement at a time.');
    }
    if (!RegExp(r'^select\b', caseSensitive: false).hasMatch(body)) {
      throw const FormatException('Read-only: only SELECT statements are allowed.');
    }
    final lower = body.toLowerCase();
    for (final w in _banned) {
      // Word boundaries, so columns like created_at are not false hits.
      if (RegExp('\\b$w\\b').hasMatch(lower)) {
        throw FormatException('Read-only: "$w" is not allowed.');
      }
    }
    final db = await AppDatabase.instance.database;
    final rows = await db.rawQuery(body);
    return rows.take(rowCap).map((r) => Map<String, Object?>.from(r)).toList();
  }

  Future<List<Map<String, Object?>>> browse(String table) {
    if (!tables.contains(table)) {
      throw ArgumentError('Unknown table: $table');
    }
    return runSelect('SELECT * FROM $table ORDER BY id');
  }

  Future<int> countRows(String table) async {
    if (kIsWeb) return 0;
    if (!tables.contains(table)) return 0;
    final rows = await runSelect('SELECT COUNT(*) AS c FROM $table');
    if (rows.isEmpty) return 0;
    final c = rows.first['c'];
    return c is int ? c : int.tryParse('$c') ?? 0;
  }
}
