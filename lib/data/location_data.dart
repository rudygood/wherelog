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
///
/// Version 4 (build 60): one Specific list per General, shared by
/// both tabs — a spot is a spot, whether the thing on it is stored
/// or inventoried.
abstract class LocationData {
  List<String> get generalNames;

  /// Opaque id token for a general name, '' if the name doesn't resolve.
  String generalIdForName(String name);

  List<String> specificNamesFor(String generalId);

  /// Specific names under a general *name* (the picker's similar-name
  /// check works from names alone).
  List<String> specificNamesByGeneralName(String generalName);

  bool isDuplicateGeneral(String name);
  bool isDuplicateSpecific(String generalId, String name);

  Future<void> addGeneral(String name);
  Future<void> addSpecific(String generalId, String name);

  /// Renames, by current name. Items reference locations by id, so a
  /// rename is one row and every item filed under it follows.
  Future<void> renameGeneral(String oldName, String newName);
  Future<void> renameSpecific(String generalName, String oldName, String newName);
}

class SqliteLocationData implements LocationData {
  final SqliteLocationRepository _repo = SqliteLocationRepository.instance;

  List<GeneralLocation> _generals = [];
  List<Specific> _specifics = [];

  /// Loads (or reloads) the cached location lists. Callers await this
  /// before the picker reads names, and the add methods below refresh
  /// the cache themselves after a write.
  Future<void> load() async {
    _generals = await _repo.getGenerals();
    _specifics = await _repo.getSpecifics();
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

  @override
  List<String> specificNamesFor(String generalId) {
    final id = int.tryParse(generalId);
    if (id == null) return [];
    final names = _specifics
        .where((s) => s.generalId == id)
        .map((s) => s.name)
        .where((n) => n.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return names;
  }

  @override
  List<String> specificNamesByGeneralName(String generalName) {
    final token = generalIdForName(generalName);
    if (token.isEmpty) return [];
    return specificNamesFor(token);
  }

  @override
  bool isDuplicateGeneral(String name) {
    final lower = name.trim().toLowerCase();
    return _generals.any((g) => g.name.toLowerCase() == lower);
  }

  @override
  bool isDuplicateSpecific(String generalId, String name) {
    final id = int.tryParse(generalId);
    if (id == null) return false;
    final lower = name.trim().toLowerCase();
    return _specifics.any((s) => s.generalId == id && s.name.toLowerCase() == lower);
  }

  @override
  Future<void> addGeneral(String name) async {
    await _repo.addGeneral(name);
    await load();
  }

  @override
  Future<void> addSpecific(String generalId, String name) async {
    final id = int.tryParse(generalId);
    if (id == null) return;
    await _repo.addSpecific(id, name);
    await load();
  }

  @override
  Future<void> renameGeneral(String oldName, String newName) async {
    final id = int.tryParse(generalIdForName(oldName));
    if (id == null) return;
    await _repo.renameGeneral(id, newName.trim());
    await load();
  }

  @override
  Future<void> renameSpecific(String generalName, String oldName, String newName) async {
    final gid = int.tryParse(generalIdForName(generalName));
    if (gid == null) return;
    for (final s in _specifics) {
      if (s.generalId == gid && s.name == oldName) {
        final id = s.id;
        if (id == null) return;
        await _repo.renameSpecific(id, newName.trim());
        await load();
        return;
      }
    }
  }
}
