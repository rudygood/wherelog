import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/inventory_records.dart';
import '../data/location_data.dart';
import '../data/photo_store.dart';
import '../data/sqlite_inventory_repository.dart';
import '../data/sqlite_location_repository.dart';
import '../widgets/notes_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class InventoryEditScreen extends StatefulWidget {
  final int itemId;
  const InventoryEditScreen({super.key, required this.itemId});
  @override
  State<InventoryEditScreen> createState() => _InventoryEditScreenState();
}

class _InventoryEditScreenState extends State<InventoryEditScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final serialController = TextEditingController();
  final brandController = TextEditingController();
  final modelController = TextEditingController();
  final purchasePriceController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  DateTime? acquiredDate;
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  File? photoFile;
  String? existingPhotoPath;
  InventoryItem? _loadedItem;
  String? _originalPhotoFilename;
  final _picker = ImagePicker();
  final _locRepo = SqliteLocationRepository.instance;
  final _invRepo = SqliteInventoryRepository.instance;
  final _locationData = SqliteLocationData();
  bool _notesExpanded = false;
  bool _photoDetailsExpanded = true;
  bool _isLoading = true;

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
    if (msg.startsWith('Added:') || msg.startsWith('Saved:')) {
      Future.delayed(const Duration(milliseconds: 1300), () {
        if (mounted) {
          try { if (Navigator.canPop(context)) Navigator.pop(context); } catch (_) {}
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

  String get concatenatedLocation => fullLocationDisplay;

  Map<String, dynamic> _initialSnapshot = {};

  bool _hasUnsavedChanges() {
    if (_loadedItem == null) return false;
    final current = {
      'name': itemNameController.text.trim(),
      'genName': generalController.text.trim(),
      'specName': specificController.text.trim(),
      'notes': notesController.text.trim(),
      'serial': serialController.text.trim(),
      'brand': brandController.text.trim(),
      'model': modelController.text.trim(),
      'qty': qtyController.text.trim(),
      'purchase': purchasePriceController.text.trim(),
      'acquiredDate': acquiredDate == null ? '' : _dateOnly(acquiredDate!),
      'value': valueController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath ?? '',
    };
    final orig = _initialSnapshot;
    return current['name'] != orig['name'] ||
        current['genName'] != orig['genName'] ||
        current['specName'] != orig['specName'] ||
        current['notes'] != orig['notes'] ||
        current['serial'] != orig['serial'] ||
        current['brand'] != orig['brand'] ||
        current['model'] != orig['model'] ||
        current['qty'] != orig['qty'] ||
        current['purchase'] != orig['purchase'] ||
        current['acquiredDate'] != orig['acquiredDate'] ||
        current['value'] != orig['value'] ||
        current['photo'] != orig['photo'];
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

  Future<bool> _confirmDiscard() async {
    if (!_hasUnsavedChanges()) return true;
    final res = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Discard changes?'),
        content: const Text('You have unsaved changes. Discard them and leave?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Keep Editing')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Discard')),
        ],
      ),
    );
    return res == true;
  }

  @override
  void initState() {
    super.initState();
    generalController.addListener(() => setState(() {}));
    specificController.addListener(() => setState(() {}));
    generalFocus.addListener(() => setState(() {}));
    specificFocus.addListener(() => setState(() {}));
    _load();
  }

  Future<void> _load() async {
    await _locationData.load();
    final item = await _invRepo.getById(widget.itemId);
    if (item != null) {
      _loadedItem = item;

      // Resolve display names from the SQLite location tables by id.
      String gName = '';
      String sName = '';
      final generals = await _locRepo.getGenerals();
      for (final g in generals) {
        if (g.id == item.generalId) { gName = g.name; break; }
      }
      if (item.specificId != null) {
        for (final s in await _locRepo.getInventorySpecifics()) {
          if (s.id == item.specificId) {
            sName = s.name;
            if (gName.isEmpty) {
              for (final g in generals) {
                if (g.id == s.generalId) { gName = g.name; break; }
              }
            }
            break;
          }
        }
      }

      generalController.text = gName;
      specificController.text = sName;
      itemNameController.text = item.name;
      notesController.text = item.notes;
      serialController.text = item.serialNumber ?? '';
      brandController.text = item.brand ?? '';
      modelController.text = item.model ?? '';
      qtyController.text = item.quantity.toString();
      if (item.acquisitionDate != null) {
        try { acquiredDate = DateTime.parse(item.acquisitionDate!); } catch (_) {}
      }
      // Money fields show dollars again; the record holds cents.
      purchasePriceController.text = item.purchasePriceCents == null ? '' : (item.purchasePriceCents! / 100).toStringAsFixed(2);
      valueController.text = item.valueCents == null ? '' : (item.valueCents! / 100).toStringAsFixed(2);
      _originalPhotoFilename = item.photoFilename;
      if (item.photoFilename != null) {
        existingPhotoPath = await PhotoStore.pathFor(item.photoFilename!);
        try {
          final f = File(existingPhotoPath!);
          if (await f.exists()) photoFile = f;
        } catch (_) {}
      }
      _initialSnapshot = {
        'name': itemNameController.text.trim(),
        'genName': generalController.text.trim(),
        'specName': specificController.text.trim(),
        'notes': notesController.text.trim(),
        'serial': serialController.text.trim(),
        'brand': brandController.text.trim(),
        'model': modelController.text.trim(),
        'qty': qtyController.text.trim(),
        'purchase': purchasePriceController.text.trim(),
        'acquiredDate': item.acquisitionDate ?? '',
        'value': valueController.text.trim(),
        'photo': existingPhotoPath ?? '',
      };
    }
    if (mounted) setState(() => _isLoading = false);
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

  Future<void> handleSave() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Inventory Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }
    final loaded = _loadedItem;
    if (loaded == null) return;
    final savedName = itemNameController.text.trim();

    // Resolve names to ids against the SQLite location tables. A
    // Specific typed but not yet existing is created, as on the add
    // screen; no Specific typed means specificId stays null
    // ("General only", schema D1).
    final gName = generalController.text.trim();
    final sName = specificController.text.trim();
    int? generalId;
    for (final g in await _locRepo.getGenerals()) {
      if (g.name.toLowerCase() == gName.toLowerCase()) { generalId = g.id; break; }
    }
    if (generalId == null) {
      showCenterNotice('General not found');
      return;
    }
    int? specificId;
    if (sName.isNotEmpty) {
      for (final s in await _locRepo.getInventorySpecifics()) {
        if (s.generalId == generalId && s.name.toLowerCase() == sName.toLowerCase()) { specificId = s.id; break; }
      }
      if (specificId == null) {
        specificId = await _locRepo.addInventorySpecific(generalId, sName);
      }
    }

    int? centsOf(String text) {
      final amt = double.tryParse(text.replaceAll('\$', '').trim());
      return amt == null ? null : (amt * 100).round();
    }

    String? orNull(String text) => text.trim().isEmpty ? null : text.trim();

    final newPhotoFilename = PhotoStore.filenameOf(photoFile?.path);
    final updated = InventoryItem(
      id: loaded.id,
      name: savedName,
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
      photoFilename: newPhotoFilename,
      createdAt: loaded.createdAt,
      modifiedAt: loaded.modifiedAt,
    );

    await _invRepo.update(updated);
    // Photo removed or replaced: the old file goes with the save (the
    // picker already removes it on replace; this is tolerant).
    if (_originalPhotoFilename != null && _originalPhotoFilename != newPhotoFilename) {
      await PhotoStore.deletePhoto(_originalPhotoFilename);
    }
    if (!mounted) return;
    showCenterNotice('Saved: $savedName');
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) Navigator.pop(context, true);
    });
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
              child: Center(
                child: Image.file(file, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: AppColors.white),
                    tooltip: 'Replace',
                    onPressed: () {
                      Navigator.pop(c);
                      
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.white),
                    onPressed: () => Navigator.pop(c),
                  ),
                ],
              ),
            ),
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pinch to zoom — tap \u2715 to close',
                  style: AppText.photoCaption,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDistinctPlaceholder() {
    return Container(
      color: AppColors.surface,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Opacity(opacity: 0.68, child: Image.asset('assets/icon/app_icon.png', width: 64, height: 64, fit: BoxFit.contain)),
            const SizedBox(height: 6),
             Text('No Photo', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 11)),
             Text('Tap to add', style: TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget buildPhotoBoxSquare() {
    final File? existingFile = (existingPhotoPath != null && existingPhotoPath!.isNotEmpty) ? File(existingPhotoPath!) : null;
    final bool existingExists = existingFile != null && existingFile.existsSync();
    final File? displayFile = photoFile ?? (existingExists ? existingFile : null);
    final bool hasPhoto = displayFile != null;
    return InkWell(
      onTap: () {
        if (hasPhoto) {
          openFullPhotoViewer(displayFile!);
        } else {
          
        }
      },
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: AppColors.surface, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: hasPhoto
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Center(
                      child: Image.file(displayFile!, fit: BoxFit.contain),
                    ),
                    Positioned(
                      right: 5,
                      bottom: 5,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                        decoration: BoxDecoration(color: AppColors.textSecondary, borderRadius: BorderRadius.circular(5)),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.zoom_in, size: 11, color: AppColors.white),
                            SizedBox(width: 2),
                            Text('View', style: TextStyle(color: AppColors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                    Positioned(
                      right: 5,
                      top: 5,
                      child: InkWell(
                        onTap: () {},
                        child: Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(5), border: Border.all(color: AppColors.border, width: AppBorder.width)),
                          child:  Icon(Icons.edit, size: 12, color: AppColors.textSecondary),
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

  Widget buildPhotoBox() => buildPhotoBoxSquare();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Inventory'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final ok = await _confirmDiscard();
        if (ok && context.mounted) Navigator.pop(context);
      },
      child: Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Inventory'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              storageKey: 'photoDetailsExpanded_inventory_edit',
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
              storageKey: 'notesExpanded_inventory_edit',
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
            ),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: SizedBox(height: AppSize.buttonHeight, child: OutlinedButton(onPressed: () async { final ok = await _confirmDiscard(); if (ok && mounted) Navigator.pop(context); }, child: const Text('Cancel')))),
              const SizedBox(width: 12),
              Expanded(child: SizedBox(height: AppSize.buttonHeight, child: ElevatedButton(onPressed: handleSave, style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white), child: const Text('Save', style: TextStyle(fontWeight: FontWeight.bold))))),
            ]),
          ]),
        ),
      ),
    );
  }
}
