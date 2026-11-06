import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'app_database.dart';
import 'photo_store.dart';

/// Record counts, for the Export/Import screen's counts box and the
/// backup viewer's comparison header.
class DataCounts {
  final int generals;
  final int storageSpecifics;
  final int inventorySpecifics;
  final int storageItems;
  final int inventoryItems;
  final int poiItems;
  final int imagesLinked;

  const DataCounts({
    required this.generals,
    required this.storageSpecifics,
    required this.inventorySpecifics,
    required this.storageItems,
    required this.inventoryItems,
    required this.poiItems,
    required this.imagesLinked,
  });
}

/// A backup file that has been picked, decoded and validated. The
/// Export/Import screen holds ONE selection and shares it between the
/// viewer and the restore, so the user never re-picks a look-alike
/// timestamped file at restore time — and the file on disk cannot
/// change between evaluation and restore, because the restore runs
/// from this held document, not from a second read.
class BackupSelection {
  final String fileName;
  final Map<String, dynamic> document;

  /// The decoded ZIP, when the pick was a ZIP. Kept so the restore can
  /// extract the photo files without re-reading the file from disk.
  final Archive? archive;

  const BackupSelection({
    required this.fileName,
    required this.document,
    this.archive,
  });

  int get formatVersion => document['version'] as int;

  DateTime? get exportedAt {
    final raw = document['exportedAt'];
    if (raw is! String) return null;
    return DateTime.tryParse(raw);
  }

  List<Map<String, dynamic>> rows(String section) =>
      DataTransfer.rowsOf(document, section);

  int countOf(String section) => rows(section).length;

  int get photoCount {
    final a = archive;
    if (a == null) return 0;
    return a.files
        .where((f) => f.isFile && f.name.startsWith('photos/') && f.name.length > 7)
        .length;
  }
}

/// The Export/Import engine: everything that moves data between the
/// SQLite database and a backup file lives here, inside lib/data/.
///
/// A backup is a GENERATED logical document (format version 10), not a
/// copy of the database file: six sections matching the schema, rows
/// in schema shape, ids present only as document-internal labels. The
/// ZIP carries that document plus the photo files, by filename.
///
/// The document's last field is a SHA-256 fingerprint of everything
/// before it, computed at export and verified at selection: any edit
/// to the document — a vandal's mischief or a clever user's tweak —
/// changes the fingerprint, and the backup is refused. It is
/// tamper-EVIDENCE, not tamper-proofing: it stops anyone who doesn't
/// know to recompute and replace the fingerprint, which is the whole
/// of the realistic threat to a personal backup.
class DataTransfer {
  DataTransfer._();
  static final DataTransfer instance = DataTransfer._();

  /// The backup document's format stamp. Version 9 was the JSON
  /// store's; it is recognised on import only to be refused politely.
  static const int backupFormatVersion = 10;

  static const List<String> _itemSections = [
    'storageItems',
    'inventoryItems',
    'poiItems',
  ];

  Future<Database> get _db => AppDatabase.instance.database;

  static List<Map<String, dynamic>> rowsOf(
      Map<String, dynamic> document, String section) {
    final v = document[section];
    if (v is! List) return const [];
    return v
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
  }

  // ------------------------------------------------------------- counts

  Future<DataCounts> currentCounts() async {
    final db = await _db;
    Future<int> count(String sql) async =>
        Sqflite.firstIntValue(await db.rawQuery(sql)) ?? 0;
    final images = await count(
          "SELECT COUNT(*) FROM storage_items WHERE photo_filename IS NOT NULL",
        ) +
        await count(
          "SELECT COUNT(*) FROM inventory_items WHERE photo_filename IS NOT NULL",
        ) +
        await count(
          "SELECT COUNT(*) FROM poi_items WHERE photo_filename IS NOT NULL",
        );
    return DataCounts(
      generals: await count('SELECT COUNT(*) FROM general_locations'),
      storageSpecifics: await count('SELECT COUNT(*) FROM storage_specifics'),
      inventorySpecifics:
          await count('SELECT COUNT(*) FROM inventory_specifics'),
      storageItems: await count('SELECT COUNT(*) FROM storage_items'),
      inventoryItems: await count('SELECT COUNT(*) FROM inventory_items'),
      poiItems: await count('SELECT COUNT(*) FROM poi_items'),
      imagesLinked: images,
    );
  }

  // ------------------------------------------------------------- export

