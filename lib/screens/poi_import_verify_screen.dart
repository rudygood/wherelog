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
/// of a WhereLog map, with the place's name, address and import
/// source, so its position can be checked — and moved, by tapping
/// the map — before anything is saved. Looking alone changes
/// nothing.
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

  /// How far the pin now sits from where the import put it.
  String get _movedText {
    final m = Geolocator.distanceBetween(_importedPoint.latitude,
        _importedPoint.longitude, _point.latitude, _point.longitude);
    final dist = m < 1000
        ? '${m.toStringAsFixed(0)} m'
        : '${(m / 1000).toStringAsFixed(2)} km';
    return 'Moved $dist from the imported position';
  }

  void _resetToImported() {
    setState(() => _point = _importedPoint);
    _mapController.move(_importedPoint, _currentZoom);
  }

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
      appBar: AppHeader(
        screenName: 'Check Imported Place',
        actions: [
          IconButton(
            icon: const Icon(Icons.center_focus_strong,
                color: AppColors.textPrimary),
            onPressed: _goToPoint,
            tooltip: 'Center on pin',
          ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // The import notice, moved here from the add
                // screen: this is the moment of the check.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.warningBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AppColors.warningText),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Coordinates from other apps aren\'t always exact. Please check that the pin sits where it should on the map — and move it if it needs adjusting.',
                          style: TextStyle(
                              fontSize: 12, color: AppColors.warningText),
                        ),
                      ),
                    ],
                  ),
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
                const SizedBox(height: 2),
                Text('Source: ${d.source}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 4),
                Text(
                  '${_point.latitude.toStringAsFixed(6)}, ${_point.longitude.toStringAsFixed(6)}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                ),
                if (_moved)
                  Row(
                    children: [
                      Expanded(
                        child: Text(_movedText,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ),
                      TextButton(
                        onPressed: _resetToImported,
                        style: TextButton.styleFrom(
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(0, 0),
                            tapTargetSize:
                                MaterialTapTargetSize.shrinkWrap),
                        child: const Text('Reset to imported point',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ],
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
                    child: Column(
                      children: [
                        FloatingActionButton.small(
                            heroTag: 'zoom_in',
                            onPressed: _zoomIn,
                            child: const Icon(Icons.add)),
                        const SizedBox(height: 8),
                        FloatingActionButton.small(
                            heroTag: 'zoom_out',
                            onPressed: _zoomOut,
                            child: const Icon(Icons.remove)),
                        const SizedBox(height: 16),
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
                        const SizedBox(height: 8),
                        MapStyleToggle(
                          satellite: _satellite,
                          onToggle: () =>
                              setState(() => _satellite = !_satellite),
                        ),
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
