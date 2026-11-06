import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/location_data.dart';
import '../data/photo_store.dart';
import '../data/sqlite_location_repository.dart';
import '../data/sqlite_storage_repository.dart';
import '../data/storage_records.dart';
import '../widgets/notes_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/app_header.dart';
import '../widgets/required_section.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

class StorageEditScreen extends StatefulWidget {
  final int itemId;
  const StorageEditScreen({super.key, required this.itemId});
  @override
  State<StorageEditScreen> createState() => _StorageEditScreenState();
}

class _StorageEditScreenState extends State<StorageEditScreen> {
  final generalController = TextEditingController();
  final specificController = TextEditingController();
  final itemNameController = TextEditingController();
  final notesController = TextEditingController();
  final qtyController = TextEditingController(text: '1');
  final valueController = TextEditingController();
  final generalFocus = FocusNode();
  final specificFocus = FocusNode();
  File? photoFile;
  String? existingPhotoPath;
  StorageItem? _loadedItem;
  String? _originalPhotoFilename;
  final _picker = ImagePicker();
  final _locRepo = SqliteLocationRepository.instance;
  final _storageRepo = SqliteStorageRepository.instance;
  final _locationData = SqliteLocationData();
  bool _isLoading = true;
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
      'generalCtrl': generalController.text.trim(),
      'specificCtrl': specificController.text.trim(),
      'notes': notesController.text.trim(),
      'qty': qtyController.text.trim(),
      'value': valueController.text.trim(),
      'photo': photoFile?.path ?? existingPhotoPath ?? '',
    };
    final orig = _initialSnapshot;
    return current['name'] != orig['name'] ||
        current['generalCtrl'] != orig['generalCtrl'] ||
        current['specificCtrl'] != orig['specificCtrl'] ||
        current['notes'] != orig['notes'] ||
        current['qty'] != orig['qty'] ||
        current['value'] != orig['value'] ||
        current['photo'] != orig['photo'];
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
    final item = await _storageRepo.getById(widget.itemId);
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
        for (final s in await _locRepo.getStorageSpecifics()) {
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
      qtyController.text = item.quantity.toString();
      // The value field shows dollars again; the record holds cents.
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
        'generalCtrl': generalController.text.trim(),
        'specificCtrl': specificController.text.trim(),
        'notes': notesController.text.trim(),
        'qty': qtyController.text.trim(),
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
    qtyController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> handleSave() async {
    if (itemNameController.text.trim().isEmpty) {
      showCenterNotice('Enter Stored Item');
      return;
    }
    if (generalController.text.trim().isEmpty) {
      showCenterNotice('Pick General');
      return;
    }
    final loaded = _loadedItem;
    if (loaded == null) return;
    final savedName = itemNameController.text.trim();
    final qty = int.tryParse(qtyController.text.trim()) ?? 1;
    final valueText = valueController.text.trim();
    final valueAmt = double.tryParse(valueText.replaceAll('\$', '').trim());

    // Resolve names to ids against the SQLite location tables. A Specific
    // typed but not yet existing is created, as before; no Specific typed
    // means specificId stays null ("General only", schema D1).
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
      for (final s in await _locRepo.getStorageSpecifics()) {
        if (s.generalId == generalId && s.name.toLowerCase() == sName.toLowerCase()) { specificId = s.id; break; }
      }
      if (specificId == null) {
        specificId = await _locRepo.addStorageSpecific(generalId, sName);
      }
    }

    final newPhotoFilename = PhotoStore.filenameOf(photoFile?.path);
    final updated = StorageItem(
      id: loaded.id,
      name: savedName,
      generalId: generalId,
      specificId: specificId,
      quantity: qty,
      valueCents: valueAmt == null ? null : (valueAmt * 100).round(),
      notes: notesController.text.trim(),
      photoFilename: newPhotoFilename,
      createdAt: loaded.createdAt,
      modifiedAt: loaded.modifiedAt,
    );

    await _storageRepo.update(updated);
    // If the photo was removed or replaced, the old file goes with the
    // save (the picker already removes it on replace; this is tolerant).
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
            const Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  'Pinch to zoom — tap ✕ to close',
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
        decoration: BoxDecoration(color: AppColors.white, border: Border.all(color: AppColors.border, width: AppBorder.width), borderRadius: BorderRadius.circular(AppRadius.button)),
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

  Widget buildPhotoBox() => buildPhotoBoxSquare();

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Storage'),
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
        appBar: const AppHeader(screenName: 'Edit Storage'),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            RequiredSection(
              source: RequiredSectionSource.storage,
              generalController: generalController,
              specificController: specificController,
              itemNameController: itemNameController,
              generalFocus: generalFocus,
              specificFocus: specificFocus,
              data: _locationData,
              itemHint: 'Stored Item',
            ),
            const SizedBox(height: 14),
            PhotoDetailsSection(
              storageKey: 'photoDetailsExpanded_storage_edit',
              isExpanded: _photoDetailsExpanded,
              onToggle: () => setState(() => _photoDetailsExpanded = !_photoDetailsExpanded),
              variant: PhotoDetailsVariant.storage,
              photoFile: photoFile,
              onPhotoChanged: (f) => setState(() => photoFile = f),
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              
              valueController: valueController,
              qtyController: qtyController,
            ),
            const SizedBox(height: 14),
            const SizedBox(height: 14),
            NotesSection(
              storageKey: 'notesExpanded_storage_edit',
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
