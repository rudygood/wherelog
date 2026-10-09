import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'screens/storage_add_screen.dart';
import 'widgets/app_sheet.dart';
import 'screens/location_options_maintenance_screen.dart';
import 'screens/storage_edit_screen.dart';
import 'screens/inventory_add_screen.dart';
import 'screens/inventory_edit_screen.dart';
import 'screens/poi_add_screen.dart';
import 'screens/poi_edit_screen.dart';
import 'wherelog_repository.dart';
import 'theme/app_theme.dart';
import 'settings_service.dart';
import 'dart:convert';
import 'dart:io';

Future<void> migrateWherelogData() async {
  if (kIsWeb) return;
  try {
    final newDir = await getApplicationDocumentsDirectory();
    final newWhereLogDir = Directory('${newDir.path}/WhereLog');
    if (!newWhereLogDir.existsSync()) await newWhereLogDir.create(recursive: true);
    final newFile = File('${newWhereLogDir.path}/wherelog_data.json');
    if (newFile.existsSync()) return;
    final oldDocDir = Directory('${Platform.environment['USERPROFILE']}\\Documents');
    final oldFile = File('${oldDocDir.path}\\wherelog_data.json');
    if (!oldFile.existsSync()) return;
    final raw = jsonDecode(await oldFile.readAsString()) as Map<String, dynamic>;
    if (raw.containsKey('storageGenerals')) {
      await newFile.writeAsString(await oldFile.readAsString());
      return;
    }
  } catch (e) { print("Migration error $e"); }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await migrateWherelogData();
  await WhereLogRepository().load();
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
  String _filterBy = 'All';
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
  final WhereLogRepository _repo = WhereLogRepository();
  double? currentLat;
  double? currentLng;
  bool _isLoadingLocation = false;

  List<Place> places = [];
  List<Item> items = [];

  List<Place> _placesFromRepo() {
    // v9: single generals + both specific types merged for tree view
    final Map<String, List<String>> generalsMap = {};
    final Map<String, String> genIdToName = {};
    for (var g in _repo.generals) {
      if (g is Map) {
        final id = g['id']?.toString() ?? '';
        final name = g['name']?.toString() ?? '';
        if (id.isNotEmpty && name.isNotEmpty) {
          genIdToName[id] = name;
          generalsMap.putIfAbsent(name, () => []);
        }
      }
    }
    for (var s in _repo.storageSpecifics) {
      if (s is Map) {
        final genId = s['generalId']?.toString() ?? '';
        final name = s['name']?.toString() ?? '';
        if (name.trim().isEmpty) continue;
        final genName = genIdToName[genId];
        if (genName != null) {
          generalsMap.putIfAbsent(genName, () => []);
          if (!generalsMap[genName]!.contains(name)) generalsMap[genName]!.add(name);
        }
      }
    }
    for (var s in _repo.inventorySpecifics) {
      if (s is Map) {
        final genId = s['generalId']?.toString() ?? '';
        final name = s['name']?.toString() ?? '';
        if (name.trim().isEmpty) continue;
        final genName = genIdToName[genId];
        if (genName != null) {
          generalsMap.putIfAbsent(genName, () => []);
          if (!generalsMap[genName]!.contains(name)) generalsMap[genName]!.add(name);
        }
      }
    }

    if (generalsMap.isEmpty) {
      debugPrint('WARNING: _placesFromRepo empty - check generals');
      return [];
    }

    final list = <Place>[];
    generalsMap.forEach((place, binsSet) {
      list.add(Place(name: place, bins: binsSet.map((b) => Bin(name: b)).toList()));
    });
    return list;
  }


    List<Item> _itemsFromRepo() {
    if (_repo.storageItems.isEmpty) {
      debugPrint('WARNING: storageItems empty');
      return [];
    }

    final Map<String, Map<String, String>> specLookup = {};
    try {
      final Map<String, String> genIdToName = {};
      for (var g in _repo.generals) {
        if (g is Map) genIdToName[g['id']?.toString() ?? ''] = g['name']?.toString() ?? '';
      }
      for (var s in _repo.storageSpecifics) {
        if (s is Map) {
          final specId = s['id']?.toString() ?? '';
          final genId = s['generalId']?.toString() ?? '';
          final specName = s['name']?.toString() ?? '';
          final genName = genIdToName[genId] ?? '';
          if (specId.isNotEmpty) {
            specLookup[specId] = {'place': genName, 'bin': specName};
          }
        }
      }
    } catch (e) {
      debugPrint('specLookup build failed: $e');
    }

    return _repo.storageItems.map((m) {
      final id = m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String place = '';
      String? bin;
      final specId = m['specificId']?.toString();
      final genId = m['generalId']?.toString();
      if (specId != null && specLookup.containsKey(specId)) {
        place = specLookup[specId]!['place'] ?? '';
        final b = specLookup[specId]!['bin'] ?? '';
        bin = b.isEmpty ? null : b;
      } else if (genId != null) {
        // fallback resolve via generalId
        place = _repo.generalNameForId(genId);
        // try to find specific name directly
        final spec = _repo.storageSpecifics.firstWhere((s) => s['id'] == specId, orElse: () => {});
        final bn = spec['name']?.toString() ?? '';
        bin = bn.isEmpty ? null : bn;
      }
      return Item(
        id: id,
        name: m['name'] ?? 'Unnamed',
        qty: (m['qty'] is int) ? m['qty'] : int.tryParse(m['qty']?.toString() ?? '1') ?? 1,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '📦');
    }).toList();
  }


    int _findRepoIndexForItem(Item item) {
    // Find by id first, then by name+place+bin
    int idx =
        _repo.storageItems.indexWhere((m) => m['id']?.toString() == item.id);
    if (idx >= 0) return idx;
    // v9: only generalId/specificId + name based - place/bin resolved via lookup
    idx = _repo.storageItems.indexWhere((m) => (m['name'] == item.name && _repo.generalNameForId(m['generalId']?.toString() ?? '') == item.place));
    return idx;
  }

  List<Item> _inventoryItemsFromRepo() {
    if (_repo.inventoryItems.isEmpty) {
      debugPrint('WARNING: inventoryItems empty');
      return [];
    }
    final Map<String, Map<String, String>> specLookup = {};
    try {
      final Map<String, String> genIdToName = {};
      for (var g in _repo.generals) {
        if (g is Map) genIdToName[g['id']?.toString() ?? ''] = g['name']?.toString() ?? '';
      }
      for (var s in _repo.inventorySpecifics) {
        if (s is Map) {
          final specId = s['id']?.toString() ?? '';
          final genId = s['generalId']?.toString() ?? '';
          final specName = s['name']?.toString() ?? '';
          final genName = genIdToName[genId] ?? '';
          if (specId.isNotEmpty) {
            specLookup[specId] = {'place': genName, 'bin': specName};
          }
        }
      }
    } catch (e) {
      debugPrint('inventory specLookup failed: $e');
    }
    return _repo.inventoryItems.map((m) {
      final id = m['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString();
      String place = '';
      String? bin;
      final specId = m['specificId']?.toString();
      final genId = m['generalId']?.toString();
      if (specId != null && specLookup.containsKey(specId)) {
        place = specLookup[specId]!['place'] ?? '';
        final b = specLookup[specId]!['bin'] ?? '';
        bin = b.isEmpty ? null : b;
      } else if (genId != null) {
        place = _repo.generalNameForId(genId);
        final spec = _repo.inventorySpecifics.firstWhere((s) => s['id'] == specId, orElse: () => {});
        final bn = spec['name']?.toString() ?? '';
        bin = bn.isEmpty ? null : bn;
      }
      return Item(
        id: id,
        name: m['name'] ?? 'Unnamed',
        qty: (m['qty'] is int) ? m['qty'] : int.tryParse(m['qty']?.toString() ?? '1') ?? 1,
        place: place.isEmpty ? 'Garage' : place,
        bin: bin,
        emoji: '🪑');
    }).toList();
  }


    Future<void> fetchCurrentForDistance() async {
    setState(() => _isLoadingLocation = true);
    try { await Future.delayed(const Duration(milliseconds: 300)); }
    finally { if (mounted) setState(() => _isLoadingLocation = false); }
  }

  double? calcDistanceMeters(double? lat, double? lng) {
    if (currentLat == null || currentLng == null || lat == null || lng == null) return null;
    return null;
  }

  String formatDistance(double? meters) {
    if (meters == null) return '';
    if (meters < 1000) return '${meters.toStringAsFixed(0)} m';
    final km = meters / 1000;
    final miles = meters / 1609.34;
    return '${km.toStringAsFixed(1)} km / ${miles.toStringAsFixed(1)} mi';
  }

  int _findPoiRepoIndex(Map<String, dynamic> poi) {
    final id = poi['id']?.toString();
    if (id == null) return -1;
    for (int i=0; i<_repo.poiItems.length; i++) {
      if (_repo.poiItems[i]['id']?.toString() == id) return i;
    }
    return -1;
  }

  int _findInventoryRepoIndexForItem(Item item) {
    int idx = _repo.inventoryItems.indexWhere((m) => m['id']?.toString() == item.id);
    if (idx >= 0) return idx;
    idx = _repo.inventoryItems.indexWhere((m) => (m['name'] == item.name && _repo.generalNameForId(m['generalId']?.toString() ?? '') == item.place));
    return idx;
  }

  List<Item> _inventoryPlaces = [];
  List<Item> _inventoryItemsList = [];


  List<Item> inventoryItemsList = [];


  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() => setState(() => _tabIndex = _tabController.index));
    places = _placesFromRepo();
    items = _itemsFromRepo();
    inventoryItemsList = _inventoryItemsFromRepo();
    _repo.load().then((_) {
      if (mounted)
        setState(() {
          places = _placesFromRepo();
          items = _itemsFromRepo();
          inventoryItemsList = _inventoryItemsFromRepo();
        });
    });
    _loadTabOrder();
  }

  Future<void> _loadTabOrder() async {
    try {
      final order = await SettingsService().getTabOrder();
      if (order.length == 3 && mounted) {
        setState(() => _tabOrder = List<String>.from(order));
      }
    } catch (_) {}
  }

  String get _currentTabName {
    if (_tabIndex >=0 && _tabIndex < _tabOrder.length) return _tabOrder[_tabIndex];
    return _tabOrder.isNotEmpty ? _tabOrder[0] : 'Storage';
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
    if (name == 'Storage') return _buildStorageTab();
    if (name == 'Inventory') return _buildInventoryTab();
    if (name == 'POI') return _buildPoiTab();
    return _buildStorageTab();
  }

  Future<void> _openAppMenu() async {
    // NEW: uses showAppMenu right-sheet 78% instead of bottom sheet
    final result = await showAppMenu(context);
    // Preserve existing behavior - reload tab order after menu / settings
    _loadTabOrder();
    // If settings returned a new tab order, propagate it if needed
    if (result is List<String> && result.length == 3) {
      // Original shell returned result via Navigator.pop(context, result)
      // showAppMenu now returns it directly
      setState(() {
        _tabOrder = result;
      });
    }
  }


  List<Item> get filteredItems {
    var list = items.where((i) {
      if (_filterBy != 'All' &&
          _filterBy != 'Important' &&
          i.place != _filterBy) return false;
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
    return list;
  }


  List<Map<String, dynamic>> get filteredPoiItems {
    var list = _repo.poiItems.where((m) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      final name = (m['name'] ?? '').toString().toLowerCase();
      final addr = (m['address'] ?? '').toString().toLowerCase();
      final notes = (m['notes'] ?? '').toString().toLowerCase();
      return name.contains(q) || addr.contains(q) || notes.contains(q);
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a,b) => (a['name']??'').toString().compareTo((b['name']??'').toString()));
    return list;
  }

  List<Item> get filteredInventoryItems {
    var list = inventoryItemsList.where((i) {
      if (_filterBy != 'All' && _filterBy != 'Important' && i.place != _filterBy) return false;
      if (_searchQuery.isNotEmpty && !i.name.toLowerCase().contains(_searchQuery.toLowerCase())) return false;
      return true;
    }).toList();
    if (_sortBy == 'Name A-Z') list.sort((a, b) => a.name.compareTo(b.name));
    if (_sortBy == 'Location') list.sort((a, b) => '${a.place}/${a.bin}'.compareTo('${b.place}/${b.bin}'));
    if (_sortBy == 'Qty') list.sort((a, b) => b.qty.compareTo(a.qty));
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.scaffold,
        elevation: 0,
        title: Row(children: [
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
                style: AppText.logoLog),
          ])),
        ]),
        actions: [
          IconButton(
              icon: Icon(Icons.menu, color: Colors.black),
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
              color: Colors.white,
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
    final isFilterActive = _filterBy != 'All';
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    child: Row(children: [
        Text('$count ${isStorage ? 'storage' : 'inventory'} items',
            style: AppText.countBar),
        if (isFilterActive) ...[
          SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => setState(() {
              _filterBy = 'All';
            }),
                                    child: Text('Clear filter'),
            ),
        ],
        Spacer(),
        IconButton(icon: Icon(Icons.tune), onPressed: () => _openFilterSheet()),
        IconButton(
            icon: Icon(Icons.search),
            onPressed: () => setState(() => _searchMode = true)),
      ]));
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
          if (currentLat != null)
            Padding(
              padding: EdgeInsets.fromLTRB(12, 8, 12, 0),
                                    child: Row(children: [
                Icon(Icons.my_location, size: 14, color: Colors.blue),
                SizedBox(width: 4),
                Text('Distance from: ${currentLat!.toStringAsFixed(4)}, ${currentLng!.toStringAsFixed(4)}', style: AppText.cardMetaSmall),
                Spacer(),
                InkWell(onTap: () => setState(() { currentLat = null; currentLng = null; }), child: Text('Clear', style: TextStyle(fontSize: 10, color: Colors.blue))),
              ])),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    child: Row(children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _isLoadingLocation ? null : fetchCurrentForDistance,
                                    child: Text('Calc Distance from Current', style: TextStyle(fontSize: 11)),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 8)))),
            ])),
          Expanded(
            child: ListView.builder(
              padding: EdgeInsets.fromLTRB(12, 0, 12, 12),
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
                  color: isSelected ? Color(0xFFE8F0FF) : Color(0xFFFAF6F0),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? Colors.blue : Colors.black12)),
                                    child: ListTile(
                    onTap: () async {
                      if (_isSelectMode('POI')) {
                        setState(() {
                          if (isSelected) _selectedIdsMap['POI']!.remove(poiId);
                          else _selectedIdsMap['POI']!.add(poiId);
                        });
                        return;
                      }
                      final repoIdx = _findPoiRepoIndex(poi);
                      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiEditScreen(itemIndex: repoIdx)));
                      if (mounted) {
                        await _repo.load();
                        setState(() {});
                      }
                    },
                    leading: _isSelectMode('POI')
                        ? Checkbox(value: isSelected, onChanged: (v) => setState(() { if (v == true) _selectedIdsMap['POI']!.add(poiId); else _selectedIdsMap['POI']!.remove(poiId); }))
                        : Container(width: 48, height: 48, decoration: BoxDecoration(color: Color(0xFFE0F2FF), borderRadius: BorderRadius.circular(AppRadius.tabIndicator)), child: Icon(Icons.location_on, color: Colors.blue.shade700)),
                    title: Text(name, style: AppText.cardTitle),
                    subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      SizedBox(height: 4),
                      Container(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Color(0xFFF0EDE8), borderRadius: BorderRadius.circular(AppRadius.tabIndicator)), child: Text(coords, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, fontFamily: 'monospace'))),
                      if (distStr.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Container(padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Color(0xFFE0F2FF), borderRadius: BorderRadius.circular(AppRadius.button)), child: Text(distStr, style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.blue.shade700)))),
                      if (address.isNotEmpty) Padding(padding: EdgeInsets.only(top: 4), child: Text(address, style: AppText.cardMeta, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ]),
                    trailing: _isSelectMode('POI') ? null : Icon(Icons.chevron_right)));
              })),
        ]));
  }

  Widget _buildStorageActionBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      await _repo.load();
                      setState(() {
                        places = _placesFromRepo();
                        items = _itemsFromRepo();
                        inventoryItemsList = _inventoryItemsFromRepo();
                      });
                    }
                  },
                                    child: Text('+ Add'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
        ])));
  }

  Widget _buildInventoryActionBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      await _repo.load();
                      setState(() {
                        places = _placesFromRepo();
                        items = _itemsFromRepo();
                        inventoryItemsList = _inventoryItemsFromRepo();
                      });
                    }
                  },
                                    child: Text('+ Add'),
                  style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(vertical: 16)))),
        ])));
  }

  Widget _buildPoiActionBar() {
    return Container(
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      await _repo.load();
                      setState(() {});
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
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        padding: EdgeInsets.all(12),
        itemCount: filteredItems.length,
        itemBuilder: (c, i) {
          final item = filteredItems[i];
          final isSelected = _idsFor('Storage').contains(item.id);
          final locationLabel =
              item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: isSelected ? Color(0xFFE8F0FF) : Color(0xFFFAF6F0),
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: isSelected ? Colors.blue : Colors.black12)),
                                    child: ListTile(
              onTap: () async {
                if (_isSelectMode('Storage')) {
                  setState(() {
                    if (isSelected) _selectedIdsMap['Storage']!.remove(item.id);
                    else _selectedIdsMap['Storage']!.add(item.id);
                  });
                  return;
                }
                final repoIdx = _findRepoIndexForItem(item);
                if (repoIdx < 0) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => StorageEditScreen(itemIndex: repoIdx)));
                if (mounted) {
                  await _repo.load();
                  setState(() {
                    places = _placesFromRepo();
                    items = _itemsFromRepo();
                  });
                }
              },
              leading: _isSelectMode('Storage')
                  ? Checkbox(value: isSelected, onChanged: (v) => setState(() {
                      if (v == true) _selectedIdsMap['Storage']!.add(item.id);
                      else _selectedIdsMap['Storage']!.remove(item.id);
                    }))
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                          color: AppColors.scaffold,
                          borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Center(
                          child: Text(item.emoji, style: TextStyle(fontSize: 24)))),
              title: Text(item.qty == 1 ? item.name : '(${item.qty}) ${item.name}',
                  style: AppText.cardTitle),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Color(0xFFF0EDE8),
                      borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Text(locationLabel,
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600))),
              trailing: _isSelectMode('Storage') ? null : Icon(Icons.chevron_right)));
        }));
  }

  Widget _buildInventoryList() {
    return Container(
      color: AppColors.scaffold,
                                    child: ListView.builder(
        padding: EdgeInsets.all(12),
        itemCount: filteredInventoryItems.length,
        itemBuilder: (c, i) {
          final item = filteredInventoryItems[i];
          final isSelected = _idsFor('Inventory').contains(item.id);
          final locationLabel = item.bin == null ? item.place : '${item.place} / ${item.bin}';
          return Card(
            margin: EdgeInsets.only(bottom: 8),
            color: isSelected ? Color(0xFFE8F0FF) : Color(0xFFFAF6F0),
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: isSelected ? Colors.blue : Colors.black12)),
                                    child: ListTile(
              onTap: () async {
                if (_isSelectMode('Inventory')) {
                  setState(() {
                    if (isSelected) _selectedIdsMap['Inventory']!.remove(item.id);
                    else _selectedIdsMap['Inventory']!.add(item.id);
                  });
                  return;
                }
                final repoIdx = _findInventoryRepoIndexForItem(item);
                if (repoIdx < 0) return;
                await Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => InventoryEditScreen(itemIndex: repoIdx)));
                if (mounted) {
                  await _repo.load();
                  setState(() {
                    places = _placesFromRepo();
                    inventoryItemsList = _inventoryItemsFromRepo();
                  });
                }
              },
              leading: _isSelectMode('Inventory')
                  ? Checkbox(value: isSelected, onChanged: (v) => setState(() {
                      if (v == true) _selectedIdsMap['Inventory']!.add(item.id);
                      else _selectedIdsMap['Inventory']!.remove(item.id);
                    }))
                  : Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(color: AppColors.scaffold, borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Center(child: Text(item.emoji, style: TextStyle(fontSize: 24)))),
              title: Text(item.qty == 1 ? item.name : '(${item.qty}) ${item.name}', style: AppText.cardTitle),
              subtitle: Container(
                  margin: EdgeInsets.only(top: 4),
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: Color(0xFFF0EDE8), borderRadius: BorderRadius.circular(AppRadius.tabIndicator)),
                                    child: Text(locationLabel, style: AppText.cardLocation)),
              trailing: _isSelectMode('Inventory') ? null : Icon(Icons.chevron_right)));
        }));
  }

  void _openFilterSheet() {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'filter',
      barrierColor: Colors.black54,
      transitionDuration: Duration(milliseconds: 250),
      pageBuilder: (c, a1, a2) {
        return Align(
          alignment: Alignment.topCenter,
                                    child: Material(
            color: Colors.transparent,
                                    child: Container(
              margin: EdgeInsets.only(top: 60, left: 12, right: 12),
              decoration: BoxDecoration(
                color: Color(0xFFDCE7FF),
                borderRadius: BorderRadius.circular(20)),
                                    child: StatefulBuilder(builder: (c, setModal) {
                return Padding(
                  padding: EdgeInsets.all(20),
                                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(children: [
                          Text(AppText.upper('Filter & Sort'),
                              style: AppText.dialogTitle),
                          Spacer(),
                          IconButton(
                              icon: Icon(Icons.close),
                              onPressed: () => Navigator.pop(c))
                        ]),
                        SizedBox(height: 16),
                        Text('SORT BY',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 8),
                        Wrap(
                            spacing: 8,
                            children:
                                ['Recent', 'Name A-Z', 'Location', 'Qty'].map((s) {
                              final sel = _sortBy == s;
                              return ChoiceChip(
                                  label: Text(s),
                                  selected: sel,
                                  onSelected: (_) => setModal(() => _sortBy = s),
                                  selectedColor: Color(0xFF0F1E3A),
                                  labelStyle: TextStyle(
                                      color: sel ? Colors.white : Colors.black));
                            }).toList()),
                        SizedBox(height: 16),
                        Text('FILTER',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textSecondary)),
                        SizedBox(height: 8),
                        Wrap(
                            spacing: 8,
                            children: [
                              'All',
                              'Attic',
                              'Garage',
                              'Shed',
                              'Kitchen',
                              'Office',
                              'Important'
                            ].map((f) {
                              final sel = _filterBy == f;
                              return ChoiceChip(
                                  label: Text(f),
                                  selected: sel,
                                  onSelected: (_) => setModal(() => _filterBy = f),
                                  selectedColor: Color(0xFF0F1E3A),
                                  labelStyle: TextStyle(
                                      color: sel ? Colors.white : Colors.black));
                            }).toList()),
                        SizedBox(height: 20),
                        Row(children: [
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      _filterBy = 'All';
                                      _sortBy = 'Recent';
                                    });
                                    Navigator.pop(c);
                                  },
                                    child: Text('RESET'),
                                  )),
                          SizedBox(width: 12),
                          Expanded(
                              child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {});
                                    Navigator.pop(c);
                                  },
                                    child: Text('APPLY'))),
                        ]),
                      ]));
              }))));
      },
      transitionBuilder: (c, anim, secAnim, child) {
        return SlideTransition(
          position: Tween(begin: Offset(0, -1), end: Offset(0, 0)).animate(anim),
                                    child: child);
      });
  }

  // NEW: Select actions - move & delete - all dialogs top of screen
  Future<void> _moveSelectedItems([String? tabName]) async {
    final String effectiveTab = tabName ?? _currentTabName;
    final Set<String> currentSelected = _selectedIdsMap[effectiveTab] ?? <String>{};
    if (currentSelected.isEmpty) return;
    final placesList = _placesFromRepo();
    String? selectedPlace;
    String? selectedBin;
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'move',
      barrierColor: Colors.black54,
      pageBuilder: (c, a1, a2) {
        return Align(
          alignment: Alignment.topCenter,
                                    child: Material(
            color: Colors.transparent,
                                    child: Container(
              margin: EdgeInsets.only(top: 80, left: 16, right: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                    child: StatefulBuilder(builder: (c2, setModal) {
                final bins = selectedPlace == null ? <String>[] : placesList.firstWhere((p) => p.name == selectedPlace, orElse: () => Place(name: '', bins: [])).bins.map((b) => b.name).toList();
                return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('MOVE ${ currentSelected.length } ITEMS', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                  SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Place', border: OutlineInputBorder()),
                    value: selectedPlace,
                    items: placesList.map((p) => DropdownMenuItem(value: p.name, child: Text(p.name))).toList(),
                    onChanged: (v) => setModal(() { selectedPlace = v; selectedBin = null; })),
                  SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: InputDecoration(labelText: 'Bin (optional)', border: OutlineInputBorder()),
                    value: selectedBin,
                    items: bins.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                    onChanged: (v) => setModal(() => selectedBin = v)),
                  SizedBox(height: 20),
                  Row(children: [
                    Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c), child: Text('CANCEL'), )),
                    SizedBox(width: 12),
                    Expanded(child: ElevatedButton(
                      onPressed: selectedPlace == null ? null : () => Navigator.pop(c, true),
                                    child: Text('MOVE'))),
                  ])
                ]);
              }))));
      }).then((confirmed) async {
      if (confirmed != true || selectedPlace == null) return;
      // Apply move for current tab items
      if (effectiveTab == 'Storage') {
        for (var id in currentSelected.toList()) {
          final idx = _repo.storageItems.indexWhere((m) => m['id']?.toString() == id);
          if (idx >= 0) {
            final map = Map<String, dynamic>.from(_repo.storageItems[idx]);
            // v5: need to resolve specificId for new place/bin
            // For simplicity, store place/bin in old fields + try to find specificId
            // v9: only generalId/specificId stored
            // keep old fields cleared for clean data
            map.remove('place');
            map.remove('tier1');
            map.remove('bin');
            map.remove('tier2');
            map.remove('general');
            map.remove('specific');
            // v9: find generalId and specificId
            try {
              final genId = _repo.generalIdForName(selectedPlace ?? '');
              final spec = _repo.storageSpecifics.firstWhere((s) => s['generalId'] == genId && (s['name'] ?? '') == (selectedBin ?? ''), orElse: () => {});
              if (genId.isNotEmpty) map['generalId'] = genId;
              if (spec.isNotEmpty) map['specificId'] = spec['id'];
            } catch (_) {}
            _repo.storageItems[idx] = map;
          }
        }
        await _repo.save();
        setState(() { items = _itemsFromRepo(); _selectModes['Storage'] = false; _selectedIdsMap['Storage']!.clear(); });
      } else if (effectiveTab == 'Inventory') {
        for (var id in currentSelected.toList()) {
          final idx = _repo.inventoryItems.indexWhere((m) => m['id']?.toString() == id);
          if (idx >= 0) {
            final map = Map<String, dynamic>.from(_repo.inventoryItems[idx]);
            // v9: only generalId/specificId stored
            // keep old fields cleared for clean data
            map.remove('place');
            map.remove('tier1');
            map.remove('bin');
            map.remove('tier2');
            map.remove('general');
            map.remove('specific');
            // v9: find generalId and specificId
            try {
              final genId = _repo.generalIdForName(selectedPlace ?? '');
              final spec = _repo.inventorySpecifics.firstWhere((s) => s['generalId'] == genId && (s['name'] ?? '') == (selectedBin ?? ''), orElse: () => {});
              if (genId.isNotEmpty) map['generalId'] = genId;
              if (spec.isNotEmpty) map['specificId'] = spec['id'];
            } catch (_) {}
            _repo.inventoryItems[idx] = map;
          }
        }
        await _repo.save();
        setState(() { inventoryItemsList = _inventoryItemsFromRepo(); _selectModes['Inventory'] = false; _selectedIdsMap['Inventory']!.clear(); });
      } else if (effectiveTab == 'POI') {
        setState(() { _selectModes['POI'] = false; _selectedIdsMap['POI']!.clear(); });
      }
    });
  }

  Future<void> _deleteSelectedItems([String? tabName]) async {
    final String effectiveTab = tabName ?? _currentTabName;
    final Set<String> currentSelected = _selectedIdsMap[effectiveTab] ?? <String>{};
    if (currentSelected.isEmpty) return;
    final confirmed = await showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'delete',
      barrierColor: Colors.black54,
      pageBuilder: (c, a1, a2) {
        return Align(
          alignment: Alignment.topCenter,
                                    child: Material(
            color: Colors.transparent,
                                    child: Container(
              margin: EdgeInsets.only(top: 80, left: 16, right: 16),
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.warning_amber_rounded, size: 48, color: Colors.red),
                SizedBox(height: 12),
                Text('Delete ${ currentSelected.length } items?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                SizedBox(height: 8),
                Text('This cannot be undone.', style: AppText.cardMeta),
                SizedBox(height: 20),
                Row(children: [
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, false), child: Text('CANCEL'), )),
                  SizedBox(width: 12),
                  Expanded(child: ElevatedButton(onPressed: () => Navigator.pop(c, true),  child: Text('DELETE'))),
                ])
              ]))));
      });
    if (confirmed != true) return;
    if (effectiveTab == 'Storage') {
      _repo.storageItems.removeWhere((m) => currentSelected.contains(m['id']?.toString()));
      await _repo.save();
      setState(() { items = _itemsFromRepo(); _selectModes['Storage'] = false; _selectedIdsMap['Storage']!.clear(); });
    } else if (effectiveTab == 'Inventory') {
      _repo.inventoryItems.removeWhere((m) => currentSelected.contains(m['id']?.toString()));
      await _repo.save();
      setState(() { inventoryItemsList = _inventoryItemsFromRepo(); _selectModes['Inventory'] = false; _selectedIdsMap['Inventory']!.clear(); });
    } else if (effectiveTab == 'POI') {
      _repo.poiItems.removeWhere((m) => currentSelected.contains(m['id']?.toString()));
      await _repo.save();
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
  Item(
      {required this.id,
      required this.name,
      required this.qty,
      required this.place,
      this.bin,
      required this.emoji});
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
                                color: Colors.black, shape: BoxShape.circle),
                                    child:
                                Icon(Icons.location_on, color: Colors.white)),
                        SizedBox(width: 8),
                        Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                              Text('Locations',
                                  style: TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 18)),
                              Text('Place / Room → Bin / Area • distinct bins',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.textSecondary))
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
                            backgroundColor: Colors.black12),
                        Spacer(),
                        Text('default: View',
                            style:
                                AppText.cardMeta)
                      ]),
                      SizedBox(height: 8),
                      Container(
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.black12),
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
                                                  color: Colors.red, size: 18)
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
                                                color: Colors.black12),
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
