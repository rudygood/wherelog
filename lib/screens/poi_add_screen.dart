import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/gps_location_section.dart';
import '../widgets/photo_details_section.dart';
import '../widgets/notes_section.dart';
import '../widgets/app_sheet.dart';
import '../wherelog_repository.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'map_picker_screen.dart';

class PoiAddScreen extends StatefulWidget {
  const PoiAddScreen({super.key});
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
  final _repo = WhereLogRepository();
  bool _notesExpanded = true;
  bool _photoExpanded = true;
  bool _isGettingLocation = false;

  @override
  void initState() {
    super.initState();
    _repo.load();
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
          const Icon(Icons.place, size: 48, color: Colors.green),
          const SizedBox(height: 12),
          Text(msg, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
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

      latController.text = pos.latitude.toStringAsFixed(6);
      lngController.text = pos.longitude.toStringAsFixed(6);

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
      setState(() {
        if (result['lat'] != null) latController.text = result['lat']!;
        if (result['lng'] != null) lngController.text = result['lng']!;
        if (result['address'] != null) addressController.text = result['address']!;
      });
    }
  }

  Future<void> openPhotoSheet() async {
    final src = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (c) => SafeArea(
        child: Wrap(children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Take Photo'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Choose from Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          if (photoFile != null) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove Photo'), onTap: () => Navigator.pop(c, null)),
        ]),
      ),
    );
    if (src == null && photoFile != null) {
      setState(() => photoFile = null);
      return;
    }
    if (src == null) return;
    final XFile? img = await _picker.pickImage(source: src, imageQuality: 80, maxWidth: 1024);
    if (img != null) setState(() => photoFile = File(img.path));
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
    final nowIso = DateTime.now().toIso8601String();
    final item = {
      'id': 'poi_${DateTime.now().millisecondsSinceEpoch}',
      'name': nameController.text.trim(),
      'lat': lat,
      'lng': lng,
      'address': addressController.text.trim(),
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'photoPath': photoFile?.path,
      'createdAt': nowIso,
      'modifyDate': nowIso,
      'updatedAt': nowIso,
    };
    await _repo.addPoiItem(item);
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
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              addressController: addressController,
              onPickMap: pickFromMapProgram,
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
