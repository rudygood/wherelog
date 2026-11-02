import 'location_records.dart';
import 'sqlite_location_repository.dart';

/// The name-based location operations the shared General/Specific picker
/// (RequiredSection) works with, separated from where the locations live.
///
/// The picker thinks in names and treats a general's id as an opaque
/// token ('' when a name doesn't resolve). SqliteLocationData is the
/// backing: it serves the SQLite location tables from a loaded cache —
/// the same load-then-read pattern the Location Options screen uses.
/// (A JSON-backed implementation served during the migration and
/// retired with the JSON store in the Export/Import batch.)
abstract class LocationData {
  List<String> get generalNames;

  /// Opaque id token for a general name, '' if the name doesn't resolve.
  String generalIdForName(String name);

  List<String> storageSpecificNamesFor(String generalId);
  List<String> inventorySpecificNamesFor(String generalId);

  /// Specific names under a general *name* (the picker's similar-name
  /// check works from names alone).
  List<String> specificNamesByGeneralName(String generalName, {required bool storage});

  bool isDuplicateGeneral(String name);
  bool isDuplicateStorageSpecific(String generalId, String name);
  bool isDuplicateInventorySpecific(String generalId, String name);

  Future<void> addGeneral(String name);
  Future<void> addStorageSpecific(String generalId, String name);
  Future<void> addInventorySpecific(String generalId, String name);
}

class SqliteLocationData implements LocationData {
  final SqliteLocationRepository _repo = SqliteLocationRepository.instance;

  List<GeneralLocation> _generals = [];
  List<StorageSpecific> _storageSpecifics = [];
  List<InventorySpecific> _inventorySpecifics = [];

  /// Loads (or reloads) the cached location lists. Callers await this
  /// before the picker reads names, and the add methods below refresh
  /// the cache themselves after a write.
  Future<void> load() async {
    _generals = await _repo.getGenerals();
    _storageSpecifics = await _repo.getStorageSpecifics();
    _inventorySpecifics = await _repo.getInventorySpecifics();
  }

  @override
  List<String> get generalNames => _generals
      .map((g) => g.name)
      .where((n) => n.isNotEmpty)
      .toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

  @override
  String generalIdForName(String name) {
    final lower = name.trim().toLowerCase();
    for (final g in _generals) {
      if (g.name.trim().toLowerCase() == lower) return g.id?.toString() ?? '';
    }
    return '';
  }

  List<String> _specificNames(int? generalId, bool storage) {
    if (generalId == null) return [];
    final names = storage
        ? _storageSpecifics.where((s) => s.generalId == generalId).map((s) => s.name)
        : _inventorySpecifics.where((s) => s.generalId == generalId).map((s) => s.name);
    return names.where((n) => n.trim().isNotEmpty).toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  }

  @override
  List<String> storageSpecificNamesFor(String generalId) =>
      _specificNames(int.tryParse(generalId), true);

  @override
  List<String> inventorySpecificNamesFor(String generalId) =>
      _specificNames(int.tryParse(generalId), false);

  @override
  List<String> specificNamesByGeneralName(String generalName, {required bool storage}) {
    final token = generalIdForName(generalName);
    if (token.isEmpty) return [];
    return storage ? storageSpecificNamesFor(token) : inventorySpecificNamesFor(token);
  }

  @override
  bool isDuplicateGeneral(String name) {
    final lower = name.trim().toLowerCase();
    return _generals.any((g) => g.name.toLowerCase() == lower);
  }

  @override
  bool isDuplicateStorageSpecific(String generalId, String name) {
    final id = int.tryParse(generalId);
    if (id == null) return false;
    final lower = name.trim().toLowerCase();
    return _storageSpecifics.any((s) => s.generalId == id && s.name.toLowerCase() == lower);
  }

  @override
  bool isDuplicateInventorySpecific(String generalId, String name) {
    final id = int.tryParse(generalId);
    if (id == null) return false;
    final lower = name.trim().toLowerCase();
    return _inventorySpecifics.any((s) => s.generalId == id && s.name.toLowerCase() == lower);
  }

  @override
  Future<void> addGeneral(String name) async {
    await _repo.addGeneral(name);
    await load();
  }

  @override
  Future<void> addStorageSpecific(String generalId, String name) async {
    final id = int.tryParse(generalId);
    if (id == null) return;
    await _repo.addStorageSpecific(id, name);
    await load();
  }

  @override
  Future<void> addInventorySpecific(String generalId, String name) async {
    final id = int.tryParse(generalId);
    if (id == null) return;
    await _repo.addInventorySpecific(id, name);
    await load();
  }
}
