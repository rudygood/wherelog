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

class PoiAddScreen extends StatefulWidget {
  const PoiAddScreen({super.key, this.initialName, this.initialLat, this.initialLng, this.initialAddress, this.initialSource, this.initialNameIsPlaceholder = false});
  final String? initialName;
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  /// Provenance carried from a staged import; null for a direct add.
  final String? initialSource;

  /// True when [initialName] is a generated import label rather
  /// than a real name (see PoiImportData.nameIsPlaceholder).
  final bool initialNameIsPlaceholder;
  @override
  State<PoiAddScreen> createState() => _PoiAddScreenState();
}

class _PoiAddScreenState extends State<PoiAddScreen> {
  final nameController = TextEditingController();
  final notesController = TextEditingController();
  final addressController = TextEditingController();
  final latController = TextEditingController();
  final lngController = TextEditingController();
  final valueController = TextEditingController();
  File? photoFile;
  final _picker = ImagePicker();
  final _poiRepo = SqlitePoiRepository.instance;
  bool _notesExpanded = true;
  bool _photoExpanded = true;
  bool _isGettingLocation = false;

  /// Provenance of the coordinates as they will be saved. For a
  /// direct add this is whichever control set the coordinates
  /// last ('Device GPS', 'Map pick', 'Manual entry'). A staged
  /// import instead KEEPS its original source for the whole
  /// screen: position changes are the verification screen's
  /// business, and if the saved point differs from the point
  /// handed over, handleAdd marks the source ' (adjusted)'.
  String? _coordsSource;
  bool _applyingCoords = false;

  void _coordsEdited() {
    if (_applyingCoords || !mounted) return;
    if (widget.initialSource != null) return;
    if (_coordsSource != 'Manual entry') setState(() => _coordsSource = 'Manual entry');
  }

  @override
  void initState() {
    super.initState();
    // Precise alteration for POI Import - prefill from shared data, preserve all existing features
    if (widget.initialName != null) nameController.text = widget.initialName!;
    if (widget.initialAddress != null) addressController.text = widget.initialAddress!;
    if (widget.initialLat != null) latController.text = widget.initialLat!.toStringAsFixed(6);
    if (widget.initialLng != null) lngController.text = widget.initialLng!.toStringAsFixed(6);
    _coordsSource = widget.initialSource;
    latController.addListener(_coordsEdited);
    lngController.addListener(_coordsEdited);
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
      backgroundColor: AppColors.white,
      builder: (c, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.place, size: 48, color: AppColors.notice),
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
      // 1. Service enabled?
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        await showCenterNotice('Location services are disabled.\n\nPlease enable Location in quick settings, then try again.');
        await Geolocator.openLocationSettings();
        return;
      }

      // 2. Permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          await showCenterNotice('Location permission denied.\nAllow location to use Device GPS.');
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        await showCenterNotice('Location permission permanently denied.\nOpen App Settings > Permissions > Location > Allow.');
        await Geolocator.openAppSettings();
        return;
      }

      // 3. Try last known first (fast on tablets)
      Position? pos = await Geolocator.getLastKnownPosition();
      
      // 4. Get current high accuracy - 30s timeout for WiFi tablets
      try {
        pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 30),
        );
      } catch (e) {
        // If getCurrentPosition fails but we have lastKnown, use it
        if (pos == null) rethrow;
      }

      if (pos == null) {
        await showCenterNotice('Could not get GPS fix.\n\nMove near window / outside, wait 30 sec for tablet GPS.');
        return;
      }

      _applyingCoords = true;
      latController.text = pos.latitude.toStringAsFixed(6);
      lngController.text = pos.longitude.toStringAsFixed(6);
      _applyingCoords = false;
      if (widget.initialSource == null) _coordsSource = 'Device GPS';

      // 5. Reverse geocode address
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
      } catch (_) {
        // geocoding failed but we have coords - fine
      }

      if (nameController.text.trim().isEmpty && addressController.text.isNotEmpty) {
        // optional: suggest name from address
      }

    } on LocationServiceDisabledException {
      await showCenterNotice('Location services disabled. Enable Location.');
    } catch (e) {
      await showCenterNotice('GPS Error:\n$e\n\nTip: On tablet, go outside, enable WiFi + Location, wait for fix.');
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
        if (widget.initialSource == null) _coordsSource = 'Map pick';
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

  Future<void> handleAdd() async {
    final typedName = nameController.text.trim();
    if (typedName.isEmpty) {
      showCenterNotice('Enter Place Name');
      return;
    }
    final lat = double.tryParse(latController.text.trim());
    final lng = double.tryParse(lngController.text.trim());
    if (lat == null || lng == null) {
      showCenterNotice('Enter valid GPS coordinates');
      return;
    }
    var saveName = typedName;
    // A staged import's placeholder label is scaffolding, not a
    // name: if it is still in the field untouched, ask comfortably
    // before it can become anything permanent.
    if (widget.initialNameIsPlaceholder && typedName == widget.initialName) {
      final ok = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius), side: AppBorder.side),
        title: const Text('Name this place?', style: AppText.dialogTitle),
        content: Text('This place still has the label from its import ("${widget.initialName}"). Is it OK to save it as "Unnamed place" for now? You can rename it any time from the edit screen.', style: const TextStyle(fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Name it now')),
          ElevatedButton(onPressed: () => Navigator.pop(c, true), child: const Text('Save as Unnamed place')),
        ],
      ));
      if (ok != true) return;
      saveName = 'Unnamed place';
    }
    // A staged import keeps its source, but if the point being
    // saved differs from the point handed over (moved on the
    // verification screen or here), the source says so. The
    // comparison allows 1e-5 degrees (~1 m): the coordinate
    // fields carry six decimals, so an untouched point returns
    // a hair different from the exact value handed over, and
    // that rounding is not an adjustment.
    var saveSource = _coordsSource;
    if (widget.initialSource != null &&
        widget.initialLat != null &&
        widget.initialLng != null &&
        ((lat - widget.initialLat!).abs() > 1e-5 ||
            (lng - widget.initialLng!).abs() > 1e-5)) {
      final base = widget.initialSource!;
      saveSource = base.endsWith(' (adjusted)') ? base : '$base (adjusted)';
    }
    final item = PoiItem(
      name: saveName,
      latitude: lat,
      longitude: lng,
      address: addressController.text.trim(),
      notes: notesController.text.trim(),
      photoFilename: PhotoStore.filenameOf(photoFile?.path),
      source: saveSource,
    );
    await _poiRepo.add(item);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Add Place of Interest'),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The import map-check notice used to live here; it
            // now sits on the import verification screen, which
            // every staged import passes through before this
            // screen opens. Direct adds never saw it either way.
            GpsLocationSection(
              nameController: nameController,
              latController: latController,
              lngController: lngController,
              isGettingLocation: _isGettingLocation,
              onCurrentGps: captureCurrentGps,
              onPickMap: pickFromMapProgram,
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
              coordsSource: _coordsSource,
              storageKey: 'photoDetailsExpanded_poi_add',
            ),
            const SizedBox(height: 16),
            NotesSection(
              controller: notesController,
              isExpanded: _notesExpanded,
              onToggle: () => setState(() => _notesExpanded = !_notesExpanded),
              storageKey: 'notesExpanded_poi_add',
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: handleAdd,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.buttonBg,
                  foregroundColor: AppColors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.button)),
                ),
                child: const Text('Save Place', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
