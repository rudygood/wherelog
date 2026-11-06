import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme/app_theme.dart';
import '../widgets/app_header.dart';
import '../widgets/map_view.dart';

class MapPickerScreen extends StatefulWidget {
  final double? initialLat;
  final double? initialLng;
  final String? initialAddress;

  const MapPickerScreen({super.key, this.initialLat, this.initialLng, this.initialAddress});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _SearchResult {
  final String displayName;
  final double lat;
  final double lng;
  final String type;
  _SearchResult({required this.displayName, required this.lat, required this.lng, required this.type});
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  LatLng? _picked;
  String _address = '';
  bool _isGeocoding = false;
  bool _isGettingLocation = false;
  bool _isSearching = false;
  bool _satellite = false;
  double _currentZoom = 16.0;
  List<_SearchResult> _searchResults = [];
  String _searchError = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialLat != null && widget.initialLng != null) {
      _picked = LatLng(widget.initialLat!, widget.initialLng!);
      _address = widget.initialAddress ?? '';
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  // ---- Reverse geocode (existing) ----
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

  // ---- Forward search (NEW) ----
  Future<void> _performSearch() async {
    final query = _searchController.text.trim();
    if (query.length < 2) {
      setState(() {
        _searchError = 'Enter at least 2 characters';
        _searchResults = [];
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = '';
      _searchResults = [];
    });

    try {
      // Bias search near current map center if we have one
      final center = _mapController.camera.center;
      // 1 degree ~ 111km, use ~ 100km viewbox for biasing (not strict)
      const delta = 1.0;
      final viewbox = '${center.longitude - delta},${center.latitude + delta},${center.longitude + delta},${center.latitude - delta}';

      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/search'
        '?q=${Uri.encodeComponent(query)}'
        '&format=json&limit=8&addressdetails=1'
        '&viewbox=$viewbox&bounded=0',
      );

      final response = await http.get(
        uri,
        headers: {
          // Nominatim requires a User-Agent identifying the app
          'User-Agent': 'WhereLog/1.0 (wherelog app; contact: wherelog.app)',
        },
      ).timeout(const Duration(seconds: 12));

      if (response.statusCode != 200) {
        throw Exception('Search failed: ${response.statusCode}');
      }

      final List data = jsonDecode(response.body) as List;
      if (data.isEmpty) {
        setState(() {
          _searchError = 'No results for "$query". Try a nearby town, park, or landmark.';
        });
      } else {
        final results = data.map((e) {
          return _SearchResult(
            displayName: e['display_name'] as String? ?? query,
            lat: double.tryParse(e['lat'].toString()) ?? 0,
            lng: double.tryParse(e['lon'].toString()) ?? 0,
            type: e['type'] as String? ?? e['class'] as String? ?? '',
          );
        }).where((r) => r.lat != 0 && r.lng != 0).toList();

        setState(() => _searchResults = results);
      }
    } catch (e) {
      setState(() => _searchError = 'Search error: $e');
    } finally {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  void _selectSearchResult(_SearchResult r) {
    final ll = LatLng(r.lat, r.lng);
    setState(() {
      _picked = ll;
      _address = r.displayName;
      _searchResults = [];
      _searchError = '';
      _searchController.text = r.displayName.split(',').first; // keep short in box
    });
    // Move map to result, zoom in
    _mapController.move(ll, 16.0);
    _currentZoom = 16.0;
    _searchFocus.unfocus();
    // Also reverse geocode for clean address (optional, but keep our picked)
    // _reverseGeocode(ll);
  }

  void _clearSearch() {
    setState(() {
      _searchController.clear();
      _searchResults = [];
      _searchError = '';
    });
    _searchFocus.unfocus();
  }

  void _onTapMap(TapPosition _, LatLng p) {
    setState(() {
      _picked = p;
      // clear search results when user manually picks
      _searchResults = [];
    });
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
    // Only set on first build, don't override during interaction
    if (_currentZoom == 16.0 && _picked == null) {
      _currentZoom = initialZoom;
    }

    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppHeader(
        screenName: 'Pick Location on Map',
        actions: [
          if (_picked != null)
            IconButton(icon: const Icon(Icons.center_focus_strong, color: AppColors.textPrimary), onPressed: _goToPicked, tooltip: 'Center on pin'),
        ],
      ),
      body: MapFrame(
        child: Stack(
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
              ...mapTileLayers(satellite: _satellite),
              if (_picked != null)
                MarkerLayer(
                  markers: [
                    Marker(
                      point: _picked!,
                      width: 50,
                      height: 50,
                      child: const Icon(Icons.location_pin, size: 48, color: AppColors.alert),
                    ),
                  ],
                ),
              RichAttributionWidget(
                attributions: mapAttributions(satellite: _satellite),
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
                  foregroundColor: AppColors.white,
                  tooltip: 'Go to my current location',
                  child: _isGettingLocation
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                      : const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                MapStyleToggle(
                  satellite: _satellite,
                  onToggle: () => setState(() => _satellite = !_satellite),
                ),
              ],
            ),
          ),
          // Center crosshair when no pin
          if (_picked == null && _searchResults.isEmpty)
            const Center(
              child: IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.location_pin, size: 48, color: AppColors.alert),
                    SizedBox(height: 4),
                    Text('Tap to drop pin or search below', style: TextStyle(fontWeight: FontWeight.bold, backgroundColor: AppColors.whiteDim)),
                  ],
                ),
              ),
            ),
          // Bottom card with SEARCH + results + coords + buttons
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // === NEW SEARCH BAR ===
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            focusNode: _searchFocus,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _performSearch(),
                            decoration: InputDecoration(
                              hintText: 'Search nearby landmark, park, campground...',
                              isDense: true,
                              prefixIcon: const Icon(Icons.search, size: 20),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(icon: const Icon(Icons.clear, size: 20), onPressed: _clearSearch)
                                  : null,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                              contentPadding: AppSize.fieldPadding,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        SizedBox(
                          height: 42,
                          child: ElevatedButton(
                            onPressed: _isSearching ? null : _performSearch,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.buttonBg,
                              foregroundColor: AppColors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppBorder.radius)),
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                            ),
                            child: _isSearching
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.white))
                                : const Text('Find'),
                          ),
                        ),
                      ],
                    ),

                    // Search status
                    if (_searchError.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(_searchError, style: AppText.dialogAlert),
                    ],

                    // Search results list
                    if (_searchResults.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(maxHeight: 180),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.border, width: AppBorder.width),
                          borderRadius: BorderRadius.circular(AppBorder.radius),
                        ),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => Divider(height: 1, color: AppColors.disabledSurface),
                          itemBuilder: (context, idx) {
                            final r = _searchResults[idx];
                            return ListTile(
                              dense: true,
                              leading: Icon(
                                r.type.contains('forest') || r.type.contains('park') || r.type.contains('camp')
                                    ? Icons.park
                                    : Icons.place,
                                size: 20,
                                color: AppColors.buttonBg,
                              ),
                              title: Text(r.displayName, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.cardTitle),
                              subtitle: Text('${r.type} • ${r.lat.toStringAsFixed(5)}, ${r.lng.toStringAsFixed(5)}', style: AppText.dialog),
                              onTap: () => _selectSearchResult(r),
                            );
                          },
                        ),
                      ),
                    ],

                    const SizedBox(height: 10),
                    const Divider(height: 1),
                    const SizedBox(height: 10),

                    // Existing coords / address display
                    if (_picked != null)
                      Text(
                        '${_picked!.latitude.toStringAsFixed(6)}, ${_picked!.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'monospace'),
                      )
                    else
                      const Text('Tap map or search to drop a pin', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (_isGeocoding)
                      const Row(children: [
                        SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 8),
                        Text('Getting address...')
                      ])
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
      ),
    );
  }
}