  /// Builds the export document from the database: every row of every
  /// table, in schema shape, stamps as stored (UTC ISO with Z). The
  /// SHA-256 fingerprint goes in last, like a signature at the foot of
  /// the document, covering everything before it.
  Future<Map<String, dynamic>> buildExportDocument() async {
    final db = await _db;
    Future<List<Map<String, dynamic>>> rows(String table) async {
      final r = await db.query(table, orderBy: 'id');
      return r.map((row) => Map<String, dynamic>.from(row)).toList();
    }

    final document = <String, dynamic>{
      'version': backupFormatVersion,
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'generals': await rows('general_locations'),
      'storageSpecifics': await rows('storage_specifics'),
      'inventorySpecifics': await rows('inventory_specifics'),
      'storageItems': await rows('storage_items'),
      'inventoryItems': await rows('inventory_items'),
      'poiItems': await rows('poi_items'),
    };
    document['checksum'] = _digestOf(document);
    return document;
  }

  /// The document's fingerprint: SHA-256 over the compact JSON of the
  /// document without its checksum field. Export and verification use
  /// this one function, so the bytes being fingerprinted are produced
  /// the same way at both ends.
  String _digestOf(Map<String, dynamic> document) {
    final unsigned = Map<String, dynamic>.from(document)
      ..remove('checksum');
    return sha256.convert(utf8.encode(jsonEncode(unsigned))).toString();
  }

  /// Assembles the export ZIP wholly in memory — the document plus
  /// every referenced photo, under its own filename — and writes it
  /// ONCE: to a `.tmp` name first, renamed to the final name only when
  /// the write has completed. A file bearing an export name is
  /// therefore always a complete export; an interrupted write can
  /// leave at most a `.tmp` file behind.
  Future<File> exportZipTo(Directory dir, {String? fileName}) async {
    final document = await buildExportDocument();
    final archive = Archive();
    final jsonBytes = utf8.encode(
      const JsonEncoder.withIndent('  ').convert(document),
    );
    archive.addFile(
      ArchiveFile('wherelog_data.json', jsonBytes.length, jsonBytes),
    );

    final filenames = <String>{};
    for (final section in _itemSections) {
      for (final row in rowsOf(document, section)) {
        final fn = row['photo_filename'];
        if (fn is String && fn.isNotEmpty) filenames.add(fn);
      }
    }
    for (final filename in filenames) {
      final file = await PhotoStore.fileFor(filename);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      archive.addFile(ArchiveFile('photos/$filename', bytes.length, bytes));
    }

    final zipBytes = ZipEncoder().encode(archive);
    if (zipBytes == null) {
      throw StateError('Failed to encode the export ZIP.');
    }
    if (!await dir.exists()) await dir.create(recursive: true);
    final name = fileName ?? 'wherelog_export_${_stamp()}.zip';
    final tmp = File(p.join(dir.path, '$name.tmp'));
    await tmp.writeAsBytes(zipBytes, flush: true);
    final out = File(p.join(dir.path, name));
    if (await out.exists()) await out.delete();
    await tmp.rename(out.path);
    return out;
  }

