import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:geolocator/geolocator.dart';
import '../data/sqlite_poi_repository.dart';
import 'poi_edit_screen.dart';
import '../utils/map_utils.dart';

class PoiMapScreen extends StatefulWidget {
  const PoiMapScreen({super.key});

  @override
  State<PoiMapScreen> createState() => _PoiMapScreenState();
}

class _PoiMapScreenState extends State<PoiMapScreen> {
  final _poiRepo = SqlitePoiRepository.instance;
  final _mapController = MapController();

  // Default 25 miles per Rudy's request
  static const double _defaultRadiusMiles = 25;
  double _radiusMiles = _defaultRadiusMiles;
  final List<double> _radiusOptions = [0, 1, 5, 10, 25, 50, 100]; // 0 = All

  Position? _currentPos;
  bool _locLoading = true;
  String? _locError;

  List<Map<String, dynamic>> _allPois = [];
  List<Map<String, dynamic>> _filteredPois = [];

  @override
  void initState() {
    super.initState();
    _loadPois();
    _loadLocation();
  }

  Future<void> _loadPois() async {
    // Places come from the SQLite poi_items table; the screen keeps
    // working with map-shaped rows built from the records.
    final records = await _poiRepo.getAll();
    _allPois = records
        .where((r) => r.latitude != 0 && r.longitude != 0)
        .map((r) => <String, dynamic>{
              'id': r.id?.toString(),
              'name': r.name,
              'lat': r.latitude,
              'lng': r.longitude,
              'address': r.address,
              'notes': r.notes,
            })
        .toList();
    _applyFilter();
  }

