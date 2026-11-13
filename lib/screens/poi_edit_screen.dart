import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gps_location_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/notes_section.dart';
import '../widgets/app_sheet.dart';
import '../data/photo_store.dart';
import '../data/poi_records.dart';
import '../data/sqlite_poi_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'map_picker_screen.dart';
import '../utils/map_utils.dart';

class PoiEditScreen extends StatefulWidget {
  final int poiId;
  const PoiEditScreen({super.key, required this.poiId});
  @override
  State<PoiEditScreen> createState() => _PoiEditScreenState();
}

class _PoiEditScreenState extends State<PoiEditScreen> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final valueController = TextEditingController();
  File? photoFile;
  String? existingPhotoPath;
  PoiItem? _loadedItem;
  String? _originalPhotoFilename;
  final _picker = ImagePicker();
  final _poiRepo = SqlitePoiRepository.instance;
  bool _notesExpanded = true;
  bool _photoExpanded = true;
  bool _isGettingLocation = false;
  bool _isLoading = true;

  /// Provenance of the record's coordinates: the stored source,
  /// replaced by whichever control sets the coordinates last
  /// ('Device GPS', 'Map pick', 'Manual entry').
  String? _coordsSource;
  bool _applyingCoords = false;

  void _coordsEdited() {
    if (_applyingCoords || !mounted) return;
    if (_coordsSource != 'Manual entry') setState(() => _coordsSource = 'Manual entry');
  }

  @override
  void initState() {
    super.initState();
    latController.addListener(_coordsEdited);
    lngController.addListener(_coordsEdited);
    _load();
  }

  Future<void> _load() async {
    final item = await _poiRepo.getById(widget.poiId);
    if (item != null) {
      _loadedItem = item;
      nameController.text = item.name;
      notesController.text = item.notes;
      addressController.text = item.address;
      _applyingCoords = true;
      latController.text = item.latitude.toString();
      lngController.text = item.longitude.toString();
      _coordsSource = item.source;
      _applyingCoords = false;
      _originalPhotoFilename = item.photoFilename;
      if (item.photoFilename != null) {
        existingPhotoPath = await PhotoStore.pathFor(item.photoFilename!);
        try {
          final f = File(existingPhotoPath!);
          if (await f.exists()) photoFile = f;
        } catch (_) {}
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    nameController.dispose();
    notesController.dispose();
    addressController.dispose();
    latController.dispose();
    lngController.dispose();
    valueController.dispose();
    super.dispose();
  }

  Future<void> showCenterNotice(String msg) {
    return showModalTopSheet<void>(
      context: context,
      maxWidth: 360,
      backgroundColor: AppColors.surface,
      builder: (c, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
           Icon(Icons.place, size: 48, color: AppColors.notice),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: AppText.dialogNotice),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(c),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white),
              child: const Text('OK'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> captureCurrentGps() async {
    if (_isGettingLocation) return;
    setState(() => _isGettingLocation = true);
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await showCenterNotice('Location services are disabled.\nEnable Location in quick settings.');
        await Geolocator.openLocationSettings();
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await showCenterNotice('Location permission denied.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        await showCenterNotice('Location permission permanently denied.\nOpen App Settings > Permissions > Allow.');
        await Geolocator.openAppSettings();
        return;
      }

      Position? pos = await Geolocator.getLastKnownPosition();
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        if (pos == null) rethrow;
      }

      if (pos == null) {
        await showCenterNotice('No GPS fix. Move outside / near window, wait 30s.');
        return;
      }

      _applyingCoords = true;
      latController.text = pos.latitude.toStringAsFixed(6);
      lngController.text = pos.longitude.toStringAsFixed(6);
      _applyingCoords = false;
      _coordsSource = 'Device GPS';

      try {
        List<Placemark> marks = await Geocoding().placemarkFromCoordinates(pos.latitude, pos.longitude);
        if (marks.isNotEmpty) {
          final m = marks.first;
          final parts = [
            if (m.street != null && m.street!.isNotEmpty) m.street,
            if (m.locality != null && m.locality!.isNotEmpty) m.locality,
            if (m.administrativeArea != null && m.administrativeArea!.isNotEmpty) m.administrativeArea,
            if (m.country != null && m.country!.isNotEmpty) m.country,
          ];
          if (parts.isNotEmpty) addressController.text = parts.join(', ');
        }
      } catch (_) {}
    } catch (e) {
      await showCenterNotice('GPS Error:\n$e');
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> pickFromMapProgram() async {
    final double? initLat = double.tryParse(latController.text.trim());
    final double? initLng = double.tryParse(lngController.text.trim());
    final result = await Navigator.push<Map<String, String>>(
      context,
      MaterialPageRoute(
        builder: (_) => MapPickerScreen(
          initialLat: initLat,
          initialLng: initLng,
          initialAddress: addressController.text,
        ),
      ),
    );
    if (result != null) {
      _applyingCoords = true;
      setState(() {
        if (result['lat'] != null) latController.text = result['lat']!;
        if (result['lng'] != null) lngController.text = result['lng']!;
        if (result['address'] != null) addressController.text = result['address']!;
        _coordsSource = 'Map pick';
      });
      _applyingCoords = false;
    }
  }

  

  Future<void> openFullPhotoViewer(File file) async {
    await showDialog(
      context: context,
      builder: (c) => Dialog(
        child: Stack(children: [
          Center(child: Image.file(file, fit: BoxFit.contain)),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(icon: const Icon(Icons.close, color: AppColors.white), onPressed: () => Navigator.pop(c)),
          ),
        ]),
      ),
    );
  }

  Future<void> handleSave() async {
    if (nameController.text.trim().isEmpty) {
      showCenterNotice('Enter Place Name');
      return;
    }
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) {
      showCenterNotice('Enter valid GPS coordinates');
      return;
    }
    final loaded = _loadedItem;
    if (loaded == null) return;
    final newPhotoFilename = PhotoStore.filenameOf(photoFile?.path);
    final item = PoiItem(
      id: loaded.id,
      name: nameController.text.trim(),
      latitude: lat,
      longitude: lng,
      address: addressController.text.trim(),
      notes: notesController.text.trim(),
      photoFilename: newPhotoFilename,
      source: _coordsSource,
      createdAt: loaded.createdAt,
      modifiedAt: loaded.modifiedAt,
    );
    await _poiRepo.update(item);
    // Photo removed or replaced: the old file goes with the save (the
    // picker already removes it on replace; this is tolerant).
    if (_originalPhotoFilename != null && _originalPhotoFilename != newPhotoFilename) {
      await PhotoStore.deletePhoto(_originalPhotoFilename);
    }
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppColors.scaffold,
        appBar: const AppHeader(screenName: 'Edit Place of Interest'),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Edit Place of Interest'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GpsLocationSection(
              nameController: nameController,
              latController: latController,
              lngController: lngController,
              isGettingLocation: _isGettingLocation,
              onCurrentGps: captureCurrentGps,
              onPickMap: pickFromMapProgram,
            ),
            const SizedBox(height: 12),
            // Map Directions - using pure-code AppIcons.directions (no asset needed)
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: latController,
              builder: (_, __, ___) => ValueListenableBuilder<TextEditingValue>(
                valueListenable: lngController,
                builder: (_, __, ___) {
                  final hasCoords = MapUtils.hasCoordinates(latController.text, lngController.text);
                  return SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: hasCoords
                          ? () {
                              final lat = double.parse(latController.text.trim());
                              final lng = double.parse(lngController.text.trim());
                              MapUtils.openDirections(lat: lat, lng: lng, label: nameController.text.trim());
                            }
                          : null,
                      // PNG with transparent interior - inverts via color tint
                      icon: ImageIcon(AssetImage('assets/icon/directions_diamond.png'), size: 22, color: AppColors.white),
                      label: const Text('Map Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCoords ? AppColors.buttonBg : AppColors.disabledSurface,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: AppColors.disabledSurface,
                        disabledForegroundColor: AppColors.textDisabled,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            PhotoDetailsSection(
              isExpanded: _photoExpanded,
              onToggle: () => setState(() => _photoExpanded = !_photoExpanded),
              variant: PhotoDetailsVariant.poi,
              photoFile: photoFile,
              onPhotoChanged: (f) => setState(() => photoFile = f),
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              
              valueController: valueController,
              addressController: addressController,
              onPickMap: pickFromMapProgram,
              coordsSource: _coordsSource ?? 'Not recorded',
              storageKey: 'photoDetailsExpanded_poi_edit',
            ),
            const SizedBox(height: 16),
            NotesSection(
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
              storageKey: 'notesExpanded_poi_edit',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: handleSave,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonBg,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
                child: const Text('Save Changes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
