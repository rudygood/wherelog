// WHERELOG REPO v9 FROM YOUR ZIP - CLEAN NO SYNONYMS - 2026-10-04
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';

class WhereLogRepository {
  static final WhereLogRepository _instance = WhereLogRepository._internal();
  factory WhereLogRepository() => _instance;
  WhereLogRepository._internal();

  List<Map<String, dynamic>> _generals = [];
  List<Map<String, dynamic>> _storageSpecifics = [];
  List<Map<String, dynamic>> _inventorySpecifics = [];
  List<Map<String, dynamic>> _storageItems = [];
  List<Map<String, dynamic>> _inventoryItems = [];
  List<Map<String, dynamic>> _poiItems = [];
  bool _loaded = false;

  List<Map<String, dynamic>> get generals => _generals;
  List<Map<String, dynamic>> get storageSpecifics => _storageSpecifics;
  List<Map<String, dynamic>> get inventorySpecifics => _inventorySpecifics;
  List<Map<String, dynamic>> get storageItems => _storageItems;
  List<Map<String, dynamic>> get inventoryItems => _inventoryItems;
  List<Map<String, dynamic>> get poiItems => _poiItems;

  // Helpers for RequiredSection and screens
  List<String> get generalNames => _generals.map((g) => g['name']?.toString() ?? '').where((n) => n.isNotEmpty).toList()
    ..sort((a,b)=>a.toLowerCase().compareTo(b.toLowerCase()));

  List<Map<String,dynamic>> storageSpecificsFor(String generalId) =>
    _storageSpecifics.where((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').trim().isNotEmpty).toList()
      ..sort((a,b)=> (a['name']??'').toString().toLowerCase().compareTo((b['name']??'').toString().toLowerCase()));

  List<Map<String,dynamic>> inventorySpecificsFor(String generalId) =>
    _inventorySpecifics.where((s) => s['generalId'] == generalId && (s['name']?.toString() ?? '').trim().isNotEmpty).toList()
      ..sort((a,b)=> (a['name']??'').toString().toLowerCase().compareTo((b['name']??'').toString().toLowerCase()));

  List<String> storageSpecificNamesFor(String generalId) => storageSpecificsFor(generalId).map((e)=>e['name'].toString()).toList();
  List<String> inventorySpecificNamesFor(String generalId) => inventorySpecificsFor(generalId).map((e)=>e['name'].toString()).toList();

  String generalIdForName(String name) {
    final lower = name.trim().toLowerCase();
    for (var g in _generals) { if ((g['name']?.toString() ?? '').trim().toLowerCase() == lower) return g['id']?.toString() ?? ''; }
    return '';
  }
  String generalNameForId(String id) {
    for (var g in _generals) { if (g['id']?.toString() == id) return g['name']?.toString() ?? ''; }
    return '';
  }

  bool isDuplicateGeneral(String name) => _generals.any((g) => (g['name']??'').toString().toLowerCase() == name.trim().toLowerCase());
  bool isDuplicateStorageSpecific(String generalId, String name) => _storageSpecifics.any((s) => s['generalId']==generalId && (s['name']??'').toString().toLowerCase()==name.trim().toLowerCase());
  bool isDuplicateInventorySpecific(String generalId, String name) => _inventorySpecifics.any((s) => s['generalId']==generalId && (s['name']??'').toString().toLowerCase()==name.trim().toLowerCase());

  Future<File> _runtimeFile() async {
    try {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null) {
        final whereLogFile = File('$userProfile\\Documents\\WhereLog\\wherelog_data.json');
        if (await whereLogFile.exists()) return whereLogFile;
      }
    } catch (_) {}
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/WhereLog/wherelog_data.json');
  }

  Future<File> _fallbackFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/wherelog_data.json');
  }

  Map<String, dynamic> toFullJson() => {
    'generals': _generals,
    'storageSpecifics': _storageSpecifics,
    'inventorySpecifics': _inventorySpecifics,
    'storageItems': _storageItems,
    'inventoryItems': _inventoryItems,
    'poiItems': _poiItems,
    'version': 9,
    'savedAt': DateTime.now().toIso8601String(),
  };

  Future<void> load() async {
    if (_loaded) return;
    try {
      Map<String, dynamic> j = {};
      if (!kIsWeb) {
        final rf = await _runtimeFile();
        final fb = await _fallbackFile();
        if (await rf.exists()) {
          j = json.decode(await rf.readAsString()) as Map<String, dynamic>;
        } else if (await fb.exists()) {
          j = json.decode(await fb.readAsString()) as Map<String, dynamic>;
        } else {
          // try asset paths
          try {
            final t = await rootBundle.loadString('assets/data/wherelog_data.json');
            j = json.decode(t) as Map<String, dynamic>;
          } catch (_) {
            final t = await rootBundle.loadString('assets/wherelog_data.json');
            j = json.decode(t) as Map<String, dynamic>;
          }
        }
      } else {
        try {
          final t = await rootBundle.loadString('assets/data/wherelog_data.json');
          j = json.decode(t) as Map<String, dynamic>;
        } catch (_) {
          final t = await rootBundle.loadString('assets/wherelog_data.json');
          j = json.decode(t) as Map<String, dynamic>;
        }
      }
      _parseClean(j);
      _loaded = true;
    } catch (_) {
      _loaded = true;
    }
  }

