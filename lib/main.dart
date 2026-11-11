import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/storage_add_screen.dart';
import 'widgets/app_sheet.dart';
import 'screens/location_options_screen.dart';
import 'screens/storage_edit_screen.dart';
import 'screens/inventory_add_screen.dart';
import 'screens/inventory_edit_screen.dart';
import 'screens/poi_add_screen.dart';
import 'screens/poi_import_verify_screen.dart';
import 'screens/poi_edit_screen.dart';
import 'data/inventory_records.dart';
import 'data/location_data.dart';
import 'data/poi_records.dart';
import 'data/location_records.dart';
import 'data/photo_store.dart';
import 'data/sqlite_inventory_repository.dart';
import 'data/sqlite_location_repository.dart';
import 'data/sqlite_poi_repository.dart';
import 'data/sqlite_storage_repository.dart';
import 'data/storage_records.dart';
import 'theme/app_theme.dart';
import 'widgets/app_icons.dart';
import 'widgets/location_filter_section.dart';
import 'utils/map_utils.dart';
import 'utils/poi_import_utils.dart';
import 'services/incoming_gpx_service.dart';
import 'services/share_diag_service.dart';
import 'settings_service.dart';
import 'dart:async';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:geolocator/geolocator.dart';
import 'screens/poi_map_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(WhereLogApp());
}

class WhereLogApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WhereLog',
      theme: AppTheme.light(),
      home: HomeScreen());
  }
}

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _tabIndex = 0;
  List<String> _tabOrder = ['Storage','Inventory','POI'];
  String _searchQuery = '';
  bool _searchMode = false;
  String _sortBy = 'Recent';
  Map<String, String> _filterGeneralMap = {'Storage': 'All', 'Inventory': 'All', 'POI': 'All'};
  Map<String, String?> _filterSpecificMap = {'Storage': null, 'Inventory': null, 'POI': null};

  bool _matchesLocationFilterForTab(Item item, String tabName) {
    final g = _filterGeneralMap[tabName] ?? 'All';
    final s = _filterSpecificMap[tabName];
    return LocationFilterSection.matchesFilter(place: item.place, bin: item.bin, filterGeneral: g, filterSpecific: s);
  }
  // INDEPENDENT SELECT MODE PER TAB - each tab owns its own state
  Map<String, bool> _selectModes = {'Storage': false, 'Inventory': false, 'POI': false};
  Map<String, Set<String>> _selectedIdsMap = {'Storage': <String>{}, 'Inventory': <String>{}, 'POI': <String>{}};

  bool get _selectMode => _selectModes[_currentTabName] ?? false;
  set _selectMode(bool v) => _selectModes[_currentTabName] = v;
  Set<String> get _selectedIds => _selectedIdsMap[_currentTabName] ?? <String>{};
  set _selectedIds(Set<String> v) => _selectedIdsMap[_currentTabName] = v;

  bool _isSelectMode(String tab) => _selectModes[tab] ?? false;
  Set<String> _idsFor(String tab) => _selectedIdsMap[tab] ?? <String>{};
  int _selectedCountFor(String tab) => _selectedIdsMap[tab]?.length ?? 0;

  void _enterSelectMode(String tab) {
    setState(() {
      _selectModes[tab] = true;
      _selectedIdsMap[tab] = <String>{};
    });
  }

  void _exitSelectMode(String tab) {
    setState(() {
      _selectModes[tab] = false;
      _selectedIdsMap[tab] = <String>{};
    });
  }
  final TextEditingController _searchController = TextEditingController();
  // SQLite side: location tables and storage items live here now. The
  // cached records below back the location tree and the Storage list;
  // they are (re)loaded by _refreshSqliteStorage/_refreshSqliteLocations.
  final SqliteLocationRepository _locRepo = SqliteLocationRepository.instance;
  final SqliteStorageRepository _storageRepo = SqliteStorageRepository.instance;
  final SqliteInventoryRepository _invRepo = SqliteInventoryRepository.instance;
  final SqlitePoiRepository _poiRepo = SqlitePoiRepository.instance;
  final SqliteLocationData _locationData = SqliteLocationData();
  List<GeneralLocation> _sqlGenerals = [];
  List<StorageSpecific> _sqlStorageSpecifics = [];
  List<InventorySpecific> _sqlInventorySpecifics = [];
  List<StorageItem> _storageRecords = [];
  List<InventoryItem> _inventoryRecords = [];
  List<PoiItem> _poiRecords = [];
  double? currentLat;
  double? currentLng;
  bool _isLoadingLocation = false;
  String _lastShareDebug = '';

  // --- Import queue for Share-to-WhereLog ---
  List<PoiImportData> _pendingImports = [];

  Future<void> _savePendingImports() async {
    try {
      final list = _pendingImports.map((e) => e.toJson()).toList();
      await SettingsService().setPendingImports(list);
    } catch (_) {}
  }

  Future<void> _loadPendingImports() async {
    try {
      final raw = await SettingsService().getPendingImports();
      if (raw.isNotEmpty) {
        setState(() {
          _pendingImports = raw.map((j) => PoiImportData.fromJson(j)).toList();
        });
      }
    } catch (_) {}
  }

  StreamSubscription? _sharingSub;

  List<Place> places = [];
  List<Item> items = [];

  List<Place> _placesFromLocations() {
    // Location tree from the SQLite location tables (cached records):
    // single generals + both specific types merged for tree view.
    final Map<String, List<String>> generalsMap = {};
    final Map<int, String> genIdToName = {};
    for (var g in _sqlGenerals) {
      if (g.id != null && g.name.isNotEmpty) {
        genIdToName[g.id!] = g.name;
        generalsMap.putIfAbsent(g.name, () => []);
      }
    }
    for (var s in _sqlStorageSpecifics) {
      if (s.name.trim().isEmpty) continue;
      final genName = genIdToName[s.generalId];
      if (genName != null) {
        generalsMap.putIfAbsent(genName, () => []);
        if (!generalsMap[genName]!.contains(s.name)) generalsMap[genName]!.add(s.name);
      }
    }
    for (var s in _sqlInventorySpecifics) {
      if (s.name.trim().isEmpty) continue;
      final genName = genIdToName[s.generalId];
      if (genName != null) {
        generalsMap.putIfAbsent(genName, () => []);
        if (!generalsMap[genName]!.contains(s.name)) generalsMap[genName]!.add(s.name);
      }
    }

    if (generalsMap.isEmpty) {
      debugPrint('WARNING: _placesFromLocations empty - check generals');
      return [];
    }

    final list = <Place>[];
    generalsMap.forEach((place, binsSet) {
      list.add(Place(name: place, bins: binsSet.map((b) => Bin(name: b)).toList()));
    });
    return list;
  }
    List<Item> _itemsFromStorageRecords() {
    // Storage list rows built from the SQLite storage_items records,
    // with place/bin resolved to names from the cached location records.
    final Map<int, String> genIdToName = {};
    for (var g in _sqlGenerals) {
      if (g.id != null) genIdToName[g.id!] = g.name;
    }
    final Map<int, StorageSpecific> specById = {};
    for (var s in _sqlStorageSpecifics) {
      if (s.id != null) specById[s.id!] = s;
    }

    return _storageRecords.map((r) {
      String place = genIdToName[r.generalId] ?? '';
      String? bin;
      if (r.specificId != null) {
        final spec = specById[r.specificId];
        if (spec != null) {
          place = genIdToName[spec.generalId] ?? place;
          bin = spec.name.isEmpty ? null : spec.name;
        }
      }
      return Item(
        id: r.id!.toString(),
        name: r.name,
        qty: r.quantity,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '📦',
        createdAt: DateTime.tryParse(r.createdAt),
        modifiedAt: DateTime.tryParse(r.modifiedAt),
        generalId: r.generalId.toString(),
        specificId: r.specificId?.toString());
    }).toList();
  }

  Future<void> _refreshSqliteLocations() async {
    final generals = await _locRepo.getGenerals();
    final stoSpecs = await _locRepo.getStorageSpecifics();
    final invSpecs = await _locRepo.getInventorySpecifics();
    if (!mounted) return;
    setState(() {
      _sqlGenerals = generals;
      _sqlStorageSpecifics = stoSpecs;
      _sqlInventorySpecifics = invSpecs;
      places = _placesFromLocations();
    });
  }

  Future<void> _refreshSqliteStorage() async {
    final records = await _storageRepo.getAll();
    await _refreshSqliteLocations();
    if (!mounted) return;
    setState(() {
      _storageRecords = records;
      items = _itemsFromStorageRecords();
    });
  }
  List<Item> _inventoryItemsFromRecords() {
    // Inventory list rows built from the SQLite inventory_items records,
    // with place/bin resolved to names from the cached location records.
    final Map<int, String> genIdToName = {};
    for (var g in _sqlGenerals) {
      if (g.id != null) genIdToName[g.id!] = g.name;
    }
    final Map<int, InventorySpecific> specById = {};
    for (var s in _sqlInventorySpecifics) {
      if (s.id != null) specById[s.id!] = s;
    }

    return _inventoryRecords.map((r) {
      String place = genIdToName[r.generalId] ?? '';
      String? bin;
      if (r.specificId != null) {
        final spec = specById[r.specificId];
        if (spec != null) {
          place = genIdToName[spec.generalId] ?? place;
          bin = spec.name.isEmpty ? null : spec.name;
        }
      }
      return Item(
        id: r.id!.toString(),
        name: r.name,
        qty: r.quantity,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '🪑',
        createdAt: DateTime.tryParse(r.createdAt),
        modifiedAt: DateTime.tryParse(r.modifiedAt),
        generalId: r.generalId.toString(),
        specificId: r.specificId?.toString());
    }).toList();
  }

  Future<void> _refreshSqliteInventory() async {
    final records = await _invRepo.getAll();
    await _refreshSqliteLocations();
    if (!mounted) return;
    setState(() {
      _inventoryRecords = records;
      inventoryItemsList = _inventoryItemsFromRecords();
    });
  }

    Future<void> fetchCurrentForDistance() async {
    setState(() => _isLoadingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location services disabled')));
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 12));
      if (!mounted) return;
      const double kMoveThresh = 402.0; // 0.25 mi
      if (currentLat != null && currentLng != null) { final moved = Geolocator.distanceBetween(currentLat!, currentLng!, pos.latitude, pos.longitude); if (moved < kMoveThresh) { if (mounted) setState(() => _isLoadingLocation = false); return; } }
      setState(() { currentLat = pos.latitude; currentLng = pos.longitude; });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Location error: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingLocation = false);
    }
  }

  // ---- Import POI methods - selectable list, keep until Save ----
  Future<void> _openImportSheet() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text('Import Places', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 12),
                      if (_pendingImports.isNotEmpty) ...[
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(color: AppColors.cardSelected, borderRadius: BorderRadius.circular(12)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text('Ready to Import (${_pendingImports.length})', style: TextStyle(fontWeight: FontWeight.bold)),
                                Spacer(),
                                TextButton(onPressed: () async { setState(() => _pendingImports.clear()); await _savePendingImports(); setSheetState((){}); Navigator.pop(ctx); }, child: Text('Clear All')),
                              ]),
                              SizedBox(height: 8),
                              Text('Tap to import - stays until saved', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontStyle: FontStyle.italic)),
                              SizedBox(height: 8),
                              ..._pendingImports.asMap().entries.map((entry) {
                                final idx = entry.key;
                                final p = entry.value;
                                return Card(
                                  margin: EdgeInsets.only(bottom: 6),
                                  child: ListTile(
                                    dense: true,
                                    leading: Icon(Icons.place, color: AppColors.alert),
                                    title: Text(p.name, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                                    subtitle: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (p.address.isNotEmpty) Text(p.address, style: TextStyle(fontSize: 11, color: AppColors.textSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                                        Text('${p.lat.toStringAsFixed(5)}, ${p.lng.toStringAsFixed(5)} • ${p.source}', style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                                      ],
                                    ),
                                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                                      IconButton(icon: Icon(Icons.check_circle, color: AppColors.success), tooltip: 'Import this', onPressed: () { Navigator.pop(ctx); _processImportAt(idx); }),
                                      IconButton(icon: Icon(Icons.close, size: 18), tooltip: 'Remove', onPressed: () async { setState(() => _pendingImports.removeAt(idx)); await _savePendingImports(); setSheetState((){}); if (_pendingImports.isEmpty) Navigator.pop(ctx); }),
                                    ]),
                                    onTap: () { Navigator.pop(ctx); _processImportAt(idx); },
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                        SizedBox(height: 12),
                        Divider(),
                        SizedBox(height: 8),
                      ],
                      ListTile(leading: Icon(Icons.content_paste), title: Text('Paste from Clipboard'), subtitle: Text('Apple Maps, Google Maps, geo:, lat,lng'), onTap: () async { Navigator.pop(ctx); await _importFromClipboard(); }),
                      ListTile(leading: Icon(Icons.file_open), title: Text('Import GPX File'), subtitle: Text('Waypoints from GPX'), onTap: () async { Navigator.pop(ctx); await _importFromGpx(); }),
                      SizedBox(height: 8),
                      OutlinedButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _processImportAt(int index) async {
    if (index < 0 || index >= _pendingImports.length) return;
    final data = _pendingImports[index];
    // Every staged import passes the verification gate first:
    // the point is checked on the map (and may be adjusted)
    // before the add screen opens. Backing out of the gate
    // leaves the import queued, untouched.
    final verified = await Navigator.of(context).push<PoiImportData>(MaterialPageRoute(builder: (_) => PoiImportVerifyScreen(data: data)));
    if (!mounted || verified == null) return;
    final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiAddScreen(initialName: verified.name, initialLat: verified.lat, initialLng: verified.lng, initialAddress: verified.address, initialSource: verified.source, initialNameIsPlaceholder: verified.nameIsPlaceholder)));
    if (mounted) {
      await _refreshSqlitePois();
      if (result == true) {
        setState(() => _pendingImports.removeAt(index));
        if (mounted) {
          await _savePendingImports();
          // No snackbar - auto-switch shows result
        }
      } else {
        if (mounted && _pendingImports.isNotEmpty) {
          // Import cancelled - keep in queue, no snackbar
        }
      }
    }
  }

  Future<void> _processPendingImports() async {
    if (_pendingImports.isEmpty) return;
    await _openImportSheet();
  }

  Future<void> _processImportData(PoiImportData data) async {
    final idx = _pendingImports.indexOf(data);
    if (idx >= 0) {
      await _processImportAt(idx);
    } else {
      // Same verification gate as the queued path above.
      final verified = await Navigator.of(context).push<PoiImportData>(MaterialPageRoute(builder: (_) => PoiImportVerifyScreen(data: data)));
      if (!mounted || verified == null) return;
      final result = await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiAddScreen(initialName: verified.name, initialLat: verified.lat, initialLng: verified.lng, initialAddress: verified.address, initialSource: verified.source, initialNameIsPlaceholder: verified.nameIsPlaceholder)));
      if (mounted) {
        await _refreshSqlitePois();
      }
    }
  }

  Future<void> _importFromClipboard() async {
    final list = await PoiImportUtils.importFromClipboard();
    if (list.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No location found in clipboard')));
      return;
    }
    setState(() => _pendingImports.addAll(list));
    await _savePendingImports();
    if (mounted) await _openImportSheet();
  }

  Future<void> _importFromGpx() async {
    final list = await PoiImportUtils.importFromGpxFile();
    if (list.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No waypoints found in GPX')));
      return;
    }
    setState(() => _pendingImports.addAll(list));
    if (mounted) {
      setState(() {});
      await _savePendingImports();
      await _openImportSheet();
    }
  }

  /// GPX waypoints arriving from outside the in-app picker —
  /// an iOS "Open with WhereLog" hand-off, or a GPX file shared
  /// into the app — join the same pending-import queue and get
  /// the same verification gate as every other import.
  Future<void> _queueGpxList(List<PoiImportData> list) async {
    if (list.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No waypoints found in GPX')));
      return;
    }
    setState(() => _pendingImports.addAll(list));
    await _savePendingImports();
    if (mounted) await _openImportSheet();
  }

  Future<void> _queueGpxPath(String path) async {
    await _queueGpxList(await PoiImportUtils.importFromGpxPath(path));
  }

  Future<void> _queueGpxContent(String content) async {
    await _queueGpxList(PoiImportUtils.parseGpxContent(content));
  }

  /// The iOS "Open with" mailbox: a pending hand-off is taken
  /// once the first frame is up (the import sheet needs a built
  /// screen to open on), and later hand-offs are pushed to the
  /// availability handler while the app is running.
  Future<void> _initIncomingGpx() async {
    IncomingGpxService.setAvailabilityHandler((content) async {
      await _queueGpxContent(content);
    });
    final pending = await IncomingGpxService.takePendingGpxContent();
    if (pending != null && pending.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _queueGpxContent(pending);
      });
    }
  }

  double? calcDistanceMeters(double? lat, double? lng) {
    if (currentLat == null || currentLng == null || lat == null || lng == null) return null;
    try {
      return Geolocator.distanceBetween(currentLat!, currentLng!, lat, lng);
    } catch (_) {
      return null;
    }
  }

  String formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000;
    final miles = meters / 1609.34;
    return '${km.toStringAsFixed(1)} km / ${miles.toStringAsFixed(1)} mi';
  }


  List<Item> _inventoryItemsList = [];


  List<Item> inventoryItemsList = [];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _tabIndex = _tabController.index));
    places = _placesFromLocations();
    items = _itemsFromStorageRecords();
    inventoryItemsList = _inventoryItemsFromRecords();
    _refreshSqliteStorage();
    _refreshSqliteInventory();
    _refreshSqlitePois();
    _loadTabOrder();
    _loadPendingImports();
    _initSharing();
    _initIncomingGpx();
  }

  @override
  void dispose() {
    _sharingSub?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // --- Share-to-WhereLog implementation ---
  Future<void> _initSharing() async {
    try {
      final initialMedia = await ReceiveSharingIntent.instance.getInitialMedia();
      ShareDiagService.logEvent('initialMedia: ${initialMedia.length} item(s)${initialMedia.isNotEmpty ? ' | first path=${initialMedia.first.path} | message=${initialMedia.first.message}' : ''}');
      if (initialMedia.isNotEmpty) {
        final first = initialMedia.first;
        if (first.path.toLowerCase().endsWith('.gpx')) {
          _queueGpxPath(first.path);
        } else {
          final initialText = _sharePayload(first);
          if (initialText.isNotEmpty) _handleIncomingShare(initialText);
        }
      }
      _sharingSub = ReceiveSharingIntent.instance.getMediaStream().listen((List<SharedMediaFile> sharedFiles) {
        ShareDiagService.logEvent('stream: ${sharedFiles.length} item(s)${sharedFiles.isNotEmpty ? ' | first path=${sharedFiles.first.path} | message=${sharedFiles.first.message}' : ''}');
        if (sharedFiles.isEmpty) return;
        final first = sharedFiles.first;
        if (first.path.toLowerCase().endsWith('.gpx')) {
          _queueGpxPath(first.path);
          return;
        }
        final text = _sharePayload(first);
        if (text.isNotEmpty) _handleIncomingShare(text);
      }, onError: (err) {
        debugPrint('Sharing stream error: ' + err.toString());
      });
    } catch (e) {
      debugPrint('Sharing init error: ' + e.toString());
    }
  }

  // A share arrives as (path, message): the iOS extension puts the
  // shared content in path and the user's typed caption in message.
  // The old message-first order threw the Maps link away and parsed
  // the caption instead, so no coordinates ever reached the parser
  // (Ciro's Pizza, 2026-11-10: the link sat unused in path while the
  // typed label was parsed and silently dropped). The content wins
  // whenever either value carries a URL; otherwise the first
  // non-empty value stands (Android text shares carry the content
  // in message).
  String _sharePayload(SharedMediaFile f) {
    bool carriesUrl(String? s) =>
        s != null && (s.contains('http://') || s.contains('https://'));
    if (carriesUrl(f.path)) return f.path;
    if (carriesUrl(f.message)) return f.message!;
    final m = f.message;
    if (m != null && m.isNotEmpty) return m;
    return f.path;
  }

  void _handleIncomingShare(String text) async {
    ShareDiagService.logEvent('handleIncomingShare: ${text.length > 80 ? text.substring(0, 80) : text}');
    var contextText = text;
    var parsed = PoiImportUtils.parseSharedText(text);
    if (parsed.isEmpty) {
      final lower = text.toLowerCase();
      if (lower.contains('goo.gl') || lower.contains('maps.app.goo.gl') || lower.contains('maps.apple')) {
        final expanded = await PoiImportUtils.tryExpandShortLink(text);
        contextText = expanded;
        parsed = PoiImportUtils.parseSharedText(expanded);
        if (parsed.isEmpty) {
          parsed = PoiImportUtils.parseSharedText(expanded + ' ' + text);
        }
      }
    }
    if (parsed.isNotEmpty) {
      parsed = await PoiImportUtils.refineViewportResults(parsed, contextText);
    }
    ShareDiagService.logEvent('parsed: ${parsed.length} candidate(s)');
    if (parsed.isEmpty) return;
    setState(() { _pendingImports.addAll(parsed); });
    await _savePendingImports();
  }


  // The share diagnostic readout (2026-11-10): long-press the
  // WhereLog title in the app bar. (It began on the POI import
  // button, but that button's own tooltip claims the long-press —
  // the title has no competing gesture.) Shows the native
  // group-container report and the persistent intake log.
  Future<void> _showShareDiagnostics() async {
    final report = await ShareDiagService.containerReport();
    final log = await ShareDiagService.readLog();
    if (!mounted) return;
    final fullText =
        'Group container:\n$report\n\nShare intake log:\n${log.isEmpty ? '(nothing recorded)' : log.join('\n')}';
    // The report sits in a read-only text field so it can be
    // selected and copied (Rudy, 2026-11-10) — screenshots of
    // wrapped group IDs were nobody's friend. Copy all does it in
    // one tap. The controller is created and disposed here, around
    // the dialog's own lifetime.
    final controller = TextEditingController(text: fullText);
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Share diagnostics'),
        content: SizedBox(
          width: double.maxFinite,
          child: TextField(
            controller: controller,
            readOnly: true,
            maxLines: 14,
            style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
            decoration: const InputDecoration(border: OutlineInputBorder()),
          ),
        ),
        actions: [
          TextButton(onPressed: () { ShareDiagService.clearLog(); Navigator.pop(c); }, child: const Text('Clear log')),
          TextButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: fullText));
              Navigator.pop(c);
            },
            child: const Text('Copy all'),
          ),
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Close')),
        ],
      ),
    );
    controller.dispose();
  }


  // Tab names come in two forms: short ('Storage','Inventory','POI') used
  // throughout main.dart, and long ('Storage Items','Home Inventory',
  // 'Places of Interest') returned by SettingsService.getTabOrder().
  // Normalizing to short here is what makes the per-tab top bars appear:
  // the search/filter bar is only shown when _currentTabName is 'Storage'
  // or 'Inventory', and _viewForName only recognised the short names, so
  // with long names the bars vanished (and POI fell back to Storage).
  static String _shortTabName(String name) {
    if (name == 'Storage Items' || name == 'Stored Items') return 'Storage';
    if (name == 'Home Inventory') return 'Inventory';
    if (name == 'Places of Interest') return 'POI';
    return name;
  }

  Future<void> _loadTabOrder() async {
    try {
      final order = await SettingsService().getTabOrder();
      if (order.length == 3 && mounted) {
        setState(() => _tabOrder = order.map(_shortTabName).toList());
      }
    } catch (_) {}
  }

  String get _currentTabName {
    if (_tabIndex >=0 && _tabIndex < _tabOrder.length) return _shortTabName(_tabOrder[_tabIndex]);
    return _tabOrder.isNotEmpty ? _shortTabName(_tabOrder[0]) : 'Storage';
  }

  Tab _tabForName(String name) {
    // Two-line labels as requested: Storage = Storage Items, Inventory = Home Inventory, POI = Places of Interest
    if (name == 'Storage' || name == 'Storage Items' || name == 'Stored Items') {
      return const Tab(
        child: Text('Storage\nItems',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.0)));
    }
    if (name == 'Inventory' || name == 'Home Inventory') {
      return const Tab(
        child: Text('Home\nInventory',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.0)));
    }
    if (name == 'POI' || name == 'Places of Interest') {
      return const Tab(
        child: Text('Places of\nInterest',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.0)));
    }
    return Tab(text: name);
  }

  Widget _viewForName(String name) {
    switch (_shortTabName(name)) {
      case 'Storage':
        return _buildStorageTab();
      case 'Inventory':
        return _buildInventoryTab();
      case 'POI':
        return _buildPoiTab();
      default:
        return _buildStorageTab();
    }
  }

  Future<void> _openAppMenu() async {
    // NEW: uses showAppMenu right-sheet 78% instead of bottom sheet
    final result = await showAppMenu(context);
    // Preserve existing behavior - reload tab order after menu / settings
    _loadTabOrder();
    // Menu screens can change the database under the cached lists —
    // above all Export/Import, whose Restore and Data Reset replace or
    // empty every table. Reload all three caches on the way back.
    _refreshSqliteStorage();
    _refreshSqliteInventory();
    _refreshSqlitePois();
    // If settings returned a new tab order, propagate it if needed
    if (result is List<String> && result.length == 3) {
      // Original shell returned result via Navigator.pop(context, result)
      // showAppMenu now returns it directly
      setState(() {
        _tabOrder = result.map(_shortTabName).toList();
      });
    }
  }


  List<Item> get filteredItems {
    var list = items.where((i) {
      if (!_matchesLocationFilterForTab(i, 'Storage')) return false;
      if (_searchQuery.isNotEmpty &&
          !i.name.toLowerCase().contains(_searchQuery.toLowerCase()))
        return false;
      return true;
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Location')
      list.sort(
          (a, b) => '${a.place}/${a.bin}'.compareTo('${b.place}/${b.bin}'));
    if (_sortBy == 'Qty') list.sort((a, b) => b.qty.compareTo(a.qty));
    if (_sortBy == 'Recent') {
      list.sort((a, b) {
        final aDt = a.modifiedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDt = b.modifiedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDt.compareTo(aDt);
      });
    }
    return list;
  }


  /// Places as map-shaped rows for the existing POI list code, built
  /// from the SQLite poi_items records.
  List<Map<String, dynamic>> get _poiMaps => _poiRecords
      .map((r) => <String, dynamic>{
            'id': r.id?.toString(),
            'name': r.name,
            'lat': r.latitude,
            'lng': r.longitude,
            'address': r.address,
            'notes': r.notes,
            'photo': r.photoFilename,
            'createdAt': r.createdAt,
            'modifyDate': r.modifiedAt,
          })
      .toList();

  Future<void> _refreshSqlitePois() async {
    final records = await _poiRepo.getAll();
    if (!mounted) return;
    setState(() {
      _poiRecords = records;
    });
  }

  List<Map<String, dynamic>> get filteredPoiItems {
    var list = _poiMaps.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (m['name'] ?? '').toString().toLowerCase();
      final addr = (m['address'] ?? '').toString().toLowerCase();
      final notes = (m['notes'] ?? '').toString().toLowerCase();
      return name.contains(q) || addr.contains(q) || notes.contains(q);
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a,b) => (a['name']??'').toString().compareTo((b['name']??'').toString()));
    if (_sortBy == 'Recent') {
      DateTime tryParseDate(dynamic v) {
        if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
        try {
          if (v is DateTime) return v;
          return DateTime.tryParse(v.toString()) ?? DateTime.fromMillisecondsSinceEpoch(0);
        } catch (_) { return DateTime.fromMillisecondsSinceEpoch(0); }
      }
      list.sort((a,b) {
        final aDt = tryParseDate(a['modifyDate'] ?? a['modifiedAt'] ?? a['createdAt']);
        final bDt = tryParseDate(b['modifyDate'] ?? b['modifiedAt'] ?? b['createdAt']);
        return bDt.compareTo(aDt);
      });
    }
    return list;
  }

  List<Item> get filteredInventoryItems {
    var list = inventoryItemsList.where((i) {
      if (!_matchesLocationFilterForTab(i, 'Inventory')) return false;
      if (_searchQuery.isNotEmpty && !i.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Location') list.sort((a, b) => '${a.place}/${a.bin}'.compareTo('${b.place}/${b.bin}'));
    if (_sortBy == 'Qty') list.sort((a, b) => b.qty.compareTo(a.qty));
    if (_sortBy == 'Recent') {
      list.sort((a, b) {
        final aDt = a.modifiedAt ?? a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDt = b.modifiedAt ?? b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDt.compareTo(aDt);
      });
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        title: GestureDetector(
          onLongPress: _showShareDiagnostics,
          behavior: HitTestBehavior.opaque,
          child: Row(children: [
            Image.asset('assets/icon/app_icon.png',
                width: 48,
                height: 48,
                errorBuilder: (c, e, s) => Icon(Icons.inventory_2)),
            SizedBox(width: 8),
            RichText(
                text: TextSpan(children: [
              TextSpan(
                  text: 'Where',
                  style: AppText.logoWhere),
              TextSpan(
                  text: 'Log',
                  style: AppText.logoLogAlert),
            ])),
          ]),
        ),
        actions: [
          if (_pendingImports.isNotEmpty)
            Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  icon: ImageIcon(AssetImage('assets/icon/poi_import_icon.png'), size: 29, color: AppColors.textPrimary),
                  tooltip: 'Import',
                  onPressed: _openImportSheet,
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                    decoration: BoxDecoration(color: AppColors.alert, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.white, width: 1)),
                    constraints: const BoxConstraints(minWidth: 14, minHeight: 12),
                    child: Text('${_pendingImports.length}', style: const TextStyle(color: AppColors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                  ),
                ),
              ],
            ),
          IconButton(
              icon: Icon(Icons.menu, color: AppColors.textPrimary),
              onPressed: () => _openAppMenu())
        ]),
      body: Column(children: [
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppColors.scaffoldDark),
                                    child: TabBar(
            controller: _tabController,
            labelColor: AppColors.textPrimary,
            unselectedLabelColor: AppColors.textSecondary,
            indicator: BoxDecoration(
              color: AppColors.white,
              border: const Border(
                top: BorderSide(color: AppColors.border, width: 1),
                left: BorderSide(color: AppColors.border, width: 1),
                right: BorderSide(color: AppColors.border, width: 1),
              ),
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12), topRight: Radius.circular(12))),
            indicatorPadding: EdgeInsets.symmetric(horizontal: 4),
            indicatorSize: TabBarIndicatorSize.tab,
            labelPadding: EdgeInsets.symmetric(horizontal: 2, vertical: 6),
            labelStyle: AppText.tabSelected,
            unselectedLabelStyle: AppText.tabUnselected,
            tabs: _tabOrder.map(_tabForName).toList())),
        if (_currentTabName == 'Storage' || _currentTabName == 'Inventory') _buildSearchFilterBar(),
        Expanded(
            child: TabBarView(controller: _tabController, children: _tabOrder.map(_viewForName).toList())),
      ]),
      bottomNavigationBar: null, // Per-tab bars handle select independently
    );
  }

  /// Trial treatment (cosmetics round, 2026-11-09): the icon buttons
  /// at the top of each tab sit on an off-white rounded background so
  /// they read as buttons. The POI card's Directions button (item 5)
  /// wears the same treatment.
  ButtonStyle _tabIconBtnStyle() => IconButton.styleFrom(
        backgroundColor: AppColors.scaffoldDark,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
            // Evaluation fix E1: the app's own light border, so the
            // squares' edges are definite against the white bars.
            side: AppBorder.side),
      );

  /// The small white pill that clears a filter or a distance
  /// calculation (review round R1, 2026-11-10): the red X tried in
  /// the cosmetics round (items 6c and 7) did not please Rudy's eye
  /// in use, and there is room for the pill on both lines.
  Widget _clearPill(String label, VoidCallback onPressed) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.white,
          foregroundColor: AppColors.textSecondary,
          side: BorderSide(color: AppColors.border, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
          padding: EdgeInsets.symmetric(vertical: 2, horizontal: 8),
          elevation: 0,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          minimumSize: Size(0, 22),
        ),
        child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
      );

  Widget _buildSearchFilterBar() {
    final isStorage = _tabIndex == 0;
    final count = isStorage ? filteredItems.length : filteredInventoryItems.length;
    final hint = isStorage ? 'SEARCH STORAGE...' : 'SEARCH INVENTORY...';
    if (_searchMode) {
      return Container(
        color: AppColors.scaffold,
        padding: EdgeInsets.all(12),
                                    child: Row(children: [
          Expanded(
              child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                      hintText: hint,
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24))),
                  onChanged: (v) => setState(() => _searchQuery = v))),
          SizedBox(width: 8),
          ElevatedButton(
              onPressed: () => setState(() {
                    _searchMode = false;
                    _searchQuery = '';
                    _searchController.clear();
                  }),
                                    child: Text('DONE')),
        ]));
    }
    final isFilterActive = (_filterGeneralMap[_currentTabName] ?? 'All') != 'All' || (_filterSpecificMap[_currentTabName] != null);
    final fg = _filterGeneralMap[_currentTabName] ?? 'All';
    final fs = _filterSpecificMap[_currentTabName];
    final filterDisplay = (fs == null || fs.isEmpty) ? fg : '$fg/$fs';
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text('$count ${isStorage ? 'storage' : 'inventory'} items',
                style: AppText.countBar),
            Spacer(),
            IconButton(icon: Icon(Icons.tune, size: 29, color: AppColors.textPrimary), style: _tabIconBtnStyle(), onPressed: () => _openFilterSheet()),
            SizedBox(width: 6),
            IconButton(
                icon: Icon(Icons.search),
                style: _tabIconBtnStyle(),
                onPressed: () => setState(() => _searchMode = true)),
          ]),
          if (isFilterActive)
            Padding(
              padding: EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Text('Filter: $filterDisplay', style: TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
                  SizedBox(width: 8),
                  _clearPill('Clear Filter', () => setState(() {
                    _filterGeneralMap[_currentTabName] = 'All';
                    _filterSpecificMap[_currentTabName] = null;
                  })),
                ],
              ),
            ),
        ],
      ));
  }

  // === MULTIPLE SETS OF BUTTONS RESIDING ON TABS - each tab owns its own set ===
  Widget _buildStorageTab() {
    final isSel = _isSelectMode('Storage');
    return Container(
      color: AppColors.scaffold,
                                    child: Column(children: [
        Expanded(child: _buildStorageList()),
        isSel ? _buildSelectActionBarFor('Storage') : _buildStorageActionBar(),
      ]));
  }

  Widget _buildInventoryTab() {
    final isSel = _isSelectMode('Inventory');
    return Container(
      color: AppColors.scaffold,
                                    child: Column(children: [
        Expanded(child: _buildInventoryList()),
        isSel ? _buildSelectActionBarFor('Inventory') : _buildInventoryActionBar(),
      ]));
  }

  Widget _buildPoiTopBar() {
    final count = filteredPoiItems.length;
    final pending = _pendingImports.length;
    if (_searchMode) {
      return Container(
        color: AppColors.scaffold,
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'SEARCH PLACES...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24)),
              ),
              onChanged: (v) => setState(() => _searchQuery = v),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => setState(() {
              _searchMode = false;
              _searchQuery = '';
              _searchController.clear();
            }),
            child: const Text('DONE'),
          ),
        ]),
      );
    }
    final text = '$count places';
    return Container(
      color: AppColors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(children: [
        Expanded(child: Text(text, style: AppText.countBar, overflow: TextOverflow.ellipsis)),
        IconButton(
          icon: ImageIcon(AssetImage('assets/icon/calc_distance_icon.png'), size: 29, color: AppColors.textPrimary),
          style: _tabIconBtnStyle(),
          tooltip: currentLat == null ? 'Calc distance' : 'Clear location',
          onPressed: () {
            if (currentLat != null) {
              setState(() { currentLat = null; currentLng = null; });
            } else {
              fetchCurrentForDistance();
            }
          },
        ),
        const SizedBox(width: 6),
        Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: ImageIcon(AssetImage('assets/icon/poi_import_icon.png'), size: 29, color: AppColors.textPrimary),
              style: _tabIconBtnStyle(),
              tooltip: 'Import',
              onPressed: _openImportSheet,
            ),
            if (pending > 0)
              Positioned(
                right: -4,
                top: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                  decoration: BoxDecoration(color: AppColors.alert, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.white, width: 1)),
                  constraints: const BoxConstraints(minWidth: 14, minHeight: 12),
                  child: Text('$pending', style: const TextStyle(color: AppColors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                ),
              ),
          ],
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: ImageIcon(AssetImage('assets/icon/poi_map_icon.png'), size: 29, color: AppColors.textPrimary),
          style: _tabIconBtnStyle(),
          tooltip: 'Map view - 25 mi default radius',
          onPressed: () {
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiMapScreen()));
          },
        ),
        const SizedBox(width: 6),
        IconButton(
          icon: const Icon(Icons.search, size: 29, color: AppColors.textPrimary),
          style: _tabIconBtnStyle(),
              tooltip: 'Search places',
          onPressed: () => setState(() => _searchMode = true),
        ),
      ]),
    );
  }

  Widget _buildPoiTab() {
    final isSel = _isSelectMode('POI');
    return Container(
      color: AppColors.scaffold,
                                    child: Column(children: [
        Expanded(child: _buildPoiList()),
        isSel ? _buildSelectActionBarFor('POI') : _buildPoiActionBar(),
      ]));
  }

  Widget _buildPoiList() {
    return Container(
      color: AppColors.scaffold,
                                    child: Column(
        children: [
          _buildPoiTopBar(),
          if (currentLat != null)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
              // Below the icon bar, filter-line style (cosmetics round,
              // item 6): the distance button's own icon instead of the
              // word 'Distance'; the pill after the coords clears the
              // calculation (review round R1 — the red X from items 6c
              // and 7 is retired on both lines).
              child: Row(children: [
                ImageIcon(AssetImage('assets/icon/calc_distance_icon.png'), size: 16, color: AppColors.textSecondary),
                SizedBox(width: 4),
                Text('from: ${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)}', style: AppText.dialog),
                SizedBox(width: 8),
                _clearPill('Clear', () => setState(() { currentLat = null; currentLng = null; })),
              ])),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(6, 0, 6, 12),
              itemCount: filteredPoiItems.length,
              itemBuilder: (c, i) {
                final poi = filteredPoiItems[i];
                final name = (poi['name'] ?? 'Unnamed').toString();
                final lat = (poi['lat'] is num) ? (poi['lat'] as num).toDouble() : double.tryParse(poi['lat']?.toString() ?? '');
                final lng = (poi['lng'] is num) ? (poi['lng'] as num).toDouble() : double.tryParse(poi['lng']?.toString() ?? '');
                final coords = (lat != null && lng != null) ? '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}' : 'No GPS';
                final address = (poi['address'] ?? '').toString();
                final distM = calcDistanceMeters(lat, lng);
                final distStr = formatDistance(distM);
                final poiId = (poi['id'] ?? poi['name'] ?? '').toString();
                final isSelected = _idsFor('POI').contains(poiId);
                return Card(
                  margin: EdgeInsets.only(bottom: 8),
                  color: isSelected ? AppColors.cardSelected : AppColors.card,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                                    child: ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 6),
                    onTap: () async {
                      if (_isSelectMode('POI')) {
                        setState(() {
                          if (isSelected) _selectedIdsMap['POI']!.remove(poiId);
                          else _selectedIdsMap['POI']!.add(poiId);
                        });
                        return;
                      }
                      final editId = int.tryParse(poi['id']?.toString() ?? '');
                      if (editId == null) return;
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiEditScreen(poiId: editId)));
                      if (mounted) {
                        await _refreshSqlitePois();
                      }
                    },
                    leading: _isSelectMode('POI')
                        ? Checkbox(value: isSelected, onChanged: (v) => setState(() { if (v == true) _selectedIdsMap['POI']!.add(poiId); else _selectedIdsMap['POI']!.remove(poiId); }))
                        : null,
              title: Text(name, style: AppText.cardTitle),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(height: 4),
                      // Directions rides the coords row, at its right
                      // end, wearing the tab-icon treatment (cosmetics
                      // round, items 3 + 5).
                      Row(children: [
                        Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: AppColors.scaffoldDark, borderRadius: BorderRadius.circular(AppRadius.tabIndicator)), child: Text(coords, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                        SizedBox(width: 6),
                        if (!_isSelectMode('POI') && MapUtils.hasCoordinates(lat, lng))
                          IconButton(
                            icon: ImageIcon(AssetImage('assets/icon/directions_diamond.png'), size: 26, color: AppColors.buttonBg),
                            tooltip: 'Navigate',
                            style: _tabIconBtnStyle(),
                            onPressed: () {
                              MapUtils.openDirections(lat: lat!, lng: lng!, label: name);
                            },
                          ),
                      ]),
                      // The card's distance, while a calculation is
                      // active (review round R2): the distance icon in
                      // front, in its natural black, and the text in
                      // the header blue instead of alert red. Icon and
                      // text come and go together with the state.
                      if (distStr.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Row(children: [
                        ImageIcon(AssetImage('assets/icon/calc_distance_icon.png'), size: 16),
                        SizedBox(width: 4),
                        Text(distStr, style: AppText.dialogDistance),
                      ])),
                      if (address.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Text(address, style: AppText.dialog, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ])));
              })),
        ]));
  }

  Widget _buildStorageActionBar() {
    return Container(
      color: AppColors.white,
      // Bottom padding 12 -> 2: the tab's buttons sit 10px lower
      // (cosmetics round, item 1). Same change in every action bar.
      padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                                    child: SafeArea(
        child: Row(children: [
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('storage_select'),
                  onPressed: () => _enterSelectMode('Storage'),
                                    child: Text('SELECT'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
          SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('storage_add_item'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => StorageAddScreen()));
                    if (mounted) {
                      await _refreshSqliteStorage();
                    }
                  },
                                    child: Text('+ Add'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
        ])));
  }

  Widget _buildInventoryActionBar() {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                                    child: SafeArea(
        child: Row(children: [
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('inventory_select'),
                  onPressed: () => _enterSelectMode('Inventory'),
                                    child: Text('SELECT'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
          SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('inventory_add_item'),
                  onPressed: () async {
                    await Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => InventoryAddScreen()));
                    if (mounted) {
                      await _refreshSqliteInventory();
                    }
                  },
                                    child: Text('+ Add'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
        ])));
  }

  Widget _buildPoiActionBar() {
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                                    child: SafeArea(
        child: Row(children: [
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('poi_select'),
                  onPressed: () => _enterSelectMode('POI'),
                                    child: Text('SELECT'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
          SizedBox(width: 12),
          Expanded(
              child: ElevatedButton(
                  key: ValueKey('poi_add_item'),
                  onPressed: () async {
                    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiAddScreen()));
                    if (mounted) {
                      await _refreshSqlitePois();
                    }
                  },
                                    child: Text('+ Add'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
        ])));
  }

  Widget _buildNormalBottomBar() {
    // Deprecated - buttons now reside on tabs per instruction
    return SizedBox.shrink();
  }

    Widget _buildSelectActionBarFor(String tabName) {
    final selectedCount = _selectedCountFor(tabName);
    return Container(
      color: AppColors.white,
      padding: EdgeInsets.fromLTRB(16, 12, 16, 2),
                                    child: SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('$selectedCount selected in $tabName', style: TextStyle(fontWeight: FontWeight.w800)),
          SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: ElevatedButton(
                key: ValueKey('${tabName.toLowerCase()}_cancel'),
                onPressed: () => _exitSelectMode(tabName),
                                    child: Text('CANCEL'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)))),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                key: ValueKey('${tabName.toLowerCase()}_move'),
                onPressed: selectedCount == 0 ? null : () => _moveSelectedItems(tabName),
                                    child: Text('MOVE'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)))),
            SizedBox(width: 8),
            Expanded(
              child: ElevatedButton(
                key: ValueKey('${tabName.toLowerCase()}_delete'),
                onPressed: selectedCount == 0 ? null : () => _deleteSelectedItems(tabName),
                                    child: Text('DELETE'),
                style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 14)))),
          ]),
        ])));
  }

  Widget _buildSelectBottomBar() {
    return _buildSelectActionBarFor(_currentTabName);
  }


  Widget _buildStorageList() {
    return Container(
      color: AppColors.scaffold,
                                    child: ListView.builder(
        padding: EdgeInsets.fromLTRB(6, 12, 6, 12),
        itemCount: filteredItems.length,
        itemBuilder: (c, i) {
          final item = filteredItems[i];
          final isSelected = _idsFor('Storage').contains(item.id);
          final locationLabel =
              item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: isSelected ? AppColors.cardSelected : AppColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                                    child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 6),
              onTap: () async {
                if (_isSelectMode('Storage')) {
                  setState(() {
                    if (isSelected) _selectedIdsMap['Storage']!.remove(item.id);
                    else _selectedIdsMap['Storage']!.add(item.id);
                  });
                  return;
                }
                final itemId = int.tryParse(item.id);
                if (itemId == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => StorageEditScreen(itemId: itemId)));
                if (mounted) {
                  await _refreshSqliteStorage();
                }
              },
              leading: _isSelectMode('Storage')
                  ? Checkbox(value: isSelected, onChanged: (v) => setState(() {
                      if (v == true) _selectedIdsMap['Storage']!.add(item.id);
                      else _selectedIdsMap['Storage']!.remove(item.id);
                    }))
                  : null,
              title: Text(item.qty == 1 ? item.name : '(${item.qty}) ${item.name}',
                  style: AppText.cardTitle),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: AppColors.scaffoldDark,
                      borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Text(locationLabel,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600)))));
        }));
  }

  Widget _buildInventoryList() {
    return Container(
      color: AppColors.scaffold,
                                    child: ListView.builder(
        padding: EdgeInsets.fromLTRB(6, 12, 6, 12),
        itemCount: filteredInventoryItems.length,
        itemBuilder: (c, i) {
          final item = filteredInventoryItems[i];
          final isSelected = _idsFor('Inventory').contains(item.id);
          final locationLabel = item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: isSelected ? AppColors.cardSelected : AppColors.card,
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                                    child: ListTile(
              contentPadding: EdgeInsets.symmetric(horizontal: 6),
              onTap: () async {
                if (_isSelectMode('Inventory')) {
                  setState(() {
                    if (isSelected) _selectedIdsMap['Inventory']!.remove(item.id);
                    else _selectedIdsMap['Inventory']!.add(item.id);
                  });
                  return;
                }
                final itemId = int.tryParse(item.id);
                if (itemId == null) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InventoryEditScreen(itemId: itemId)));
                if (mounted) {
                  await _refreshSqliteInventory();
                }
              },
              leading: _isSelectMode('Inventory')
                  ? Checkbox(value: isSelected, onChanged: (v) => setState(() {
                      if (v == true) _selectedIdsMap['Inventory']!.add(item.id);
                      else _selectedIdsMap['Inventory']!.remove(item.id);
                    }))
                  : null,
              title: Text(item.qty == 1 ? item.name : '(${item.qty}) ${item.name}', style: AppText.cardTitle),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.scaffoldDark, borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Text(locationLabel, style: AppText.cardLocation))));
        }));
  }

  Future<void> _openFilterSheet() async {
    await _locationData.load();
    if (!mounted) return;
    final bool isStorageTab = _currentTabName == 'Storage';
    String modalGeneral = _filterGeneralMap[_currentTabName] ?? 'All';
    String? modalSpecific = _filterSpecificMap[_currentTabName];

    showModalTopSheet(
      context: context,
      maxWidth: 420,
      builder: (c, setModal) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              Text(AppText.upper('Filter & Sort'), style: AppText.dialogTitle),
              Spacer(),
              IconButton(icon: Icon(Icons.close), onPressed: () => Navigator.pop(c))
            ]),
            SizedBox(height: 16),
            LocationFilterSection(
              data: _locationData,
              isStorage: isStorageTab,
              selectedGeneral: modalGeneral,
              selectedSpecific: modalSpecific,
              onGeneralChanged: (v) => setModal(() {
                modalGeneral = v;
                modalSpecific = null;
              }),
              onSpecificChanged: (v) => setModal(() => modalSpecific = v),
            ),
            SizedBox(height: 16),
            Text('SORT BY',
                style: AppText.dialogSection),
            SizedBox(height: 8),
            Wrap(
                spacing: 6,
                runSpacing: 4,
                children: ['Recent', 'Name A-Z', 'Location A-Z'].map((s) {
                  final sel = _sortBy == s || (s == 'Location A-Z' && _sortBy == 'Location');
                  return Padding(
                    padding: const EdgeInsets.only(right: 0, bottom: 2),
                    child: ElevatedButton(
                      onPressed: () => setModal(() {
                        // Map Location A-Z to Location for backward compat
                        _sortBy = (s == 'Location A-Z') ? 'Location' : s;
                      }),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sel ? AppColors.buttonBg : AppColors.white,
                        foregroundColor: sel ? AppColors.white : AppColors.textSecondary,
                        side: BorderSide(color: sel ? AppColors.buttonBg : AppColors.border, width: sel ? AppBorder.sideSelected.width : AppBorder.width),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                        elevation: sel ? 1 : 0,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size(0, 26),
                      ),
                      child: Text(s, style: TextStyle(fontWeight: sel ? FontWeight.w800 : FontWeight.w600, fontSize: 11, letterSpacing: 0.1)),
                    ),
                  );
                }).toList()),
            SizedBox(height: 20),
            Row(children: [
              Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterGeneralMap[_currentTabName] = 'All';
                          _filterSpecificMap[_currentTabName] = null;
                          _sortBy = 'Recent';
                        });
                        Navigator.pop(c);
                      },
                      child: Text('RESET'))),
              SizedBox(width: 12),
              Expanded(
                  child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _filterGeneralMap[_currentTabName] = modalGeneral;
                          _filterSpecificMap[_currentTabName] = modalSpecific;
                        });
                        Navigator.pop(c);
                      },
                      child: Text('APPLY'))),
            ]),
          ],
        );
      },
    );
  }

  Future<void> _moveSelectedItems([String? tabName]) async {
    final String effectiveTab = tabName ?? _currentTabName;
    final Set<String> currentSelected = _selectedIdsMap[effectiveTab] ?? <String>{};
    if (currentSelected.isEmpty) return;
    await _refreshSqliteLocations();
    final placesList = _placesFromLocations();
    String? selectedPlace;
    String? selectedBin;
    final confirmed = await showModalTopSheet<bool>(
      context: context,
      maxWidth: 420,
      builder: (c, setModal) {
        final bins = selectedPlace == null
            ? <String>[]
            : placesList
                .firstWhere((p) => p.name == selectedPlace, orElse: () => Place(name: '', bins: []))
                .bins
                .map((b) => b.name)
                .toList();
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('MOVE ${currentSelected.length} ITEMS',
                  style: AppText.dialogTitle),
              SizedBox(height: 16),
              DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Place', border: OutlineInputBorder()),
                  value: selectedPlace,
                  items: placesList.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                  onChanged: (v) => setModal(() {
                        selectedPlace = v;
                        selectedBin = null;
                      })),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                  decoration: InputDecoration(labelText: 'Bin (optional)', border: OutlineInputBorder()),
                  value: selectedBin,
                  items: bins.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                  onChanged: (v) => setModal(() => selectedBin = v)),
              SizedBox(height: 20),
              Row(children: [
                Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL'))),
                SizedBox(width: 12),
                Expanded(
                    child: ElevatedButton(
                        onPressed: selectedPlace == null ? null : () => Navigator.pop(c, true),
                        child: Text('MOVE'))),
              ])
            ]);
      },
    );
    if (confirmed != true || selectedPlace == null) return;
      // Apply move for current tab items
      if (effectiveTab == 'Storage') {
        // Resolve the chosen place/bin names to SQLite location ids from
        // the cached records (the tree they were picked from is built
        // from the same records). No bin chosen means "General only":
        // specific_id is set to null (schema D1).
        int? genId;
        for (final g in _sqlGenerals) {
          if (g.name == selectedPlace) { genId = g.id; break; }
        }
        int? specId;
        if (genId != null && selectedBin != null) {
          for (final s in _sqlStorageSpecifics) {
            if (s.generalId == genId && s.name == selectedBin) { specId = s.id; break; }
          }
        }
        if (genId != null) {
          for (final idStr in currentSelected.toList()) {
            final id = int.tryParse(idStr);
            if (id != null) await _storageRepo.updateLocation(id, genId, specId);
          }
        }
        await _refreshSqliteStorage();
        setState(() { _selectModes['Storage'] = false; _selectedIdsMap['Storage']!.clear(); });
      } else if (effectiveTab == 'Inventory') {
        int? genId;
        for (final g in _sqlGenerals) {
          if (g.name == selectedPlace) { genId = g.id; break; }
        }
        int? specId;
        if (genId != null && selectedBin != null) {
          for (final s in _sqlInventorySpecifics) {
            if (s.generalId == genId && s.name == selectedBin) { specId = s.id; break; }
          }
        }
        if (genId != null) {
          for (final idStr in currentSelected.toList()) {
            final id = int.tryParse(idStr);
            if (id != null) await _invRepo.updateLocation(id, genId, specId);
          }
        }
        await _refreshSqliteInventory();
        setState(() { _selectModes['Inventory'] = false; _selectedIdsMap['Inventory']!.clear(); });
      } else if (effectiveTab == 'POI') {
        setState(() { _selectModes['POI'] = false; _selectedIdsMap['POI']!.clear(); });
      }
  }

  Future<void> _deleteSelectedItems([String? tabName]) async {
    final String effectiveTab = tabName ?? _currentTabName;
    final Set<String> currentSelected = _selectedIdsMap[effectiveTab] ?? <String>{};
    if (currentSelected.isEmpty) return;
    final confirmed = await showModalTopSheet<bool>(
      context: context,
      maxWidth: 360,
      builder: (c, _) {
        return Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.alert),
          SizedBox(height: 12),
          Text('Delete ${currentSelected.length} items?',
              style: AppText.dialogTitleAlert),
          SizedBox(height: 8),
          Text('This cannot be undone.', style: AppText.dialogAlert),
          SizedBox(height: 20),
          Row(children: [
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL'))),
            SizedBox(width: 12),
            Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, true), child: Text('DELETE'))),
          ])
        ]);
      },
    );
    if (confirmed != true) return;
    if (effectiveTab == 'Storage') {
      final ids = <int>[];
      final photoNames = <String>[];
      for (final idStr in currentSelected) {
        final id = int.tryParse(idStr);
        if (id == null) continue;
        ids.add(id);
        for (final r in _storageRecords) {
          if (r.id == id && r.photoFilename != null) photoNames.add(r.photoFilename!);
        }
      }
      await _storageRepo.deleteMany(ids);
      for (final n in photoNames) {
        await PhotoStore.deletePhoto(n);
      }
      await _refreshSqliteStorage();
      setState(() { _selectModes['Storage'] = false; _selectedIdsMap['Storage']!.clear(); });
    } else if (effectiveTab == 'Inventory') {
      final ids = <int>[];
      final photoNames = <String>[];
      for (final idStr in currentSelected) {
        final id = int.tryParse(idStr);
        if (id == null) continue;
        ids.add(id);
        for (final r in _inventoryRecords) {
          if (r.id == id && r.photoFilename != null) photoNames.add(r.photoFilename!);
        }
      }
      await _invRepo.deleteMany(ids);
      for (final n in photoNames) {
        await PhotoStore.deletePhoto(n);
      }
      await _refreshSqliteInventory();
      setState(() { _selectModes['Inventory'] = false; _selectedIdsMap['Inventory']!.clear(); });
    } else if (effectiveTab == 'POI') {
      final ids = <int>[];
      final photoNames = <String>[];
      for (final idStr in currentSelected) {
        final id = int.tryParse(idStr);
        if (id == null) continue;
        ids.add(id);
        for (final r in _poiRecords) {
          if (r.id == id && r.photoFilename != null) photoNames.add(r.photoFilename!);
        }
      }
      await _poiRepo.deleteMany(ids);
      for (final n in photoNames) {
        await PhotoStore.deletePhoto(n);
      }
      await _refreshSqlitePois();
      setState(() { _selectModes['POI'] = false; _selectedIdsMap['POI']!.clear(); });
    }
  }

  
  
}

