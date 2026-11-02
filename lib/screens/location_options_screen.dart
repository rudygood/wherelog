import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../widgets/app_header.dart';
import '../data/location_records.dart';
import '../data/sqlite_inventory_repository.dart';
import '../data/sqlite_location_repository.dart';
import '../data/sqlite_storage_repository.dart';

/// Location Options - SINGLE GENERALS CLEAN
/// Locations live in SQLite (SqliteLocationRepository). Item counts are
/// read from both item tables (storage_items + inventory_items).

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
  int? editingGeneralId;
  int? editingSpecificId;
  String editingSpecificType = 'storage'; // 'storage' or 'inventory'
  final TextEditingController _editController = TextEditingController();
  final TextEditingController _newGeneralController = TextEditingController();
  final Map<int, TextEditingController> _newStorageSpecificControllers = {};
  final Map<int, TextEditingController> _newInventorySpecificControllers = {};

  @override
  void initState() {
    super.initState();
    _reload();
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
    _editController.dispose();
    _newGeneralController.dispose();
    for (final c in _newStorageSpecificControllers.values) {
      c.dispose();
    }
    for (final c in _newInventorySpecificControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: AppColors.scaffold,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(children: [
            const Icon(Icons.location_on_outlined, size: 16, color: AppColors.textPrimary),
            const SizedBox(width: 8),
            Expanded(child: Text('GENERAL LOCATION OPTIONS (${generals.length})', style: AppText.dialogSection)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),
        Expanded(
          child: !_loaded
              ? const SizedBox.shrink()
              : generals.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'No General locations in the database yet.\n\nAdd your first one using the "New General Location Option" at the bottom of this screen.',
                          textAlign: TextAlign.center,
                          style: AppText.dialogNotice,
                        ),
                      ),
                    )
                  : ListView.builder(
            padding: const EdgeInsets.all(6),
            itemCount: generals.length,
            itemBuilder: (c, idx) {
              final g = generals[idx];
              final genId = g.id!;
              final genName = g.name;
              final isExp = expanded.contains(genId);
              final stoSpecifics = _storageSpecificsForGeneral(genId);
              final invSpecifics = _inventorySpecificsForGeneral(genId);
              final itemCount = _itemCountForGeneral(genId);
              final canDeleteGeneral = itemCount==0 && stoSpecifics.isEmpty && invSpecifics.isEmpty;
              final isEditingGen = editingGeneralId==genId;
              return Card(
                margin: const EdgeInsets.only(bottom: 3),
                elevation: 0,
                color: AppColors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
                child: Column(children: [
                  ListTile(
                    dense: true,
                    visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    leading: IconButton(icon: Icon(isExp?Icons.expand_less:Icons.chevron_right, size: 18), onPressed: ()=>setState(()=>isExp?expanded.remove(genId):expanded.add(genId)), padding: EdgeInsets.zero, constraints: const BoxConstraints()),
                    title: isEditingGen ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameGeneral(genId, v), decoration: _fieldDec('General name'), style: AppText.input) : Text(genName, style: AppText.cardTitle),
                    subtitle: Text('$itemCount Storage/Inventory items', style: AppText.dialog),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      if(!isEditingGen) Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(icon: const Icon(Icons.edit_outlined, size: 20, color: AppColors.textSecondary), onPressed: ()=>setState(()=>{editingGeneralId=genId, _editController.text=genName}), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                      if(isEditingGen) Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(icon: const Icon(Icons.check, size: 22, color: AppColors.success), onPressed: ()=>_renameGeneral(genId, _editController.text), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                      if(isEditingGen) Padding(padding: const EdgeInsets.only(right: 8), child: IconButton(icon: const Icon(Icons.close, size: 20, color: AppColors.textSecondary), onPressed: ()=>setState(()=>editingGeneralId=null), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                      IconButton(icon: Icon(Icons.delete_outline, size: 20, color: canDeleteGeneral?AppColors.alert:AppColors.border), onPressed: canDeleteGeneral?()=>_deleteGeneral(genId):null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                    ]),
                  ),
                  if(isExp) ...[
                    // Storage specifics section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textPrimary),
                        const SizedBox(width: 6),
                        Text('STORAGE SPECIFIC LOCATION OPTIONS (${stoSpecifics.length})', style: AppText.dialogSection),
                      ]),
                    ),
                    ...stoSpecifics.map((s) {
                      final specId = s.id!;
                      final specName = s.name;
                      final count = _itemCountForStorageSpecific(specId);
                      final canDelete = count==0;
                      final isEditing = editingSpecificId==specId && editingSpecificType=='storage';
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 2, 8, 2),
                        child: Row(children: [
                          Expanded(child: isEditing ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v, 'storage'), decoration: _fieldDec('Specific name'), style: AppText.input) : Text('• $specName ($count items)', style: AppText.dialog)),
                          if(!isEditing) Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary), onPressed: ()=>setState(()=>{editingSpecificId=specId, editingSpecificType='storage', _editController.text=specName}), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                          if(isEditing) Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: IconButton(icon: const Icon(Icons.check, size: 20, color: AppColors.success), onPressed: ()=>_renameSpecific(specId, _editController.text, 'storage'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: canDelete?AppColors.alert:AppColors.border), onPressed: canDelete?()=>_deleteSpecific(specId, 'storage'):null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                        ]),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 3, 8, 5),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newStorageSpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: _fieldDec('New Storage Specific Location Option'), style: AppText.input, onSubmitted: (v)=>_addSpecific(genId, v, 'storage'))),
                        const SizedBox(width: 6),
                        SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: ()=>_addSpecific(genId, _newStorageSpecificControllers[genId]?.text??'', 'storage'), style: AppButton.primary, child: const Text('+ Add', style: AppText.buttonPrimary))),
                      ]),
                    ),
                    // Inventory specifics section
                    Container(
                      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Row(children: [
                        const Icon(Icons.location_on_outlined, size: 14, color: AppColors.textPrimary),
                        const SizedBox(width: 6),
                        Text('INVENTORY SPECIFIC LOCATION OPTIONS (${invSpecifics.length})', style: AppText.dialogSection),
                      ]),
                    ),
                    ...invSpecifics.map((s) {
                      final specId = s.id!;
                      final specName = s.name;
                      final count = _itemCountForInventorySpecific(specId);
                      final canDelete = count==0;
                      final isEditing = editingSpecificId==specId && editingSpecificType=='inventory';
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(24, 2, 8, 2),
                        child: Row(children: [
                          Expanded(child: isEditing ? TextField(controller: _editController, autofocus: true, onSubmitted: (v)=>_renameSpecific(specId, v, 'inventory'), decoration: _fieldDec('Specific name'), style: AppText.input) : Text('• $specName ($count items)', style: AppText.dialog)),
                          if(!isEditing) Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: IconButton(icon: const Icon(Icons.edit_outlined, size: 18, color: AppColors.textSecondary), onPressed: ()=>setState(()=>{editingSpecificId=specId, editingSpecificType='inventory', _editController.text=specName}), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                          if(isEditing) Padding(padding: const EdgeInsets.only(left: 8, right: 8), child: IconButton(icon: const Icon(Icons.check, size: 20, color: AppColors.success), onPressed: ()=>_renameSpecific(specId, _editController.text, 'inventory'), padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap))),
                          IconButton(icon: Icon(Icons.delete_outline, size: 18, color: canDelete?AppColors.alert:AppColors.border), onPressed: canDelete?()=>_deleteSpecific(specId, 'inventory'):null, padding: EdgeInsets.zero, constraints: const BoxConstraints(minWidth: 36, minHeight: 36), style: IconButton.styleFrom(tapTargetSize: MaterialTapTargetSize.shrinkWrap)),
                        ]),
                      );
                    }),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 3, 8, 8),
                      child: Row(children: [
                        Expanded(child: TextField(controller: _newInventorySpecificControllers.putIfAbsent(genId, ()=>TextEditingController()), decoration: _fieldDec('New Inventory Specific Location Option'), style: AppText.input, onSubmitted: (v)=>_addSpecific(genId, v, 'inventory'))),
                        const SizedBox(width: 6),
                        SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: ()=>_addSpecific(genId, _newInventorySpecificControllers[genId]?.text??'', 'inventory'), style: AppButton.primary, child: const Text('+ Add', style: AppText.buttonPrimary))),
                      ]),
                    ),
                  ],
                ]),
              );
            },
          ),
        ),
        const Divider(height: 1, color: AppColors.border),
        if (!kIsWeb) Container(
          color: AppColors.scaffold,
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
          child: SafeArea(
            child: Row(children: [
              Expanded(child: TextField(controller: _newGeneralController, decoration: _fieldDec('New General Location Option'), style: AppText.input, onSubmitted: (v)=>_addGeneral(v))),
              const SizedBox(width: 8),
              SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: ()=>_addGeneral(_newGeneralController.text), style: AppButton.primary, child: const Text('+ Add', style: AppText.buttonPrimary))),
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
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingGeneralId=null); return;}
    final idx=generals.indexWhere((g)=>g.id==genId); if(idx<0) return;
    final oldName=generals[idx].name; if(t.toLowerCase()==oldName.toLowerCase()){setState(()=>editingGeneralId=null); return;}
    if(await _locRepo.isDuplicateGeneral(t)){_snack('General "$t" already exists'); return;}
    await _locRepo.renameGeneral(genId, t);
    setState(()=>editingGeneralId=null);
    await _reload();
  }
  Future<void> _renameSpecific(int specId, String newName, String type) async {
    final t=newName.trim(); if(t.isEmpty){setState(()=>editingSpecificId=null); return;}
    final int genId;
    final String old;
    if(type=='storage'){
      final idx=storageSpecifics.indexWhere((s)=>s.id==specId); if(idx<0) return;
      old=storageSpecifics[idx].name; genId=storageSpecifics[idx].generalId;
    } else {
      final idx=inventorySpecifics.indexWhere((s)=>s.id==specId); if(idx<0) return;
      old=inventorySpecifics[idx].name; genId=inventorySpecifics[idx].generalId;
    }
    if(t.toLowerCase()==old.toLowerCase()){setState(()=>editingSpecificId=null); return;}
    if(type=='storage' && await _locRepo.isDuplicateStorageSpecific(genId, t) || type=='inventory' && await _locRepo.isDuplicateInventorySpecific(genId, t)){_snack('Specific "$t" already exists'); return;}
    if(type=='storage'){ await _locRepo.renameStorageSpecific(specId, t); } else { await _locRepo.renameInventorySpecific(specId, t); }
    setState(()=>editingSpecificId=null);
    await _reload();
  }
  Future<void> _deleteGeneral(int genId) async {
    final gen=generals.firstWhere((g)=>g.id==genId, orElse: ()=>const GeneralLocation(name: '')); final genName=gen.name;
    final stoSpecifics=_storageSpecificsForGeneral(genId); final invSpecifics=_inventorySpecificsForGeneral(genId); final itemCount=_itemCountForGeneral(genId);
    if(itemCount>0 || stoSpecifics.isNotEmpty || invSpecifics.isNotEmpty){_snack('Cannot delete $genName: has ${stoSpecifics.length} storage + ${invSpecifics.length} inventory specifics, $itemCount items'); return;}
    final confirm=await showDialog<bool>(context: context, builder: (c)=>AlertDialog(title: Text('Delete General "$genName"?'), content: const Text('General has no specifics and no items. This cannot be undone.'), actions: [TextButton(onPressed: ()=>Navigator.pop(c,false), child: const Text('Cancel')), ElevatedButton(onPressed: ()=>Navigator.pop(c,true), style: ElevatedButton.styleFrom(backgroundColor: AppColors.alert), child: const Text('Delete'))]));
    if(confirm!=true) return;
    await _locRepo.deleteGeneral(genId);
    if(editingGeneralId==genId) editingGeneralId=null;
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
    if(editingSpecificId==specId && editingSpecificType==type) editingSpecificId=null;
    await _reload();
  }
  void _snack(String msg)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}
