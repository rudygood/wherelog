import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/app_header.dart';
import '../data/location_records.dart';
import '../data/sqlite_inventory_repository.dart';
import '../data/sqlite_location_repository.dart';
import '../data/sqlite_storage_repository.dart';

/// Location Options — REWORKED VIEW (2026-11-10), same plumbing.
/// Locations live in SQLite (SqliteLocationRepository). Item counts are
/// read from both item tables (storage_items + inventory_items).
///
/// The page Rudy designed: a collapsible "About this Page" box at
/// the front (Hide/Show beside its label, opens by default, and its
/// state is remembered like the Notes/Photo sections'), one standing
/// instruction line, then a card per General. Inside an open card, two
/// trees drawn in the wordmark's split colors — Storage specifics in
/// logo blue, Inventory specifics in Alert red — each entry one line,
/// name plus item count. Tapping any entry opens its edit popup
/// (rename, or a red Delete that explains itself when greyed out).
/// The last row of each tree is its add-entry row; new Generals are
/// added at the bottom of the page. Horizontal padding is the main
/// page's 6 outside / 6 inside.

class LocationOptionsScreen extends StatefulWidget {
  const LocationOptionsScreen({super.key});
  @override
  State<LocationOptionsScreen> createState() => _LocationOptionsScreenState();
}

class _LocationOptionsScreenState extends State<LocationOptionsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(screenName: 'Location Options'),
      body: _SingleGeneralTree(),
    );
  }
}

class _SingleGeneralTree extends StatefulWidget {
  const _SingleGeneralTree();
  @override
  State<_SingleGeneralTree> createState() => _SingleGeneralTreeState();
}

class _SingleGeneralTreeState extends State<_SingleGeneralTree> {
  final SqliteLocationRepository _locRepo = SqliteLocationRepository.instance;
  final SqliteStorageRepository _storageRepo = SqliteStorageRepository.instance;
  final SqliteInventoryRepository _invRepo = SqliteInventoryRepository.instance;
  List<GeneralLocation> generals = [];
  List<StorageSpecific> storageSpecifics = [];
  List<InventorySpecific> inventorySpecifics = [];
  Map<int, int> _storageCountsBySpecific = {};
  Map<int, int> _storageCountsByGeneral = {};
  Map<int, int> _invCountsBySpecific = {};
  Map<int, int> _invCountsByGeneral = {};
  bool _loaded = false;
  Set<int> expanded = {};
  bool _howToOpen = true;
  bool _editEnabled = true;
  final TextEditingController _newGeneralController = TextEditingController();
  final Map<int, TextEditingController> _newStorageSpecificControllers = {};
  final Map<int, TextEditingController> _newInventorySpecificControllers = {};

  @override
  void initState() {
    super.initState();
    _reload();
    _loadHowTo();
    _loadEditEnabled();
  }

