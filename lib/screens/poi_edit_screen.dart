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
import '../utils/map_utils.dart';

class PoiEditScreen extends StatefulWidget {
  final int itemIndex;
  const PoiEditScreen({super.key, required this.itemIndex});
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
  final _picker = ImagePicker();
  final _repo = WhereLogRepository();
  bool _notesExpanded = true;
  bool _photoExpanded = true;
  bool _isGettingLocation = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _repo.load().then((_) {
      if (_repo.poiItems.length > widget.itemIndex) {
        final item = _repo.poiItems[widget.itemIndex];
        setState(() {
          nameController.text = (item['name'] ?? '').toString();
          notesController.text = (item['notes'] ?? '').toString();
          addressController.text = (item['address'] ?? '').toString();
          latController.text = (item['lat'] ?? '').toString();
          lngController.text = (item['lng'] ?? '').toString();
          if ((item['photo'] ?? item['photoPath'] ?? '').toString().isNotEmpty) {
            try {
              photoFile = File((item['photo'] ?? item['photoPath']).toString());
            } catch (_) {}
          }
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    });
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

      latController.text = pos.latitude.toStringAsFixed(6);
      lngController.text = pos.longitude.toStringAsFixed(6);

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
      setState(() {
        if (result['lat'] != null) latController.text = result['lat']!;
        if (result['lng'] != null) lngController.text = result['lng']!;
        if (result['address'] != null) addressController.text = result['address']!;
      });
    }
  }

  Future<void> openPhotoSheet() async {
    final src = await showModalTopSheet<ImageSource>(
      context: context,
      builder: (c, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Camera'), onTap: () => Navigator.pop(c, ImageSource.camera)),
          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Gallery'), onTap: () => Navigator.pop(c, ImageSource.gallery)),
          if (photoFile != null) ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Remove Photo'), onTap: () => Navigator.pop(c, null)),
        ],
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
    final nowIso = DateTime.now().toIso8601String();
    final existing = (_repo.poiItems.length > widget.itemIndex) ? _repo.poiItems[widget.itemIndex] : <String, dynamic>{};
    final item = {
      'id': existing['id'] ?? 'poi_${DateTime.now().millisecondsSinceEpoch}',
      'name': nameController.text.trim(),
      'lat': lat,
      'lng': lng,
      'address': addressController.text.trim(),
      'notes': notesController.text.trim(),
      'photo': photoFile?.path,
      'photoPath': photoFile?.path,
      'createdAt': existing['createdAt'] ?? nowIso,
      'modifyDate': nowIso,
      'updatedAt': nowIso,
    };
    await _repo.updatePoiItem(widget.itemIndex, item);
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
                      icon: ImageIcon(AssetImage('assets/icon/directions_diamond.png'), size: 22, color: Colors.white),
                      label: const Text('Map Directions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: hasCoords ? AppColors.buttonBg : Colors.grey.shade300,
                        foregroundColor: AppColors.white,
                        disabledBackgroundColor: Colors.grey.shade300,
                        disabledForegroundColor: Colors.grey.shade600,
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
              onPhotoAdd: openPhotoSheet,
              onPhotoView: () => openFullPhotoViewer(photoFile!),
              onPhotoEdit: openPhotoSheet,
              valueController: valueController,
              addressController: addressController,
              onPickMap: pickFromMapProgram,
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