  String _stamp() {
    final now = DateTime.now();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_'
        '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  // -------------------------------------------------------- parse/check

  /// Decodes and validates a picked backup file. Throws a
  /// [FormatException] with a plain message when the file is not a
  /// restorable backup; the database is never touched here. On
  /// success, returns the shared selection used by View and Restore.
  BackupSelection parseBackup({
    required String fileName,
    required Uint8List bytes,
  }) {
    Map<String, dynamic> document;
    Archive? archive;
    if (fileName.toLowerCase().endsWith('.zip')) {
      archive = ZipDecoder().decodeBytes(bytes);
      ArchiveFile? jsonFile;
      for (final f in archive.files) {
        if (f.name == 'wherelog_data.json' ||
            f.name.endsWith('/wherelog_data.json')) {
          jsonFile = f;
          break;
        }
      }
      if (jsonFile == null) {
        throw const FormatException(
          'This ZIP does not contain a WhereLog data file (wherelog_data.json).',
        );
      }
      document = _decodeDocument(jsonFile.content as List<int>);
    } else {
      document = _decodeDocument(bytes);
    }
    _validate(document);
    return BackupSelection(
      fileName: fileName,
      document: document,
      archive: archive,
    );
  }

  Map<String, dynamic> _decodeDocument(List<int> bytes) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } catch (_) {
      throw const FormatException(
        'The data file in this backup could not be read.',
      );
    }
    if (decoded is! Map) {
      throw const FormatException(
        'The data file in this backup is not a WhereLog document.',
      );
    }
    return decoded.cast<String, dynamic>();
  }

  /// Whole-document validation, run BEFORE the database is touched:
  /// the version, the section shapes, field presence and types, and
  /// every reference resolving to a record inside the same document.
  void _validate(Map<String, dynamic> doc) {
    final version = doc['version'];
    if (version is! int) {
      throw const FormatException(
        'This file is not a WhereLog backup: it has no format version.',
      );
    }
    if (version == 9) {
      throw const FormatException(
        'This backup predates the database format (version 9) and cannot be restored into the current app.',
      );
    }
    if (version != backupFormatVersion) {
      throw FormatException(
        'This backup uses format version $version, which this app cannot restore (expected version $backupFormatVersion).',
      );
    }

    final checksum = doc['checksum'];
    if (checksum is! String) {
      throw const FormatException(
        'This backup has no export fingerprint, so its contents cannot be verified. It cannot be restored.',
      );
    }
    if (checksum != _digestOf(doc)) {
      throw const FormatException(
        'This backup has been changed or damaged since it was exported — its contents do not match its export fingerprint. It cannot be restored.',
      );
    }

    final generals = rowsOf(doc, 'generals');
    for (final key in const [
      'generals',
      'storageSpecifics',
      'inventorySpecifics',
      'storageItems',
      'inventoryItems',
      'poiItems',
    ]) {
      if (doc[key] is! List) {
        throw FormatException(
          'This backup is damaged: the "$key" section is missing or is not a list.',
        );
      }
    }
    final sSpecs = rowsOf(doc, 'storageSpecifics');
    final iSpecs = rowsOf(doc, 'inventorySpecifics');
    final sItems = rowsOf(doc, 'storageItems');
    final iItems = rowsOf(doc, 'inventoryItems');
    final pois = rowsOf(doc, 'poiItems');

    final generalIds = <int>{};
    for (final r in generals) {
      _reqInt(r, 'id');
      _reqString(r, 'name');
      generalIds.add(r['id'] as int);
    }
    final sSpecIds = _validateSpecifics(sSpecs, generalIds);
    final iSpecIds = _validateSpecifics(iSpecs, generalIds);

    for (final r in sItems) {
      _validateItemBase(r, generalIds, sSpecIds);
      _optInt(r, 'value_cents');
    }
    for (final r in iItems) {
      _validateItemBase(r, generalIds, iSpecIds);
      _optInt(r, 'value_cents');
      _optInt(r, 'purchase_price_cents');
      _optString(r, 'brand');
      _optString(r, 'model');
      _optString(r, 'serial_number');
      _optString(r, 'acquisition_date');
    }
    for (final r in pois) {
      _reqInt(r, 'id');
      _reqString(r, 'name');
      _reqNum(r, 'latitude');
      _reqNum(r, 'longitude');
      _reqString(r, 'address');
      _reqString(r, 'notes');
      _optString(r, 'photo_filename');
      _optString(r, 'source');
      _reqString(r, 'created_at');
      _reqString(r, 'modified_at');
    }
  }

  Set<int> _validateSpecifics(
    List<Map<String, dynamic>> rows,
    Set<int> generalIds,
  ) {
    final ids = <int>{};
    for (final r in rows) {
      _reqInt(r, 'id');
      _reqInt(r, 'general_id');
      _reqString(r, 'name');
      if (!generalIds.contains(r['general_id'])) {
        throw const FormatException(
          'This backup is damaged: a Specific location points at a General that is not in the backup.',
        );
      }
      ids.add(r['id'] as int);
    }
    return ids;
  }

  void _validateItemBase(
    Map<String, dynamic> r,
    Set<int> generalIds,
    Set<int> specificIds,
  ) {
    _reqInt(r, 'id');
    _reqString(r, 'name');
    _reqInt(r, 'general_id');
    if (!generalIds.contains(r['general_id'])) {
      throw const FormatException(
        'This backup is damaged: an item points at a General location that is not in the backup.',
      );
    }
    final sid = r['specific_id'];
    if (sid != null && (sid is! int || !specificIds.contains(sid))) {
      throw const FormatException(
        'This backup is damaged: an item points at a Specific location that is not in the backup.',
      );
    }
    _reqInt(r, 'quantity');
    _reqString(r, 'notes');
    _optString(r, 'photo_filename');
    _reqString(r, 'created_at');
    _reqString(r, 'modified_at');
  }

  void _reqInt(Map<String, dynamic> r, String field) {
    if (r[field] is! int) {
      throw FormatException(
        'This backup is damaged: a record has no valid "$field".',
      );
    }
  }

  void _optInt(Map<String, dynamic> r, String field) {
    final v = r[field];
    if (v != null && v is! int) {
      throw FormatException(
        'This backup is damaged: a record has an invalid "$field".',
      );
    }
  }

  void _reqString(Map<String, dynamic> r, String field) {
    if (r[field] is! String) {
      throw FormatException(
        'This backup is damaged: a record has no valid "$field".',
      );
    }
  }

  void _optString(Map<String, dynamic> r, String field) {
    final v = r[field];
    if (v != null && v is! String) {
      throw FormatException(
        'This backup is damaged: a record has an invalid "$field".',
      );
    }
  }

  void _reqNum(Map<String, dynamic> r, String field) {
    if (r[field] is! num) {
      throw FormatException(
        'This backup is damaged: a record has no valid "$field".',
      );
    }
  }

  // ------------------------------------------------------------ restore

  /// Restores a validated selection. Photo files are extracted first —
  /// they live outside the database transaction, so a later failure
  /// can leave an unreferenced photo file, never a damaged database.
  /// The document itself is loaded by [importDocument] in ONE
  /// transaction: atomic, not resumable; a failure rolls the database
  /// back to exactly what it was, and restarting means running the
  /// restore again.
  Future<void> restore(BackupSelection selection) async {
    final archive = selection.archive;
    if (archive != null) {
      final dir = await PhotoStore.photosDir();
      for (final f in archive.files) {
        if (!f.isFile) continue;
        if (!f.name.startsWith('photos/')) continue;
        final base = p.basename(f.name);
        if (base.isEmpty) continue;
        await File(p.join(dir.path, base))
            .writeAsBytes(f.content as List<int>);
      }
    }
    await importDocument(selection.document);
  }

  /// The bulk load: delete children-first, insert parents-first,
  /// translating the document's ids through in-memory cross-references
  /// (old id → the new id SQLite returned at insert). The document's
  /// ids are used only as lookup keys and never enter the database;
  /// relationships are preserved, numbers are not. The document's
  /// created/modified stamps are stored as data — restores do not
  /// restamp. [document] must already have passed validation (see
  /// [parseBackup]).
  Future<void> importDocument(Map<String, dynamic> doc) async {
    final generals = rowsOf(doc, 'generals');
    final sSpecs = rowsOf(doc, 'storageSpecifics');
    final iSpecs = rowsOf(doc, 'inventorySpecifics');
    final sItems = rowsOf(doc, 'storageItems');
    final iItems = rowsOf(doc, 'inventoryItems');
    final pois = rowsOf(doc, 'poiItems');

    final db = await _db;
    await db.transaction((txn) async {
      await _deleteAll(txn);

      final genMap = <int, int>{};
      for (final r in generals) {
        final newId = await txn.insert('general_locations', {
          'name': r['name'],
        });
        genMap[r['id'] as int] = newId;
      }

      final sSpecMap = <int, int>{};
      for (final r in sSpecs) {
        final newId = await txn.insert('storage_specifics', {
          'general_id': genMap[r['general_id']],
          'name': r['name'],
        });
        sSpecMap[r['id'] as int] = newId;
      }

      final iSpecMap = <int, int>{};
      for (final r in iSpecs) {
        final newId = await txn.insert('inventory_specifics', {
          'general_id': genMap[r['general_id']],
          'name': r['name'],
        });
        iSpecMap[r['id'] as int] = newId;
      }

      for (final r in sItems) {
        await txn.insert('storage_items', {
          'name': r['name'],
          'general_id': genMap[r['general_id']],
          'specific_id':
              r['specific_id'] == null ? null : sSpecMap[r['specific_id']],
          'quantity': r['quantity'],
          'value_cents': r['value_cents'],
          'notes': r['notes'],
          'photo_filename': r['photo_filename'],
          'created_at': r['created_at'],
          'modified_at': r['modified_at'],
        });
      }

      for (final r in iItems) {
        await txn.insert('inventory_items', {
          'name': r['name'],
          'general_id': genMap[r['general_id']],
          'specific_id':
              r['specific_id'] == null ? null : iSpecMap[r['specific_id']],
          'brand': r['brand'],
          'model': r['model'],
          'serial_number': r['serial_number'],
          'acquisition_date': r['acquisition_date'],
          'quantity': r['quantity'],
          'purchase_price_cents': r['purchase_price_cents'],
          'value_cents': r['value_cents'],
          'notes': r['notes'],
          'photo_filename': r['photo_filename'],
          'created_at': r['created_at'],
          'modified_at': r['modified_at'],
        });
      }

      for (final r in pois) {
        await txn.insert('poi_items', {
          'name': r['name'],
          'latitude': r['latitude'],
          'longitude': r['longitude'],
          'address': r['address'],
          'notes': r['notes'],
          'photo_filename': r['photo_filename'],
          'source': r['source'],
          'created_at': r['created_at'],
          'modified_at': r['modified_at'],
        });
      }
    });
  }

  /// Empties all six tables in one transaction (Export Data Reset,
  /// after its export has been written). Photo files are left on disk
  /// unlinked, as the reset's confirmation dialog states.
  Future<void> clearAllData() async {
    final db = await _db;
    await db.transaction((txn) async {
      await _deleteAll(txn);
    });
  }

  Future<void> _deleteAll(Transaction txn) async {
    // Children before parents, so foreign keys are never violated
    // mid-transaction.
    await txn.delete('storage_items');
    await txn.delete('inventory_items');
    await txn.delete('poi_items');
    await txn.delete('storage_specifics');
    await txn.delete('inventory_specifics');
    await txn.delete('general_locations');
  }
}
