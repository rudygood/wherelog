import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class MapUtils {
  /// Opens native maps with directions to EXACT lat/lng - no name search.
  /// This fixes "Stoney Creek primitive campsite" finding other "Stoney Creek Campground" locations.
  ///
  /// The label is only used as a pin title, never as a search query.
  static Future<void> openDirections({
    required double lat,
    required double lng,
    String? label,
  }) async {
    // Clean label - default to WhereLog POI if empty
    final String rawLabel = (label != null && label.trim().isNotEmpty)
        ? label.trim()
        : 'WhereLog POI';

    // Title that will show in Maps: "WhereLog: My Garage"
    final String displayTitle = rawLabel.startsWith('WhereLog:')
        ? rawLabel
        : 'WhereLog: $rawLabel';

    // For geo URI, we need to keep parentheses but encode the label inside
    // Use Uri.encodeComponent but keep it readable - geo handler wants raw label in parens
    // IMPORTANT: Don't double-encode. The geo URI format is: geo:lat,lng?q=lat,lng(label)
    // The label in parens is display only, the lat,lng before it forces exact location
    final String geoLabel = displayTitle
        .replaceAll('(', '')
        .replaceAll(')', '') // prevent breaking parens
        .replaceAll(',', ' '); // commas inside label can break parsing

    // 1. Android - geo: with exact coords + label as display title (NOT search)
    // Format: geo:lat,lng?q=lat,lng(label) -> The q=lat,lng forces pin at coords, (label) is title
    // This does NOT search by name - it drops pin at exact coords
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($geoLabel)');
    try {
      if (await canLaunchUrl(geoUri)) {
        final launched = await launchUrl(geoUri);
        if (launched) return;
      }
    } catch (_) {}

    // 2. iOS Apple Maps - use daddr with coords only, no q search
    // If we include q=label, Apple Maps will search for that label and may find wrong place
    if (Platform.isIOS) {
      // Use daddr with coords only - forces exact pin
      final appleUri = Uri.parse('maps://?daddr=$lat,$lng&dirflg=d');
      try {
        if (await canLaunchUrl(appleUri)) {
          final launched = await launchUrl(appleUri);
          if (launched) return;
        }
      } catch (_) {}

      // Fallback Apple https with ll (lat/lng) - also forces exact location
      final appleHttps = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&ll=$lat,$lng&dirflg=d');
      try {
        if (await canLaunchUrl(appleHttps)) {
          final launched = await launchUrl(appleHttps, mode: LaunchMode.externalApplication);
          if (launched) return;
        }
      } catch (_) {}
    }

    // 3. Universal Google Maps - destination=lat,lng ONLY, no query param
    // Adding &query=Title@lat,lng or &query=Title causes Google to SEARCH for Title
    // and it will find similarly named campgrounds 75 miles away
    // Just using destination=lat,lng forces exact coords
    final googleUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving');
    try {
      if (await canLaunchUrl(googleUri)) {
        final launched = await launchUrl(googleUri, mode: LaunchMode.externalApplication);
        if (launched) return;
      }
    } catch (_) {}

    // 4. Last resort - geo with 0,0?q=lat,lng(label) - still coords only
    final geoFallback = Uri.parse('geo:0,0?q=$lat,$lng($geoLabel)');
    try {
      await launchUrl(geoFallback, mode: LaunchMode.externalApplication);
    } catch (_) {
      // Final fallback - Google search but with coords in query, not name
      // Use lat,lng as query to force pin at coords
      final googleWeb = Uri.parse('https://www.google.com/maps/search/?api=1&query=$lat,$lng');
      await launchUrl(googleWeb, mode: LaunchMode.externalApplication);
    }
  }

  static bool hasCoordinates(dynamic lat, dynamic lng) {
    double? latD;
    double? lngD;
    if (lat is num) {
      latD = lat.toDouble();
    } else {
      latD = double.tryParse(lat?.toString() ?? '');
    }
    if (lng is num) {
      lngD = lng.toDouble();
    } else {
      lngD = double.tryParse(lng?.toString() ?? '');
    }
    if (latD == null || lngD == null) return false;
    if (latD == 0 && lngD == 0) return false;
    // Basic range check
    if (latD < -90 || latD > 90) return false;
    if (lngD < -180 || lngD > 180) return false;
    return true;
  }
}
