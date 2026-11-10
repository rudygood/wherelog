import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/map_view.dart';
import '../utils/poi_import_utils.dart';

/// The verification gate every staged POI import passes through
/// before the add screen: the imported point shown in the middle
/// of a WhereLog map, with the place's name, address and coords,
/// so its position can be checked — and moved, by tapping
/// the map — before anything is saved. Looking alone changes
/// nothing. (The import source is no longer displayed here —
/// cosmetics round, item 16 — but it is still recorded.)
///
/// Confirming returns the (possibly adjusted) [PoiImportData];
/// if the pin was moved, the source gains an " (adjusted)"
/// suffix and otherwise keeps the import's original source.
/// Backing out returns null and the import stays queued.
class PoiImportVerifyScreen extends StatefulWidget {
  final PoiImportData data;

  const PoiImportVerifyScreen({super.key, required this.data});

  @override
  State<PoiImportVerifyScreen> createState() =>
      _PoiImportVerifyScreenState();
}

class _PoiImportVerifyScreenState extends State<PoiImportVerifyScreen> {
  final MapController _mapController = MapController();

  late LatLng _point;
  late LatLng _importedPoint;
  bool _satellite = false;
  bool _isGettingLocation = false;
  double _currentZoom = 16.0;

  bool get _moved => _point != _importedPoint;

  @override
  void initState() {
    super.initState();
    _importedPoint = LatLng(widget.data.lat, widget.data.lng);
    _point = _importedPoint;
  }

  void _onTapMap(TapPosition _, LatLng p) {
    setState(() => _point = p);
  }

  void _zoomIn() {
    _currentZoom = (_currentZoom + 1).clamp(2.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _zoomOut() {
    _currentZoom = (_currentZoom - 1).clamp(2.0, 19.0);
    _mapController.move(_mapController.camera.center, _currentZoom);
  }

  void _goToPoint() {
    _mapController.move(_point, _currentZoom);
  }

  Future<void> _goToCurrentLocation() async {
    setState(() => _isGettingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Location permission denied')));
        }
        return;
      }
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      final ll = LatLng(pos.latitude, pos.longitude);
      setState(() => _point = ll);
      _mapController.move(ll, 17.0);
      _currentZoom = 17.0;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not get location: $e')));
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  void _confirm() {
    final d = widget.data;
    final source = _moved && !d.source.endsWith(' (adjusted)')
        ? '${d.source} (adjusted)'
        : d.source;
    Navigator.pop(
      context,
      PoiImportData(
        name: d.name,
        lat: _point.latitude,
        lng: _point.longitude,
        address: d.address,
        source: source,
        nameIsPlaceholder: d.nameIsPlaceholder,
        coordsAreViewport: d.coordsAreViewport,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: const AppHeader(screenName: 'Verify Pin'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // One plain line (cosmetics round, item 15; wording
                // settled in evaluation fix E6 — the line teaches the
                // action instead of naming the task, Rudy's ruling:
                // his first wording presumed the user already knew
                // what verifying entailed and how a pin moves here).
                const Text(
                  'If the pin isn\'t on the right spot, zoom in and tap the right spot to move it.',
                  style: TextStyle(
                      fontSize: 13, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                Text(d.name,
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.bold)),
                if (d.address.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(d.address,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.textSecondary)),
                ],
                const SizedBox(height: 4),
                Text(
                  '${_point.latitude.toStringAsFixed(6)}, ${_point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
              ],
            ),
          ),
          Expanded(
            child: MapFrame(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _importedPoint,
                      initialZoom: 16.0,
                      onTap: _onTapMap,
                      onPositionChanged: (pos, _) {
                        _currentZoom = pos.zoom;
                      },
                    ),
                    children: [
                      ...mapTileLayers(satellite: _satellite),
                      MarkerLayer(
                        markers: [
                          // Once the pin moves, a quiet grey pin
                          // stays behind at the imported position,
                          // so where it arrived remains visible
                          // alongside where it now sits.
                          if (_moved)
                            Marker(
                              point: _importedPoint,
                              width: 40,
                              height: 40,
                              child: Icon(Icons.location_pin,
                                  size: 38,
                                  color: AppColors.textSecondary
                                      .withOpacity(0.65)),
                            ),
                          Marker(
                            point: _point,
                            width: 50,
                            height: 50,
                            child: const Icon(Icons.location_pin,
                                size: 48, color: AppColors.alert),
                          ),
                        ],
                      ),
                      RichAttributionWidget(
                        attributions: mapAttributions(satellite: _satellite),
                      ),
                    ],
                  ),
                  Positioned(
                    right: 12,
                    top: 12,
                    // Five in a horizontal strip at the top: zoom +,
                    // zoom -, GPS, satellite/street, and center-on-pin
                    // (moved here from the header) — one shallow row
                    // instead of a column down the side (cosmetics
                    // round, items 12, 17 and 18).
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FloatingActionButton.small(
                            heroTag: 'zoom_in',
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add)),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                            heroTag: 'zoom_out',
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove)),
                        const SizedBox(width: 12),
                        FloatingActionButton(
                          heroTag: 'my_location',
                          onPressed:
                              _isGettingLocation ? null : _goToCurrentLocation,
                          backgroundColor: AppColors.buttonBg,
                          foregroundColor: AppColors.white,
                          tooltip: 'Go to my current location',
                          child: _isGettingLocation
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.white))
                              : const Icon(Icons.my_location),
                        ),
                        const SizedBox(width: 8),
                        MapStyleToggle(
                          satellite: _satellite,
                          onToggle: () =>
                              setState(() => _satellite = !_satellite),
                        ),
                        const SizedBox(width: 8),
                        FloatingActionButton.small(
                            heroTag: 'center_on_pin',
                            onPressed: _goToPoint,
                            tooltip: 'Center on pin',
                            child: const Icon(Icons.center_focus_strong)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
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
                    onPressed: _confirm,
                    style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.buttonBg,
                        foregroundColor: AppColors.white),
                    child: const Text('Use This Location'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