  void _parseClean(Map<String, dynamic> j) {
    // Only accept clean format - no tier synonyms
    _generals = (j['generals'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    _storageSpecifics = (j['storageSpecifics'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    _inventorySpecifics = (j['inventorySpecifics'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    _storageItems = (j['storageItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    _inventoryItems = (j['inventoryItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    _poiItems = (j['poiItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
  }

  Future<void> save() async {
    if (kIsWeb) return;
    try {
      final f = await _runtimeFile();
      await f.parent.create(recursive: true);
      await f.writeAsString(const JsonEncoder.withIndent('  ').convert(toFullJson()));
      // also write fallback for compatibility
      final fb = await _fallbackFile();
      if (fb.path != f.path) {
        try { await fb.parent.create(recursive: true); await fb.writeAsString(const JsonEncoder.withIndent('  ').convert(toFullJson())); } catch (_) {}
      }
    } catch (_) {}
  }

  Future<void> clearAllData() async {
    _generals=[]; _storageSpecifics=[]; _inventorySpecifics=[]; _storageItems=[]; _inventoryItems=[]; _poiItems=[];
    await save();
  }

  Future<void> forceReload() async { _loaded=false; await load(); }

  Future<void> replaceAllFromJson(Map<String,dynamic> j, {String Function(String oldPath)? remapPhoto}) async {
    var newGenerals = (j['generals'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    var newStoSpecs = (j['storageSpecifics'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    var newInvSpecs = (j['inventorySpecifics'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    var newStoItems = (j['storageItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    var newInvItems = (j['inventoryItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();
    var newPoiItems = (j['poiItems'] as List? ?? []).map<Map<String,dynamic>>((e) => Map<String,dynamic>.from(e as Map)).toList();

    if (remapPhoto != null) {
      List<Map<String,dynamic>> remap(List<Map<String,dynamic>> list) {
        return list.map((m){
          final ph = m['photo'] ?? m['photoPath'];
          if (ph is String && ph.isNotEmpty) { final np = remapPhoto(ph); m['photo']=np; m['photoPath']=np; }
          return m;
        }).toList();
      }
      newStoItems = remap(newStoItems);
      newInvItems = remap(newInvItems);
      newPoiItems = remap(newPoiItems);
    }

    _generals = newGenerals;
    _storageSpecifics = newStoSpecs;
    _inventorySpecifics = newInvSpecs;
    _storageItems = newStoItems;
    _inventoryItems = newInvItems;
    _poiItems = newPoiItems;
    _loaded = true;
    await save();
  }

  Future<void> addGeneral(String name) async {
    if (kIsWeb) return;
    final t=name.trim(); if(t.isEmpty||isDuplicateGeneral(t)) return;
    final id='gen_${(_generals.length+1).toString().padLeft(3,'0')}_${DateTime.now().millisecondsSinceEpoch % 10000}';
    // Use simple sequential if possible
    final simpleId = 'gen_${(_generals.length+1).toString().padLeft(3,'0')}';
    final finalId = _generals.any((g)=>g['id']==simpleId) ? id : simpleId;
    _generals.add({'id':finalId,'name':t});
    // add blank sentinels for UI that expects empty specific
    _storageSpecifics.add({'id':'stospec_${(_storageSpecifics.length+1).toString().padLeft(3,'0')}','generalId':finalId,'name':''});
    _inventorySpecifics.add({'id':'invspec_${(_inventorySpecifics.length+1).toString().padLeft(3,'0')}','generalId':finalId,'name':''});
    await save();
  }

  Future<void> addStorageSpecific(String generalId, String name) async {
    if (kIsWeb) return;
    final n=name.trim(); if(n.isEmpty||isDuplicateStorageSpecific(generalId,n)) return;
    _storageSpecifics.add({'id':'stospec_${(_storageSpecifics.length+1).toString().padLeft(3,'0')}_${DateTime.now().millisecondsSinceEpoch % 10000}','generalId':generalId,'name':n});
    await save();
  }

  Future<void> addInventorySpecific(String generalId, String name) async {
    if (kIsWeb) return;
    final n=name.trim(); if(n.isEmpty||isDuplicateInventorySpecific(generalId,n)) return;
    _inventorySpecifics.add({'id':'invspec_${(_inventorySpecifics.length+1).toString().padLeft(3,'0')}_${DateTime.now().millisecondsSinceEpoch % 10000}','generalId':generalId,'name':n});
    await save();
  }

  // Items store ONLY generalId + specificId + core fields - no tier synonyms
  Future<void> addStorageItem(Map<String,dynamic> item) async {
    if (kIsWeb) return;
    final gid=item['generalId']?.toString()??''; final sid=item['specificId']?.toString()??''; if(gid.isEmpty||sid.isEmpty) return;
    _storageItems.add({
      'id':'sto_${DateTime.now().millisecondsSinceEpoch}',
      'name':item['name']??'Unnamed',
      'generalId':gid,
      'specificId':sid,
      'qty':item['qty']??1,
      'value':item['value'],
      'valueAmount':item['valueAmount']??'',
      'notes':item['notes']??'',
      'photo':item['photo'],
      'photoPath':item['photoPath'],
      'createdAt':DateTime.now().toIso8601String(),
      'modifyDate':DateTime.now().toIso8601String(),
      'updatedAt':DateTime.now().toIso8601String()
    });
    await save();
  }

  Future<void> updateStorageItem(int i, Map<String,dynamic> item) async {
    if (kIsWeb) return;
    if(i<0||i>=_storageItems.length) return;
    final gid=item['generalId']?.toString()??_storageItems[i]['generalId']??''; final sid=item['specificId']?.toString()??_storageItems[i]['specificId']??'';
    _storageItems[i]={
      'id':item['id']??_storageItems[i]['id'],
      'name':item['name']??_storageItems[i]['name'],
      'generalId':gid,
      'specificId':sid,
      'qty':item['qty']??_storageItems[i]['qty']??1,
      'value':item['value']??_storageItems[i]['value'],
      'valueAmount':item['valueAmount']??_storageItems[i]['valueAmount']??'',
      'notes':item['notes']??_storageItems[i]['notes']??'',
      'photo':item['photo']??_storageItems[i]['photo'],
      'photoPath':item['photoPath']??_storageItems[i]['photoPath'],
      'createdAt':item['createdAt']??_storageItems[i]['createdAt'],
      'modifyDate':DateTime.now().toIso8601String(),
      'updatedAt':DateTime.now().toIso8601String()
    };
    await save();
  }

  Future<void> deleteStorageItem(int i) async { if (kIsWeb) return; if(i>=0&&i<_storageItems.length){ _storageItems.removeAt(i); await save(); } }

  Future<void> addInventoryItem(Map<String,dynamic> item) async {
    if (kIsWeb) return;
    final gid=item['generalId']?.toString()??''; final sid=item['specificId']?.toString()??''; if(gid.isEmpty||sid.isEmpty) return;
    _inventoryItems.add({
      'id':'inv_${DateTime.now().millisecondsSinceEpoch}',
      'name':item['name']??'Unnamed',
      'generalId':gid,
      'specificId':sid,
      'serial_number':item['serial_number']??'',
      'acquisition_date':item['acquisition_date'],
      'value':item['value'],
      'valueAmount':item['valueAmount']??'',
      'notes':item['notes']??'',
      'photo':item['photo'],
      'photoPath':item['photoPath'],
      'createdAt':DateTime.now().toIso8601String(),
      'modifyDate':DateTime.now().toIso8601String(),
      'updatedAt':DateTime.now().toIso8601String()
    });
    await save();
  }

  Future<void> updateInventoryItem(int i, Map<String,dynamic> item) async {
    if (kIsWeb) return;
    if(i<0||i>=_inventoryItems.length) return;
    final gid=item['generalId']?.toString()??_inventoryItems[i]['generalId']??''; final sid=item['specificId']?.toString()??_inventoryItems[i]['specificId']??'';
    _inventoryItems[i]={
      'id':item['id']??_inventoryItems[i]['id'],
      'name':item['name']??_inventoryItems[i]['name'],
      'generalId':gid,
      'specificId':sid,
      'serial_number':item['serial_number']??_inventoryItems[i]['serial_number']??'',
      'acquisition_date':item['acquisition_date']??_inventoryItems[i]['acquisition_date'],
      'value':item['value']??_inventoryItems[i]['value'],
      'valueAmount':item['valueAmount']??_inventoryItems[i]['valueAmount']??'',
      'notes':item['notes']??_inventoryItems[i]['notes']??'',
      'photo':item['photo']??_inventoryItems[i]['photo'],
      'photoPath':item['photoPath']??_inventoryItems[i]['photoPath'],
      'createdAt':item['createdAt']??_inventoryItems[i]['createdAt'],
      'modifyDate':DateTime.now().toIso8601String(),
      'updatedAt':DateTime.now().toIso8601String()
    };
    await save();
  }

  Future<void> deleteInventoryItem(int i) async { if (kIsWeb) return; if(i>=0&&i<_inventoryItems.length){ _inventoryItems.removeAt(i); await save(); } }

  Future<void> addPoiItem(Map<String,dynamic> m) async { if (kIsWeb) return; _poiItems.add(m); await save(); }
  Future<void> updatePoiItem(int i, Map<String,dynamic> m) async { if (kIsWeb) return; if(i>=0&&i<_poiItems.length){ _poiItems[i]=m; await save(); } }
  Future<void> deletePoiItem(int i) async { if (kIsWeb) return; if(i>=0&&i<_poiItems.length){ _poiItems.removeAt(i); await save(); } }
}
