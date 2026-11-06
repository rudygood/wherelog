import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import '../theme/app_theme.dart';

/// Shared pieces for every WhereLog map (the location picker,
/// the POI map, and the import verification screen), so all maps
/// carry the same WhereLog page identity: the tile layers
/// (street or satellite), the street/satellite toggle button,
/// and the narrow framed border the map sits inside.

/// The base tile layers for the current map style. Street is
/// OpenStreetMap; satellite is Esri World Imagery with the Esri
/// reference overlay on top, so place names and roads stay
/// readable over the photography. Both are free and keyless.
/// Spread the result into a FlutterMap's children in place of a
/// single TileLayer.
List<Widget> mapTileLayers({required bool satellite}) {
  if (satellite) {
    return [
      TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.wherelog.app',
        maxZoom: 19,
        // Esri's photography ends at zoom 18; upscale past it
        // rather than request tiles that do not exist.
        maxNativeZoom: 18,
      ),
      TileLayer(
        urlTemplate:
            'https://server.arcgisonline.com/ArcGIS/rest/services/Reference/World_Boundaries_and_Places/MapServer/tile/{z}/{y}/{x}',
        userAgentPackageName: 'com.wherelog.app',
        maxZoom: 19,
        maxNativeZoom: 18,
      ),
    ];
  }
  return [
    TileLayer(
      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
      userAgentPackageName: 'com.wherelog.app',
      maxZoom: 19,
    ),
  ];
}

/// Attribution line matching the current tile style, for a
/// FlutterMap's RichAttributionWidget.
List<SourceAttribution> mapAttributions({required bool satellite}) {
  if (satellite) {
    return [
      TextSourceAttribution(
        'Esri, Maxar, Earthstar Geographics',
        onTap: () {},
      ),
    ];
  }
  return [
    TextSourceAttribution('© OpenStreetMap contributors', onTap: () {}),
  ];
}

/// The street/satellite toggle button, styled like the other
/// floating controls on the map screens.
class MapStyleToggle extends StatelessWidget {
  final bool satellite;
  final VoidCallback onToggle;

  const MapStyleToggle({
    super.key,
    required this.satellite,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: 'map_style_toggle',
      onPressed: onToggle,
      tooltip: satellite ? 'Show street map' : 'Show satellite view',
      child: Icon(satellite ? Icons.map : Icons.satellite_alt),
    );
  }
}

/// The framed border every WhereLog map sits inside: page
/// padding around a 1px theme border at the app corner radius,
/// with the tiles clipped to the frame.
class MapFrame extends StatelessWidget {
  final Widget child;

  const MapFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border, width: AppBorder.width),
          borderRadius: BorderRadius.circular(AppBorder.radius),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppBorder.radius),
          child: child,
        ),
      ),
    );
  }
}
