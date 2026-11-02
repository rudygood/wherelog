
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../data/location_data.dart';
import '../data/location_records.dart';
import '../data/photo_store.dart';
import '../data/sqlite_location_repository.dart';
import '../data/sqlite_storage_repository.dart';
import '../data/storage_records.dart';
import '../widgets/notes_section.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageAddScreen extends StatefulWidget {
  const StorageAddScreen({super.key});
  @override
  State<StorageAddScreen> createState() => _StorageAddScreenState();
}

class _StorageAddScreenState extends State<StorageAddScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  List<String> addedItemsLog = [];
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true;
  File? photoFile;
  final _picker = ImagePicker();
  final _locRepo = SqliteLocationRepository.instance;
  final _storageRepo = SqliteStorageRepository.instance;
  final _locationData = SqliteLocationData();

  void showCenterNotice(String msg) {
    showDialog(context: context, builder: (c) => Dialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)), child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.check_circle, size: 48, color: AppColors.success), const SizedBox(height: 12), Text(msg, style: AppText.dialogNotice, textAlign: TextAlign.center), const SizedBox(height: 16), SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.pop(c), style: AppButton.primary, child: const Text('OK')))]))));
    if (msg.startsWith('Added:')) {
      Future.delayed(const Duration(milliseconds: 1300), () { if (mounted) { try { if (Navigator.canPop(context)) Navigator.pop(context); } catch (_) {} } });
    }
  }

  String get fullLocationDisplay {
    final g = generalController.text.trim();
    final s = specificController.text.trim();
    if (g.isNotEmpty && s.isNotEmpty) return '$g / $s';
    return g.isNotEmpty ? g : s;
  }

  @override
  void initState() {
    super.initState();
    _locationData.load().then((_) => setState(() {}));
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    generalFocus.dispose(); specificFocus.dispose();
    generalController.dispose(); specificController.dispose();
    itemNameController.dispose(); notesController.dispose(); qtyController.dispose(); valueController.dispose();
    super.dispose();
  }

  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) { showCenterNotice('Enter Stored Item'); return; }
    if (generalController.text.trim().isEmpty) { showCenterNotice('Pick General'); return; }
    final gName = generalController.text.trim();
    final sName = specificController.text.trim();
    // Locations resolve against the SQLite location tables, by name
    // (case-insensitive, as the old repository resolved them).
    GeneralLocation? general;
    for (final g in await _locRepo.getGenerals()) {
      if (g.name.toLowerCase() == gName.toLowerCase()) { general = g; break; }
    }
    if (general == null || general.id == null) { showCenterNotice('General not found'); return; }
    final generalId = general.id!;
    // No Specific typed means "General only": specificId stays null
    // (schema D1 — there is no blank-name sentinel row any more).
    int? specificId;
    if (sName.isNotEmpty) {
      for (final s in await _locRepo.getStorageSpecifics()) {
        if (s.generalId == generalId && s.name.toLowerCase() == sName.toLowerCase()) { specificId = s.id; break; }
      }
      if (specificId == null) {
        specificId = await _locRepo.addStorageSpecific(generalId, sName);
      }
      if (specificId == null) { showCenterNotice('Specific not found'); return; }
    }
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());
    final item = StorageItem(
      name: itemNameController.text.trim(),
      generalId: generalId,
      specificId: specificId,
      quantity: qty,
      valueCents: valueAmt == null ? null : (valueAmt * 100).round(),
      notes: notesController.text.trim(),
      photoFilename: PhotoStore.filenameOf(photoFile?.path),
    );
    await _storageRepo.add(item);
    setState(() { addedItemsLog.add('${item.name} x$qty @ $fullLocationDisplay${photoFile!=null?' 📷':''}'); });
    itemNameController.clear();
    showCenterNotice('Added: ${item.name}');
  }

  
  void openFullPhotoViewer(File f) { showDialog(context: context, builder: (c)=>Dialog(child: Image.file(f))); }
  Widget _buildDistinctPlaceholder() => Center(child: Icon(Icons.inventory_2_outlined, size: 40, color: AppColors.textDisabled));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Add Storage'),
      body: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16,8,16,16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        RequiredSection(source: RequiredSectionSource.storage, generalController: generalController, specificController: specificController, itemNameController: itemNameController, generalFocus: generalFocus, specificFocus: specificFocus, data: _locationData, itemHint: 'Stored Item'),
        const SizedBox(height:14),
        PhotoDetailsSection(isExpanded: _photoDetailsExpanded, onToggle: ()=>setState(()=>_photoDetailsExpanded=!_photoDetailsExpanded), variant: PhotoDetailsVariant.storage, storageKey: 'photoDetailsExpanded_storage_add', photoFile: photoFile, onPhotoChanged: (f) => setState(() => photoFile = f), onPhotoView: ()=>photoFile!=null?openFullPhotoViewer(photoFile!):null,  valueController: valueController, qtyController: qtyController),
        const SizedBox(height:14),
        NotesSection(storageKey: 'notesExpanded_storage_add', controller: notesController, isExpanded: _notesExpanded, onToggle: ()=>setState(()=>_notesExpanded=!_notesExpanded)),
        const SizedBox(height:16),
        Row(children: [const Expanded(child: Text('General / Specific does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize: 11, color: AppColors.buttonBg, fontWeight: FontWeight.w600, height: 1.3))), const SizedBox(width:12), SizedBox(height:36, child: ElevatedButton(onPressed: handleAdd, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, padding: EdgeInsets.symmetric(horizontal:16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))), child: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))))]),
        if (addedItemsLog.isNotEmpty) ...[const SizedBox(height:18), const Text('ADDED THIS SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.buttonBg)), const SizedBox(height:6), ...addedItemsLog.map((l)=>Padding(padding: const EdgeInsets.only(bottom:3), child: Text('• $l', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.buttonBg))))],
      ])),
    );
  }
}
