import 'package:url_launcher/url_launcher.dart';
import 'dart:io' show Platform;

class MapUtils {
  /// Opens native maps with directions to lat/lng WITH TITLE
  /// Android: geo: intent shows chooser (Google Maps, Waze, etc.) with label as title
  /// iOS: Apple Maps with q= label, Google Maps web fallback with WhereLog: title
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
    
    final String encodedLabel = Uri.encodeComponent(displayTitle);
    final String encodedQueryTitle = Uri.encodeComponent(displayTitle);
    
    // Android - geo: with label in parentheses shows as title on pin
    // Format: geo:lat,lng?q=lat,lng(label) -> label shows as title
    final geoUri = Uri.parse('geo:$lat,$lng?q=$lat,$lng($encodedLabel)');
    if (await canLaunchUrl(geoUri)) {
      await launchUrl(geoUri);
      return;
    }

    // iOS Apple Maps - daddr + q shows title
    if (Platform.isIOS) {
      final appleUri = Uri.parse('maps://?daddr=$lat,$lng&q=$encodedLabel&dirflg=d');
      if (await canLaunchUrl(appleUri)) {
        await launchUrl(appleUri);
        return;
      }
      final appleHttps = Uri.parse('https://maps.apple.com/?daddr=$lat,$lng&q=$encodedLabel&dirflg=d');
      if (await canLaunchUrl(appleHttps)) {
        await launchUrl(appleHttps, mode: LaunchMode.externalApplication);
        return;
      }
    }

    // Universal fallback - Google Maps dir with title via query param
    // This format: destination=lat,lng & query=Title@lat,lng shows Title as header
    final googleUri = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&query=$encodedQueryTitle@${lat},${lng}&travelmode=driving');
    if (await canLaunchUrl(googleUri)) {
      await launchUrl(googleUri, mode: LaunchMode.externalApplication);
      return;
    }

    // Last resort web search with title
    final googleWeb = Uri.parse('https://www.google.com/maps/search/?api=1&query=$encodedQueryTitle@${lat},${lng}');
    await launchUrl(googleWeb, mode: LaunchMode.externalApplication);
  }

  static bool hasCoordinates(dynamic lat, dynamic lng) {
    double? latD;
    double? lngD;
    if (lat is num) latD = lat.toDouble();
    else latD = double.tryParse(lat?.toString() ?? '');
    if (lng is num) lngD = lng.toDouble();
    else lngD = double.tryParse(lng?.toString() ?? '');
    if (latD == null || lngD == null) return false;
    if (latD == 0 && lngD == 0) return false;
    // Basic range check
    if (latD < -90 || latD > 90) return false;
    if (lngD < -180 || lngD > 180) return false;
    return true;
  }
}