  // The instruction box's state is remembered across sessions, the
  // way the Notes and Photo sections remember theirs: no saved value
  // means it has never been closed, so it starts open.
  Future<void> _loadHowTo() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('locationOptionsHowToOpen');
    if (saved != null && mounted) setState(() => _howToOpen = saved);
  }

  Future<void> _toggleHowTo() async {
    setState(() => _howToOpen = !_howToOpen);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationOptionsHowToOpen', _howToOpen);
  }

  // The read-only switch's state is remembered the same way: no
  // saved value means the page has always opened editable.
  Future<void> _loadEditEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('locationOptionsEditEnabled');
    if (saved != null && mounted) setState(() => _editEnabled = saved);
  }

  Future<void> _toggleEdit(bool value) async {
    setState(() => _editEnabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('locationOptionsEditEnabled', _editEnabled);
  }

  Future<void> _reload() async {
    final g = await _locRepo.getGenerals();
    final ss = await _locRepo.getStorageSpecifics();
    final isx = await _locRepo.getInventorySpecifics();
    // Item counts are real for both item tables now that storage_items
    // and inventory_items are both wired.
    final bySpec = <int, int>{};
    for (final s in ss) {
      if (s.id != null) bySpec[s.id!] = await _storageRepo.countForSpecific(s.id!);
    }
    final byGen = <int, int>{};
    for (final gen in g) {
      if (gen.id != null) byGen[gen.id!] = await _storageRepo.countForGeneral(gen.id!);
    }
    final invBySpec = <int, int>{};
    for (final s in isx) {
      if (s.id != null) invBySpec[s.id!] = await _invRepo.countForSpecific(s.id!);
    }
    final invByGen = <int, int>{};
    for (final gen in g) {
      if (gen.id != null) invByGen[gen.id!] = await _invRepo.countForGeneral(gen.id!);
    }
    if (!mounted) return;
    setState(() {
      generals = g;
      storageSpecifics = ss;
      inventorySpecifics = isx;
      _storageCountsBySpecific = bySpec;
      _storageCountsByGeneral = byGen;
      _invCountsBySpecific = invBySpec;
      _invCountsByGeneral = invByGen;
      _loaded = true;
    });
  }

  int _itemCountForStorageSpecific(int specId) => _storageCountsBySpecific[specId] ?? 0;
  int _itemCountForInventorySpecific(int specId) => _invCountsBySpecific[specId] ?? 0;
  int _itemCountForGeneral(int genId) =>
      (_storageCountsByGeneral[genId] ?? 0) + (_invCountsByGeneral[genId] ?? 0);

  List<StorageSpecific> _storageSpecificsForGeneral(int genId) => storageSpecifics.where((s) => s.generalId == genId).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  List<InventorySpecific> _inventorySpecificsForGeneral(int genId) => inventorySpecifics.where((s) => s.generalId == genId).toList()..sort((a,b)=>a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  InputDecoration _fieldDec(String hint) => InputDecoration(
    hintText: hint,
    isDense: true,
    filled: true,
    fillColor: AppColors.white,
    contentPadding: AppSize.fieldPadding,
    hintStyle: AppText.inputHint,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: AppBorder.side),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius), borderSide: const BorderSide(color: AppColors.textPrimary, width: 1)),
  );

  @override
  void dispose() {
    _newGeneralController.dispose();
    for (final c in _newStorageSpecificControllers.values) {
      c.dispose();
    }
    for (final c in _newInventorySpecificControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // The instruction box: a label header with Hide/Show beside it.
  Widget _howToBox() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(AppBorder.radius),
        border: Border.all(color: AppColors.border, width: AppBorder.width),
      ),
      padding: const EdgeInsets.fromLTRB(6, 2, 6, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('About this Page', style: AppText.dialogSection),
            const Spacer(),
            TextButton(
              onPressed: _toggleHowTo,
              style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), minimumSize: const Size(0, 28), tapTargetSize: MaterialTapTargetSize.shrinkWrap),
              child: Text(_howToOpen ? 'Hide' : 'Show', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            ),
          ]),
          if (_howToOpen) ...[
            const Text('Location options record the location of Storage Items and Home Inventory. Every entry in these two categories must have a General location and may also have an optional Specific location. There is one shared list of General locations for both; the Specific locations are separate — Storage Items and Home Inventory each have their own Specifics for each General. Locations can also be added or edited while adding or editing items, to accommodate new or changed entries.', style: AppText.dialog),
            const SizedBox(height: 6),
            const Text('This page lets you view and manage location options as a whole — particularly useful for prepopulating them before capturing your Storage and Inventory items. Each General appears as an expandable card; expanded, it shows all its Specific locations, those connected by blue lines belonging to Storage and those by red to Inventory. Add a new General with the entry field at the bottom of the screen. New Specifics are added in the last row of each color\'s list. To edit or delete, tap any entry: a popup lets you update it or delete it — though delete is unavailable while items still use that location.', style: AppText.dialog),
          ],
        ],
      ),
    );
  }

  // One tree of a card: the family's entry rows, then its add row.
  // [color] is the family's wordmark color. The Storage tree never
  // ends inside its section — its trunk runs on into the junction
  // row between the families. The Inventory tree ends at its add
  // row, or, in read-only, at its last entry. In read-only the add
  // row is not built at all, and entry taps are quiet (Rudy,
  // 2026-11-10: the adds disappear entirely, never show disabled).
  Widget _treeSection({
    required int genId,
    required String kind,
    required Color color,
    required List<int> ids,
    required List<String> names,
    required List<int> counts,
    required TextEditingController addController,
    required String addHint,
  }) {
    final isInventory = kind == 'inventory';
    return Padding(
      padding: isInventory ? const EdgeInsets.fromLTRB(6, 0, 6, 2) : const EdgeInsets.fromLTRB(6, 4, 6, 0),
      child: Column(children: [
        for (var i = 0; i < ids.length; i++)
          _treeRow(
            color: color,
            isLast: isInventory && !_editEnabled && i == ids.length - 1,
            child: InkWell(
              onTap: _editEnabled ? () => _showEntryPopup(kind: kind, id: ids[i], name: names[i]) : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Text('${names[i]} (${counts[i]})', style: AppText.countBar),
              ),
            ),
          ),
        if (_editEnabled)
          _treeRow(
            color: color,
            isLast: isInventory,
            child: Row(children: [
              Expanded(child: TextField(controller: addController, textCapitalization: TextCapitalization.words, decoration: _fieldDec(addHint), style: AppText.input, onSubmitted: (v) => _addSpecific(genId, v, kind))),
              const SizedBox(width: 6),
              SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: () => _addSpecific(genId, addController.text, kind), style: AppButton.primary, child: const Text('+ Add', style: AppText.buttonPrimary))),
            ]),
          ),
      ]),
    );
  }

  // The junction between a card's two trees: the blue trunk descends
  // into a red ball, and the red trunk descends out of it — one
  // connected tree per card (Rudy, 2026-11-10). The ball falls in
  // the gap between the last blue row and the first red row.
  Widget _junctionRow() {
    return const SizedBox(
      height: 14,
      child: Row(children: [
        SizedBox(width: 28, child: CustomPaint(painter: _JunctionPainter())),
        Expanded(child: SizedBox()),
      ]),
    );
  }

  // A tree row: the drawn branch at the left, the content beside it.
  Widget _treeRow({required Color color, required bool isLast, required Widget child}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(width: 22, child: CustomPaint(painter: _TreeLinePainter(color: color, isLast: isLast))),
          Expanded(child: Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: child)),
        ],
      ),
    );
  }

  // The edit popup for one entry: rename in the field, Update to
  // commit, and a red Delete — enabled only when the standing rules
  // allow it, with the reason on the popup when it is greyed out.
  // The dialog owns its text controller (see _EntryEditDialog): the
  // first version disposed the controller here, the moment the
  // dialog started closing — while the closing dialog was still on
  // screen using it — which tripped a framework assertion on Cancel
  // (Rudy's report, 2026-11-10).
  Future<void> _showEntryPopup({required String kind, required int id, required String name}) async {
    final isGeneral = kind == 'general';
    final bool canDelete;
    final String why;
    if (isGeneral) {
      final itemCount = _itemCountForGeneral(id);
      final specCount = _storageSpecificsForGeneral(id).length + _inventorySpecificsForGeneral(id).length;
      canDelete = itemCount == 0 && specCount == 0;
      why = [
        if (specCount > 0) '$specCount specific${specCount == 1 ? '' : 's'} below it',
        if (itemCount > 0) '$itemCount item${itemCount == 1 ? '' : 's'} use it',
      ].join(' and ');
    } else {
      final itemCount = kind == 'storage' ? _itemCountForStorageSpecific(id) : _itemCountForInventorySpecific(id);
      canDelete = itemCount == 0;
      why = '$itemCount item${itemCount == 1 ? '' : 's'} use it';
    }
    final result = await showDialog<({bool delete, String name})>(
      context: context,
      builder: (c) => _EntryEditDialog(
        title: isGeneral ? 'General location' : (kind == 'storage' ? 'Storage specific' : 'Inventory specific'),
        initialName: name,
        canDelete: canDelete,
        why: why,
        fieldDecoration: _fieldDec('Name'),
      ),
    );
    if (result == null) return;
    if (result.delete) {
      await _applyDelete(kind, id);
    } else {
      await _applyRename(kind, id, result.name);
    }
  }

  Future<void> _applyRename(String kind, int id, String newName) async {
    if (kind == 'general') {
      await _renameGeneral(id, newName);
    } else {
      await _renameSpecific(id, newName, kind);
    }
  }

  Future<void> _applyDelete(String kind, int id) async {
    if (kind == 'general') {
      await _deleteGeneral(id);
    } else {
      await _deleteSpecific(id, kind);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 0),
          child: _howToBox(),
        ),
        // The standing control line: pencil, the read-only switch,
        // and the short instruction. It stays on the page whatever
        // the instruction box is doing. Switched off, the page is
        // read-only — every add element disappears and the entry
        // taps go quiet, leaving a clean view of the data.
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
          child: Row(children: [
            Icon(Icons.edit, size: 16, color: _editEnabled ? AppColors.textPrimary : AppColors.border),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.8,
              child: Switch(
                value: _editEnabled,
                onChanged: _toggleEdit,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                trackColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? AppColors.logoBlue : null),
              ),
            ),
            const SizedBox(width: 4),
            Text(_editEnabled ? 'Tap entry for edit/delete.' : 'Read only.', style: AppText.dialog),
          ]),
        ),
        Expanded(
          child: !_loaded
              ? const SizedBox.shrink()
              : generals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          _editEnabled
                              ? 'No General locations in the database yet.\n\nAdd your first one using the "New General Location" at the bottom of this screen.'
                              : 'No General locations in the database yet.',
                          textAlign: TextAlign.center,
                          style: AppText.dialogNotice,
                        ),
                      ),
                    )
                  : ListView.builder(
            padding: const EdgeInsets.fromLTRB(6, 4, 6, 6),
            itemCount: generals.length,
            itemBuilder: (c, idx) {
              final g = generals[idx];
              final genId = g.id!;
              final genName = g.name;
              final isExp = expanded.contains(genId);
              final stoSpecifics = _storageSpecificsForGeneral(genId);
              final invSpecifics = _inventorySpecificsForGeneral(genId);
              final itemCount = _itemCountForGeneral(genId);
              return Card(
                margin: const EdgeInsets.only(bottom: 6),
                elevation: 0,
                color: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                child: Column(children: [
                  // Header line: name and everything-below count at the
                  // left; tapping the line opens the entry's edit
                  // popup. The expand control is at the far right, a
                  // full button-sized target.
                  InkWell(
                    onTap: _editEnabled ? () => _showEntryPopup(kind: 'general', id: genId, name: genName) : null,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 6),
                      child: Row(children: [
                        Expanded(child: Text('$genName ($itemCount)', style: AppText.cardTitle)),
                        IconButton(
                          icon: Icon(isExp ? Icons.expand_less : Icons.expand_more, size: 22, color: AppColors.textSecondary),
                          onPressed: () => setState(() => isExp ? expanded.remove(genId) : expanded.add(genId)),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                          style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                        ),
                      ]),
                    ),
                  ),
                  if (isExp) ...[
                    Container(height: 1, color: AppColors.border, margin: const EdgeInsets.symmetric(horizontal: 6)),
                    _treeSection(
                      genId: genId,
                      kind: 'storage',
                      color: AppColors.logoBlue,
                      ids: [for (final s in stoSpecifics) s.id!],
                      names: [for (final s in stoSpecifics) s.name],
                      counts: [for (final s in stoSpecifics) _itemCountForStorageSpecific(s.id!)],
                      addController: _newStorageSpecificControllers.putIfAbsent(genId, () => TextEditingController()),
                      addHint: 'New Storage Specific',
                    ),
                    _junctionRow(),
                    _treeSection(
                      genId: genId,
                      kind: 'inventory',
                      color: AppColors.alert,
                      ids: [for (final s in invSpecifics) s.id!],
                      names: [for (final s in invSpecifics) s.name],
                      counts: [for (final s in invSpecifics) _itemCountForInventorySpecific(s.id!)],
                      addController: _newInventorySpecificControllers.putIfAbsent(genId, () => TextEditingController()),
                      addHint: 'New Inventory Specific',
                    ),
                    const SizedBox(height: 4),
                  ],
                ]),
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        if (!kIsWeb && _editEnabled) Container(
          color: AppColors.scaffold,
          padding: const EdgeInsets.fromLTRB(6, 6, 6, 10),
          child: SafeArea(
            child: Row(children: [
              Expanded(child: TextField(controller: _newGeneralController, textCapitalization: TextCapitalization.words, decoration: _fieldDec('New General Location'), style: AppText.input, onSubmitted: (v) => _addGeneral(v))),
              const SizedBox(width: 6),
              SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: () => _addGeneral(_newGeneralController.text), style: AppButton.primary, child: const Text('+ Add', style: AppText.buttonPrimary))),
            ]),
          ),
        ),
      ],
    );
  }

  Future<void> _addGeneral(String name) async {
    final t=name.trim(); if(t.isEmpty) return;
    if(await _locRepo.isDuplicateGeneral(t)){_snack('General "$t" already exists'); return;}
    await _locRepo.addGeneral(t);
    _newGeneralController.clear();
    await _reload();
  }
  Future<void> _addSpecific(int genId, String name, String type) async {
    final t=name.trim(); if(t.isEmpty) return;
    if(type=='storage'){
      if(await _locRepo.isDuplicateStorageSpecific(genId, t)){_snack('Storage Specific "$t" already exists'); return;}
      await _locRepo.addStorageSpecific(genId, t);
      _newStorageSpecificControllers[genId]?.clear();
    } else {
      if(await _locRepo.isDuplicateInventorySpecific(genId, t)){_snack('Inventory Specific "$t" already exists'); return;}
      await _locRepo.addInventorySpecific(genId, t);
      _newInventorySpecificControllers[genId]?.clear();
    }
    setState(()=>expanded.add(genId));
    await _reload();
  }
  Future<void> _renameGeneral(int genId, String newName) async {
    final t=newName.trim(); if(t.isEmpty) return;
    final idx=generals.indexWhere((g)=>g.id==genId); if(idx<0) return;
    final oldName=generals[idx].name; if(t.toLowerCase()==oldName.toLowerCase()) return;
    if(await _locRepo.isDuplicateGeneral(t)){_snack('General "$t" already exists'); return;}
    await _locRepo.renameGeneral(genId, t);
    await _reload();
  }
  Future<void> _renameSpecific(int specId, String newName, String type) async {
    final t=newName.trim(); if(t.isEmpty) return;
    final int genId;
    final String old;
    if(type=='storage'){
      final idx=storageSpecifics.indexWhere((s)=>s.id==specId); if(idx<0) return;
      old=storageSpecifics[idx].name; genId=storageSpecifics[idx].generalId;
    } else {
      final idx=inventorySpecifics.indexWhere((s)=>s.id==specId); if(idx<0) return;
      old=inventorySpecifics[idx].name; genId=inventorySpecifics[idx].generalId;
    }
    if(t.toLowerCase()==old.toLowerCase()) return;
    if(type=='storage' && await _locRepo.isDuplicateStorageSpecific(genId, t) || type=='inventory' && await _locRepo.isDuplicateInventorySpecific(genId, t)){_snack('Specific "$t" already exists'); return;}
    if(type=='storage'){ await _locRepo.renameStorageSpecific(specId, t); } else { await _locRepo.renameInventorySpecific(specId, t); }
    await _reload();
  }
  Future<void> _deleteGeneral(int genId) async {
    final gen=generals.firstWhere((g)=>g.id==genId, orElse: ()=>const GeneralLocation(name: '')); final genName=gen.name;
    final stoSpecifics=_storageSpecificsForGeneral(genId); final invSpecifics=_inventorySpecificsForGeneral(genId); final itemCount=_itemCountForGeneral(genId);
    if(itemCount>0 || stoSpecifics.isNotEmpty || invSpecifics.isNotEmpty){_snack('Cannot delete $genName: has ${stoSpecifics.length} storage + ${invSpecifics.length} inventory specifics, $itemCount items'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete General "$genName"?'), content: const Text('General has no specifics and no items. This cannot be undone.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert), child: const Text('Delete'))]));
    if(confirm!=true) return;
    await _locRepo.deleteGeneral(genId);
    setState(()=>{expanded.remove(genId)});
    await _reload();
  }
  Future<void> _deleteSpecific(int specId, String type) async {
    final String specName; final int genId;
    if(type=='storage'){
      final spec=storageSpecifics.firstWhere((s)=>s.id==specId, orElse: ()=>StorageSpecific(generalId: 0, name: '')); specName=spec.name; genId=spec.generalId;
    } else {
      final spec=inventorySpecifics.firstWhere((s)=>s.id==specId, orElse: ()=>InventorySpecific(generalId: 0, name: '')); specName=spec.name; genId=spec.generalId;
    }
    final gen=generals.firstWhere((g)=>g.id==genId, orElse: ()=>const GeneralLocation(name: '')); final genName=gen.name;
    final count = type=='storage' ? _itemCountForStorageSpecific(specId) : _itemCountForInventorySpecific(specId);
    if(count>0){_snack('Cannot delete $genName / $specName: $count items reference it'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete Specific "$genName / $specName"?'), content: const Text('Specific has no items. Delete?'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert), child: const Text('Delete'))]));
    if(confirm!=true) return;
    if(type=='storage'){ await _locRepo.deleteStorageSpecific(specId); } else { await _locRepo.deleteInventorySpecific(specId); }
    await _reload();
  }
  void _snack(String msg)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

/// Draws one row of a location tree in the family's color: the
/// vertical trunk running through the row, and a horizontal branch
/// reaching to the entry. The tree's last row stops its trunk at the
/// branch, closing the tree.
class _TreeLinePainter extends CustomPainter {
  final Color color;
  final bool isLast;
  const _TreeLinePainter({required this.color, required this.isLast});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3.2
      ..style = PaintingStyle.stroke;
    final trunkX = size.width / 2;
    final midY = size.height / 2;
    canvas.drawLine(Offset(trunkX, 0), Offset(trunkX, isLast ? midY : size.height), paint);
    canvas.drawLine(Offset(trunkX, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(covariant _TreeLinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.isLast != isLast;
}


/// The entry edit popup as its own widget, so the text controller is
/// owned by the dialog's State and disposed in its dispose() — which
/// the framework calls only after the dialog has fully left the
/// tree. Pops with (delete: true) for Delete, (delete: false, name)
/// for Update or keyboard submit, and null for Cancel.
class _EntryEditDialog extends StatefulWidget {
  final String title;
  final String initialName;
  final bool canDelete;
  final String why;
  final InputDecoration fieldDecoration;
  const _EntryEditDialog({
    required this.title,
    required this.initialName,
    required this.canDelete,
    required this.why,
    required this.fieldDecoration,
  });

  @override
  State<_EntryEditDialog> createState() => _EntryEditDialogState();
}

class _EntryEditDialogState extends State<_EntryEditDialog> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _ctrl,
            textCapitalization: TextCapitalization.words,
            autofocus: true,
            decoration: widget.fieldDecoration,
            style: AppText.input,
            onSubmitted: (v) => Navigator.pop(context, (delete: false, name: v)),
          ),
          if (!widget.canDelete)
            Padding(padding: const EdgeInsets.only(top: 10), child: Text('Delete is unavailable: ${widget.why}.', style: AppText.dialog)),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: widget.canDelete ? () => Navigator.pop(context, (delete: true, name: '')) : null,
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert, foregroundColor: AppColors.white, disabledBackgroundColor: AppColors.buttonBgDisabled, disabledForegroundColor: AppColors.whiteDim),
          child: const Text('Delete'),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: () => Navigator.pop(context, (delete: false, name: _ctrl.text)), style: AppButton.primary, child: const Text('Update', style: AppText.buttonPrimary)),
      ],
    );
  }
}


/// Paints the junction between a card's two trees inside the 28-wide
/// gutter (the trunk center, x 17, matches the tree rows': their 22
/// gutter plus the sections' 6 left padding): the blue trunk comes
/// down from above, meets a red ball at the row's middle, and the
/// red trunk continues down out of the ball.
class _JunctionPainter extends CustomPainter {
  const _JunctionPainter();

  @override
  void paint(Canvas canvas, Size size) {
    const x = 17.0;
    final cy = size.height / 2;
    final blue = Paint()
      ..color = AppColors.logoBlue
      ..strokeWidth = 3.2;
    canvas.drawLine(const Offset(x, 0), Offset(x, cy - 4.5), blue);
    final red = Paint()
      ..color = AppColors.alert
      ..strokeWidth = 3.2;
    canvas.drawLine(Offset(x, cy + 4.5), Offset(x, size.height), red);
    canvas.drawCircle(Offset(x, cy), 4.5, Paint()..color = AppColors.alert);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
