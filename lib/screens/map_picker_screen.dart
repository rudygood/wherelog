import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng, this.initialAddress});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  LatLng? _picked;
  String _address = '';
  bool _isGeocoding = false;
  bool _isGettingLocation = false;
  double _currentZoom = 16.0;

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _address = widget.initialAddress ?? '';
    }
  }

  Future<void> _reverseGeocode(LatLng p) async {
    setState(() => _isGeocoding = true);
    try {
      final marks = await Geocoding().placemarkFromCoordinates(p.latitude, p.longitude);
      if (marks.isNotEmpty) {
        final m = marks.first;
        final parts = [
          if (m.street != null && m.street!.isNotEmpty) m.street,
          if (m.locality != null && m.locality!.isNotEmpty) m.locality,
          if (m.administrativeArea != null && m.administrativeArea!.isNotEmpty) m.administrativeArea,
          if (m.country != null && m.country!.isNotEmpty) m.country,
        ];
        setState(() => _address = parts.join(', '));
      }
    } catch (_) {
      // ignore
    } finally {
      if (mounted) setState(() => _isGeocoding = false);
    }
  }

  void _onTapMap(TapPosition _, LatLng p) {
    setState(() => _picked = p);
    _reverseGeocode(p);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Location permission denied')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _picked = ll);
      _mapController.move(ll, 17.0);
      _currentZoom = 17.0;
      await _reverseGeocode(ll);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(2.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(2.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _goToPicked() {
    if (_picked != null) {
      _mapController.move(_picked!, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    final initialCenter = _picked ?? const LatLng(38.879, -78.36); // Stanley, VA
    final initialZoom = _picked != null ? 16.0 : 8.0;
    _currentZoom = initialZoom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pick Location on Map'),
        backgroundColor: AppColors.white,
        actions: [
          if (_picked != null)
            IconButton(icon: const Icon(Icons.center_focus_strong), onPressed: _goToPicked, tooltip: 'Center on pin'),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: initialCenter,
              initialZoom: initialZoom,
              onTap: _onTapMap,
              onPositionChanged: (pos, _) {
                _currentZoom = pos.zoom;
              },
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.wherelog',
                maxZoom: 19,
              ),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_pin, size: 48, color: Colors.red),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
                ],
              ),
            ],
          ),
          // Zoom buttons + current location
          Positioned(
            right: 12,
            top: 12,
            child: Column(
              children: [
                FloatingActionButton.small(heroTag: 'zoom_in', onPressed: _zoomIn, child: const Icon(Icons.add)),
                const SizedBox(height: 8),
                FloatingActionButton.small(heroTag: 'zoom_out', onPressed: _zoomOut, child: const Icon(Icons.remove)),
                const SizedBox(height: 16),
                FloatingActionButton(
                  heroTag: 'my_location',
                  onPressed: _isGettingLocation ? null : _goToCurrentLocation,
                  backgroundColor: AppColors.buttonBg,
                  foregroundColor: Colors.white,
                  tooltip: 'Go to my current location',
                  child: _isGettingLocation
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.my_location),
                ),
              ],
            ),
          ),
          // Center crosshair when no pin
          if (_picked == null)
            const Center(
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, size: 48, color: Colors.redAccent),
                    SizedBox(height: 4),
                    Text('Tap to drop pin or use GPS', style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: Colors.white70)),
                  ],
                ),
              ),
            ),
          // Bottom card
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_picked != null)
                      Text(
                        '${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      )
                    else
                      const Text('Tap map to drop a pin', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (_isGeocoding)
                      const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Getting address...')])
                    else if (_address.isNotEmpty)
                      Text(_address, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: _picked == null
                                ? null
                                : () => Navigator.pop(context, {
                                      'lat': _picked!.latitude.toString(),
                                      'lng': _picked!.longitude.toString(),
                                      'address': _address,
                                    }),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.buttonBg, foregroundColor: AppColors.white),
                            child: const Text('Use This Location'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
