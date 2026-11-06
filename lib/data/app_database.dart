import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Opens the WhereLog SQLite database.
///
/// Schema version 1 created ALL SIX tables from the settled schema
/// (see wherelog-schema-description.md) in one step, so any problem in
/// the schema surfaces early, while the database is still a scratch
/// file. Version 2 corrects one column: inventory_items.serial_number
/// becomes nullable (NULL = not recorded, consistent with brand/model;
/// v1 inherited the JSON shape's empty string — Rudy ruled there was no
/// rationale for two ways to say "no value").
/// Version 3 adds poi_items.source — where a place's coordinates
/// came from (an import origin or a direct-entry channel). A plain
/// nullable column added with ADD COLUMN, no rebuild; rows that
/// predate it read NULL (not recorded).
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const int schemaVersion = 3;

  /// The inventory_items definition, shared by onCreate and the v1→v2
  /// rebuild so the two can never drift apart.
  static String _createInventoryItemsSql(String table) => '''
    CREATE TABLE $table (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL,
      general_id INTEGER NOT NULL REFERENCES general_locations(id),
      specific_id INTEGER REFERENCES inventory_specifics(id),
      brand TEXT,
      model TEXT,
      serial_number TEXT,
      acquisition_date TEXT,
      quantity INTEGER NOT NULL DEFAULT 1,
      purchase_price_cents INTEGER,
      value_cents INTEGER,
      notes TEXT NOT NULL DEFAULT '',
      photo_filename TEXT,
      created_at TEXT NOT NULL,
      modified_at TEXT NOT NULL
    )
  ''';

  Database? _db;

  /// The database file's full path (shown on the About page).
  Future<String> databasePath() async {
    final dir = await getDatabasesPath();
    return p.join(dir, 'wherelog.db');
  }

  Future<Database> get database async {
    final existing = _db;
    if (existing != null) return existing;
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'wherelog.db');
    final db = await openDatabase(
      path,
      version: schemaVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        // Reference data first: every item table points at these.
        await db.execute('''
          CREATE TABLE general_locations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE storage_specifics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            general_id INTEGER NOT NULL REFERENCES general_locations(id),
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE inventory_specifics (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            general_id INTEGER NOT NULL REFERENCES general_locations(id),
            name TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE storage_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            general_id INTEGER NOT NULL REFERENCES general_locations(id),
            specific_id INTEGER REFERENCES storage_specifics(id),
            quantity INTEGER NOT NULL DEFAULT 1,
            value_cents INTEGER,
            notes TEXT NOT NULL DEFAULT '',
            photo_filename TEXT,
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL
          )
        ''');
        await db.execute(_createInventoryItemsSql('inventory_items'));
        await db.execute('''
          CREATE TABLE poi_items (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            address TEXT NOT NULL DEFAULT '',
            notes TEXT NOT NULL DEFAULT '',
            photo_filename TEXT,
            source TEXT,
            created_at TEXT NOT NULL,
            modified_at TEXT NOT NULL
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // v2: serial_number becomes nullable. SQLite cannot relax a
          // column in place, so the table is rebuilt and rows copied;
          // any stored empty-string serials become NULL on the way over
          // (NULLIF), so the corrected column holds one representation
          // of "no value" only. inventory_items is a leaf table (nothing
          // references it), so the drop is safe with foreign keys on.
          await db.execute(_createInventoryItemsSql('inventory_items_new'));
          await db.execute('''
            INSERT INTO inventory_items_new (id, name, general_id, specific_id, brand, model, serial_number, acquisition_date, quantity, purchase_price_cents, value_cents, notes, photo_filename, created_at, modified_at)
            SELECT id, name, general_id, specific_id, brand, model, NULLIF(serial_number, ''), acquisition_date, quantity, purchase_price_cents, value_cents, notes, photo_filename, created_at, modified_at FROM inventory_items
          ''');
          await db.execute('DROP TABLE inventory_items');
          await db.execute('ALTER TABLE inventory_items_new RENAME TO inventory_items');
        }
        if (oldVersion < 3) {
          await db.execute('ALTER TABLE poi_items ADD COLUMN source TEXT');
        }
      },
    );
    _db = db;
    return db;
  }
}