  Future<void> _loadLocation() async {
    setState(() { _locLoading = true; _locError = null; });
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() { _locError = 'Location services disabled'; _locLoading = false; });
        _applyFilter();
        return;
      }
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        setState(() { _locError = 'Location permission denied'; _locLoading = false; });
        _applyFilter();
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high).timeout(const Duration(seconds: 10));
      const double kThresh = 402.0; // 0.25 mi
      if (_currentPos != null) { final mv = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, pos.latitude, pos.longitude); if (mv < kThresh) { setState(() { _locLoading = false; }); return; } }
      setState(() { _currentPos = pos; _locLoading = false; });
      _applyFilter();
      // Center map on current location
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        _mapController.move(ll.LatLng(pos.latitude, pos.longitude), 11);
      });
    } catch (e) {
      setState(() { _locError = e.toString(); _locLoading = false; });
      _applyFilter();
    }
  }

  void _applyFilter() {
    if (_radiusMiles == 0 || _currentPos == null) {
      // 0 = All, or no location = show all
      _filteredPois = List.from(_allPois);
    } else {
      final maxMeters = _radiusMiles * 1609.34;
      _filteredPois = _allPois.where((poi) {
        final lat = (poi['lat'] as num).toDouble();
        final lng = (poi['lng'] as num).toDouble();
        final dist = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, lat, lng);
        return dist <= maxMeters;
      }).toList();
      // Sort nearest first
      _filteredPois.sort((a, b) {
        final da = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, (a['lat'] as num).toDouble(), (a['lng'] as num).toDouble());
        final db = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, (b['lat'] as num).toDouble(), (b['lng'] as num).toDouble());
        return da.compareTo(db);
      });
    }
    if (mounted) setState(() {});
  }

  ll.LatLng _initialCenter() {
    if (_currentPos != null) return ll.LatLng(_currentPos!.latitude, _currentPos!.longitude);
    if (_filteredPois.isNotEmpty) {
      final first = _filteredPois.first;
      return ll.LatLng((first['lat'] as num).toDouble(), (first['lng'] as num).toDouble());
    }
    if (_allPois.isNotEmpty) {
      final first = _allPois.first;
      return ll.LatLng((first['lat'] as num).toDouble(), (first['lng'] as num).toDouble());
    }
    // Stanley, VA fallback
    return ll.LatLng(38.573, -78.512);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('POI Map (${_filteredPois.length}/${_allPois.length})'),
        actions: [
          IconButton(icon: const Icon(Icons.my_location), onPressed: _loadLocation, tooltip: 'Recenter'),
        ],
      ),
      body: Column(
        children: [
          // Radius selector
          Container(
            color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.5),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
              children: [
                const Icon(Icons.radar, size: 18),
                const SizedBox(width: 6),
                Text(_currentPos == null ? 'Radius: All (no location)' : 'Radius:', style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: _radiusOptions.map((r) {
                        final label = r == 0 ? 'All' : '${r.toInt()} mi';
                        final selected = r == _radiusMiles;
                        return Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(label),
                            selected: selected,
                            onSelected: (v) {
                              if (!v) return;
                              setState(() { _radiusMiles = r; });
                              _applyFilter();
                            },
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                if (_locLoading) const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
          ),
          if (_locError != null)
            Container(
              width: double.infinity,
              color: AppColors.warningBackground,
              padding: const EdgeInsets.all(6),
              child: Text(_locError!, style: TextStyle(color: AppColors.warningText, fontSize: 12), textAlign: TextAlign.center),
            ),
          Expanded(
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(),
                initialZoom: _currentPos != null ? 11 : 10,
                maxZoom: 18,
                minZoom: 3,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.wherelog.app',
                ),
                // Radius circle
                if (_currentPos != null && _radiusMiles > 0)
                  CircleLayer(
                    circles: [
                      CircleMarker(
                        point: ll.LatLng(_currentPos!.latitude, _currentPos!.longitude),
                        radius: _radiusMiles * 1609.34,
                        useRadiusInMeter: true,
                        color: AppColors.mapAccent.withOpacity(0.1),
                        borderColor: AppColors.mapAccent.withOpacity(0.4),
                        borderStrokeWidth: 2,
                      ),
                    ],
                  ),
                MarkerLayer(
                  markers: [
                    // Current location
                    if (_currentPos != null)
                      Marker(
                        width: 30,
                        height: 30,
                        point: ll.LatLng(_currentPos!.latitude, _currentPos!.longitude),
                        child: const Icon(Icons.my_location, color: AppColors.mapAccent, size: 28),
                      ),
                    // POI pins
                    for (final poi in _filteredPois)
                      Marker(
                        width: 148,
                        height: 58,
                        point: ll.LatLng((poi['lat'] as num).toDouble(), (poi['lng'] as num).toDouble()),
                        child: GestureDetector(
                          onTap: () => _showPoiSheet(poi),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.white,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: AppColors.border, width: AppBorder.width),
                                  boxShadow: [BoxShadow(color: AppColors.shadow, blurRadius: 2)],
                                ),
                                child: Text(
                                  (poi['name']?.toString() ?? 'POI').length > 22
                                      ? '${poi['name'].toString().substring(0, 20)}..'
                                      : poi['name']?.toString() ?? 'POI',
                                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const Icon(Icons.location_on, color: AppColors.alert, size: 28),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Bottom list of filtered POIs sorted nearest
          if (_filteredPois.isNotEmpty)
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(top: BorderSide(color: AppColors.disabledSurface)),
              ),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.all(8),
                itemCount: _filteredPois.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (ctx, i) {
                  final poi = _filteredPois[i];
                  final lat = (poi['lat'] as num).toDouble();
                  final lng = (poi['lng'] as num).toDouble();
                  String distStr = '';
                  if (_currentPos != null) {
                    final m = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, lat, lng);
                    final mi = m / 1609.34;
                    distStr = '${mi.toStringAsFixed(1)} mi';
                  }
                  return GestureDetector(
                    onTap: () {
                      _mapController.move(ll.LatLng(lat, lng), 14);
                      _showPoiSheet(poi);
                    },
                    child: Container(
                      width: 180,
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.white,
                        borderRadius: BorderRadius.circular(AppRadius.button),
                        border: Border.all(color: AppColors.border, width: AppBorder.width),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(poi['name']?.toString() ?? 'POI', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                          if (poi['address'] != null && poi['address'].toString().isNotEmpty)
                            Text(poi['address'].toString(), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10, color: AppColors.textDisabled)),
                          const Spacer(),
                          Row(
                            children: [
                              if (distStr.isNotEmpty) Text(distStr, style: const TextStyle(fontSize: 10, color: AppColors.mapAccent, fontWeight: FontWeight.w600)),
                              const Spacer(),
                              const Icon(Icons.map, size: 14, color: AppColors.textDisabled),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  void _showPoiSheet(Map<String, dynamic> poi) {
    final lat = (poi['lat'] as num).toDouble();
    final lng = (poi['lng'] as num).toDouble();
    String distStr = '';
    if (_currentPos != null) {
      final m = Geolocator.distanceBetween(_currentPos!.latitude, _currentPos!.longitude, lat, lng);
      distStr = '${(m / 1609.34).toStringAsFixed(1)} mi / ${(m / 1000).toStringAsFixed(1)} km away';
    }
    showModalBottomSheet(
      context: context,
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(poi['name']?.toString() ?? 'POI', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (poi['address'] != null && poi['address'].toString().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(poi['address'].toString(), style: const TextStyle(color: AppColors.textDisabled)),
            ],
            if (distStr.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(distStr, style: const TextStyle(color: AppColors.mapAccent, fontWeight: FontWeight.w600)),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.navigation), label: const Text('Navigate'), onPressed: () { MapUtils.openDirections(lat: lat, lng: lng, label: poi['name']?.toString()); })),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.edit), label: const Text('POI Edit'), onPressed: () { Navigator.pop(ctx); final pid = int.tryParse(poi['id']?.toString() ?? ''); if (pid != null) { Navigator.of(context).push(MaterialPageRoute(builder: (_) => PoiEditScreen(poiId: pid))).then((_) { _loadPois(); }); } })),
              ],
            ),
            const SizedBox(height: 8),
            Text('${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}', style: const TextStyle(fontSize: 11, color: AppColors.textDisabled)),
          ],
        ),
      ),
    );
  }
}