class Place {
  String name;
  List<Bin> bins;
  Place({required this.name, required this.bins});
}

class Bin {
  String name;
  Bin({required this.name});
}

class Item {
  String id;
  String name;
  int qty;
  String place;
  String? bin;
  String emoji;
  DateTime? createdAt;
  DateTime? modifiedAt;
  String? generalId;
  String? specificId;
  Item(
      {required this.id,
      required this.name,
      required this.qty,
      required this.place,
      this.bin,
      required this.emoji,
      this.createdAt,
      this.modifiedAt,
      this.generalId,
      this.specificId});
}

class LocationsSheet extends StatefulWidget {
  final List<Place> places;
  LocationsSheet({required this.places});
  @override
  State<LocationsSheet> createState() => _LocationsSheetState();
}

class _LocationsSheetState extends State<LocationsSheet> {
  bool editMode = false;
  Set<String> expanded = {'Garage'};
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
        initialChildSize: 0.9,
        expand: false,
        builder: (c, scroll) {
          return SingleChildScrollView(
              controller: scroll,
                                    child: Padding(
                padding: EdgeInsets.all(16),
                                    child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                                color: AppColors.textPrimary, shape: BoxShape.circle),
                                    child:
                                Icon(Icons.location_on, color: AppColors.white)),
                        SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Locations',
                                  style: AppText.dialogTitle),
                              Text('Place / Room → Bin / Area • distinct bins',
                                  style: AppText.dialog)
                            ])),
                        IconButton(
                            icon: Icon(Icons.close),
                            onPressed: () => Navigator.pop(context))
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Chip(label: Text('Storage 5')),
                        SizedBox(width: 8),
                        Chip(label: Text('Inventory 5'))
                      ]),
                      SizedBox(height: 12),
                      Row(children: [
                        Text('MODE',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                        SizedBox(width: 8),
                        Chip(
                            label: Text(editMode ? 'EDIT MODE' : 'VIEW SAFE'),
                            backgroundColor: AppColors.border),
                        Spacer(),
                        Text('default: View',
                            style:
                                AppText.dialog)
                      ]),
                      SizedBox(height: 8),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: AppColors.border, width: AppBorder.width),
                              borderRadius: BorderRadius.circular(24)),
                          padding: EdgeInsets.all(4),
                                    child: Row(children: [
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: () =>
                                        setState(() => editMode = false),
                                    child: Text('View'),
                                    )),
                            Expanded(
                                child: ElevatedButton(
                                    onPressed: () =>
                                        setState(() => editMode = true),
                                    child: Text('Edit'),
                                    )),
                          ])),
                      SizedBox(height: 12),
                      Text(
                          editMode
                              ? 'Edit: Tap name to edit (Return saves), X deletes (confirm if has bins), blanks: "Type new Place..." + "Type new Bin for Garage..."'
                              : 'View: Safe browsing only — chevron expands, peruse tree, no blanks, no edit, no delete.',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w600)),
                      SizedBox(height: 12),
                      Container(
                          padding: EdgeInsets.all(12),
                          color: AppColors.scaffold,
                                    child: Row(children: [
                            Icon(Icons.error, size: 20),
                            SizedBox(width: 8),
                            Expanded(
                                child: Text(
                                    '2 tiers: Place required → Bin optional inside Place. Garage / Bin 1 ≠ Attic / Bin 1.',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold)))
                          ])),
                      ...widget.places.map((p) {
                        final isExp = expanded.contains(p.name);
                        return Card(
                            margin: EdgeInsets.only(top: 8),
                                    child: Column(children: [
                              ListTile(
                                  leading: IconButton(
                                      icon: Icon(isExp
                                          ? Icons.keyboard_arrow_down
                                          : Icons.chevron_right),
                                      onPressed: () => setState(() => isExp
                                          ? expanded.remove(p.name)
                                          : expanded.add(p.name))),
                                  title: Row(children: [
                                    Text(p.name,
                                        style: TextStyle(
                                            fontWeight: FontWeight.w800)),
                                    SizedBox(width: 8),
                                    Chip(label: Text('${p.bins.length}'))
                                  ]),
                                  trailing: editMode
                                      ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                              Icon(Icons.edit_outlined,
                                                  size: 18),
                                              SizedBox(width: 8),
                                              Icon(Icons.close,
                                                  color: AppColors.alert, size: 18)
                                            ])
                                      : null),
                              if (isExp)
                                ...p.bins.map((b) => Padding(
                                    padding: EdgeInsets.only(
                                        left: 40, right: 12, bottom: 8),
                                    child: Container(
                                        padding: EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                            border: Border.all(
                                                color: AppColors.border),
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                    child: Row(children: [
                                          Text('${b.name} - ',
                                              style: TextStyle(
                                                  fontWeight: FontWeight.w800)),
                                          Text('${p.name} / ${b.name}',
                                              style: TextStyle(
                                                  fontFamily: 'monospace'))
                                        ])))),
                            ]));
                      }).toList(),
                      SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                            child: OutlinedButton(
                                onPressed: () => Navigator.pop(context),
                                    child: Text('Done'))),
                        SizedBox(width: 12),
                        Expanded(
                            child: Text(
                                '${widget.places.length} Place • Bin • storage • ${editMode ? 'Edit combined' : 'View safe'}',
                                style: TextStyle(fontWeight: FontWeight.bold)))
                      ])
                    ])));
        });
  }
}
