import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/inventory_records.dart';
import '../data/location_data.dart';
import '../data/location_records.dart';
import '../data/photo_store.dart';
import '../data/sqlite_inventory_repository.dart';
import '../data/sqlite_location_repository.dart';
import '../widgets/notes_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryAddScreen extends StatefulWidget {
  const InventoryAddScreen({super.key});
  @override
  State<InventoryAddScreen> createState() => _InventoryAddScreenState();
}

class _InventoryAddScreenState extends State<InventoryAddScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final serialController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final purchasePriceController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  DateTime? acquiredDate;
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  List<String> addedItemsLog = [];
  File? photoFile;
  final _picker = ImagePicker();
  final _locRepo = SqliteLocationRepository.instance;
  final _invRepo = SqliteInventoryRepository.instance;
  final _locationData = SqliteLocationData();
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true;

  void showCenterNotice(String msg) {
    showDialog(
      context: context,
      builder: (c) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sheet)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, size: 48, color: AppColors.success),
              const SizedBox(height: 12),
              Text(msg, style: AppText.dialogNotice, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(c),
                  style: AppButton.primary,
                  child: const Text('OK'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (msg.startsWith('Added:')) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) {
          try {
            if (Navigator.canPop(context)) Navigator.pop(context);
          } catch (_) {}
        }
      });
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
    generalFocus.dispose();
    specificFocus.dispose();
    generalController.dispose();
    specificController.dispose();
    itemNameController.dispose();
    notesController.dispose();
    serialController.dispose();
    brandController.dispose();
    modelController.dispose();
    purchasePriceController.dispose();
    qtyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> handleAdd() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Inventory Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }

    final displayLoc = fullLocationDisplay.isEmpty ? generalController.text.trim() : fullLocationDisplay;
    final hasPhoto = photoFile != null ? ' 📷' : '';
    final addedName = itemNameController.text.trim();
    final serialText = serialController.text.trim();

    // Locations resolve against the SQLite location tables, by name
    // (case-insensitive), mirroring the Storage add screen: a Specific
    // typed but not yet existing is created; no Specific typed means
    // specificId stays null ("General only", schema D1).
    final gName = generalController.text.trim();
    final sName = specificController.text.trim();
    GeneralLocation? general;
    for (final g in await _locRepo.getGenerals()) {
      if (g.name.toLowerCase() == gName.toLowerCase()) { general = g; break; }
    }
    if (general == null || general.id == null) {
      showCenterNotice('General not found');
      return;
    }
    final generalId = general.id!;
    int? specificId;
    if (sName.isNotEmpty) {
      for (final s in await _locRepo.getInventorySpecifics()) {
        if (s.generalId == generalId && s.name.toLowerCase() == sName.toLowerCase()) { specificId = s.id; break; }
      }
      if (specificId == null) {
        specificId = await _locRepo.addInventorySpecific(generalId, sName);
      }
      if (specificId == null) {
        showCenterNotice('Specific not found');
        return;
      }
    }

    int? centsOf(String text) {
      final amt = double.tryParse(text.replaceAll('\$', '').trim());
      return amt == null ? null : (amt * 100).round();
    }

    String? orNull(String text) => text.trim().isEmpty ? null : text.trim();

    final item = InventoryItem(
      name: addedName,
      generalId: generalId,
      specificId: specificId,
      brand: orNull(brandController.text),
      model: orNull(modelController.text),
      serialNumber: orNull(serialController.text),
      acquisitionDate: acquiredDate == null ? null : _dateOnly(acquiredDate!),
      quantity: int.tryParse(qtyController.text.trim()) ?? 1,
      purchasePriceCents: centsOf(purchasePriceController.text),
      valueCents: centsOf(valueController.text),
      notes: notesController.text.trim(),
      photoFilename: PhotoStore.filenameOf(photoFile?.path),
    );

    await _invRepo.add(item);
    setState(() {
      final dateLabel = acquiredDate != null ? ' ${acquiredDate!.month}/${acquiredDate!.day}/${acquiredDate!.year}' : '';
      final serialLabel = serialText.isNotEmpty ? ' S/N:$serialText' : '';
      addedItemsLog.add('$addedName$serialLabel$dateLabel @ $displayLoc$hasPhoto');
    });
    itemNameController.clear();
    notesController.clear();
    serialController.clear();
    brandController.clear();
    modelController.clear();
    purchasePriceController.clear();
    qtyController.text = '1';
    setState(() {
      acquiredDate = null;
    });
    valueController.clear();
    setState(() => photoFile = null);
    showCenterNotice('Added: $addedName @ $displayLoc$hasPhoto');
  }

  /// Acquisition dates are stored date-only (YYYY-MM-DD): no time, no
  /// timezone, so the date can never drift a day either way.
  String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> pickAcquiredDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(context: context, initialDate: acquiredDate ?? now, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null) setState(() => acquiredDate = picked);
  }

  Future<void> openNotesEditor() async {
    final tempCtrl = TextEditingController(text: notesController.text);
    final result = await showDialog<String>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Edit Notes'),
        content: TextField(controller: tempCtrl, textCapitalization: TextCapitalization.sentences, minLines: 4, maxLines: 8),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(c, tempCtrl.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null) setState(() => notesController.text = result);
  }

  

  Future<void> openFullPhotoViewer(File file) async {
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        backgroundColor: AppColors.buttonBg,
        insetPadding: const EdgeInsets.all(10),
        child: Stack(
          children: [
            InteractiveViewer(
              child: Center(child: Image.file(file, fit: BoxFit.contain)),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.edit, color: AppColors.white), tooltip: 'Replace', onPressed: () { Navigator.pop(c); }),
                  IconButton(icon: const Icon(Icons.close, color: AppColors.white), onPressed: () => Navigator.pop(c)),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(child: Text('Pinch to zoom — tap ✕ to close', style: AppText.photoCaption)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistinctPlaceholder() {
    return Container(
      color: AppColors.white,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.68, child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64, fit: BoxFit.contain)),
            const SizedBox(height: 6),
            const Text('No Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 11)),
            const Text('Tap to add', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget buildPhotoBoxSquare() {
    final bool hasPhoto = photoFile != null;
    return InkWell(
      onTap: () {
        if (hasPhoto) {
          openFullPhotoViewer(photoFile!);
        } else {
          
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(child: Image.file(photoFile!, fit: BoxFit.contain)),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(5)),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.zoom_in, size: 11, color: AppColors.white), SizedBox(width: 2), Text('View', style: TextStyle(color: AppColors.white, fontSize: 9, fontWeight: FontWeight.bold))]),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: InkWell(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: AppColors.white, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.border, width: AppBorder.width)),
                          child: const Icon(Icons.edit, size: 12, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                )
              : _buildDistinctPlaceholder(),
        ),
      ),
    );
  }

  Widget buildPhotoBox() {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: double.infinity,
        height: 110,
        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)),
        child: photoFile == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_a_photo_outlined, size: 32, color: AppColors.textDisabled),
                  SizedBox(height: 6),
                  Text('Add Photo (optional)', style: TextStyle(color: AppColors.textDisabled, fontWeight: FontWeight.w600)),
                  SizedBox(height: 2),
                  Text('Tap to take or choose', style: TextStyle(color: AppColors.border, fontSize: 11)),
                ],
              )
            : ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: Image.file(photoFile!, width: double.infinity, height: 110, fit: BoxFit.cover),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Add Inventory'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RequiredSection(
              source: RequiredSectionSource.inventory,
              generalController: generalController,
              specificController: specificController,
              itemNameController: itemNameController,
              generalFocus: generalFocus,
              specificFocus: specificFocus,
              data: _locationData,
              itemHint: 'Inventory Item',
            ),
            const SizedBox(height: 14),
            PhotoDetailsSection(
              storageKey: 'photoDetailsExpanded_inventory_add',
              isExpanded: _photoDetailsExpanded,
              onToggle: () => setState(() => _photoDetailsExpanded = !_photoDetailsExpanded),
              variant: PhotoDetailsVariant.inventory,
              photoFile: photoFile,
              onPhotoChanged: (f) => setState(() => photoFile = f),
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              
              valueController: valueController,
              serialController: serialController,
              brandController: brandController,
              modelController: modelController,
              purchasePriceController: purchasePriceController,
              qtyController: qtyController,
              acquiredDate: acquiredDate,
              onPickAcquiredDate: () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: acquiredDate ?? now,
                  firstDate: DateTime(2000),
                  lastDate: DateTime(now.year + 5),
                );
                if (picked != null) setState(() => acquiredDate = picked);
              },
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 14),
            NotesSection(
              storageKey: 'notesExpanded_inventory_add',
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Expanded(child: Text('General / Specific does not reset so you can add multiple items, but you can change it when needed.', style: TextStyle(fontSize: 11, color: AppColors.textPrimary, fontWeight: FontWeight.w600, height: 1.3))),
                const SizedBox(width: 12),
                SizedBox(
                  height: 36,
                  child: ElevatedButton(
                    onPressed: handleAdd,
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white, padding: const EdgeInsets.symmetric(horizontal: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button))),
                    child: const Text('+ Add Item', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              ],
            ),
            if (addedItemsLog.isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text('ADDED THIS SESSION', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textPrimary)),
              const SizedBox(height: 6),
              ...addedItemsLog.map((l) => Padding(padding: const EdgeInsets.only(bottom: 3), child: Text('• $l', style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: AppColors.textPrimary)))),
            ],
          ],
        ),
      ),
    );
  }
}
