import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:xml/xml.dart' as xml;
import 'package:http/http.dart' as http;

/// Result from parsing any shared import
class PoiImportData {
  final String name;
  final double lat;
  final double lng;
  final String address;
  final String source; // clipboard, gpx, wherelog link

  PoiImportData({
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.source = '',
  });
}

class PoiImportUtils {
  // ---- Regex for lat,lng anywhere in text ----
  static final RegExp _latLngRegex = RegExp(
    r'(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)',
  );

  static Future<String> tryExpandShortLink(String text) async {
    try {
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
      if (urlMatch == null) return text;
      final url = urlMatch.group(0)!;
      if (!url.contains('goo.gl')) return text;
      final client = http.Client();
      try {
        final request = http.Request('GET', Uri.parse(url));
        request.followRedirects = false;
        final streamed = await client.send(request).timeout(Duration(seconds: 8));
        String? nextUrl = streamed.headers['location'];
        if (nextUrl != null && nextUrl.isNotEmpty) {
          if (nextUrl.contains('goo.gl')) {
            final r2 = await client.get(Uri.parse(nextUrl)).timeout(Duration(seconds: 8));
            final body = r2.body;
            return body.substring(0, body.length > 8000 ? 8000 : body.length) + ' ' + nextUrl;
          }
          return nextUrl + ' ' + text;
        }
        final response = await http.get(Uri.parse(url)).timeout(Duration(seconds: 8));
        return response.body.substring(0, response.body.length > 8000 ? 8000 : response.body.length) + ' ' + text;
      } finally {
        client.close();
      }
    } catch (_) {
      return text;
    }
  }

  // ---- Parse clipboard / shared text ----
  // Handles:
  // - "38.9123, -78.3456"
  // - https://www.google.com/maps/search/?api=1&query=38.9123,-78.3456
  // - https://www.google.com/maps/dir/?api=1&destination=38.9123,-78.3456
  // - https://maps.apple.com/?daddr=38.9123,-78.3456
  // - https://maps.apple.com/?q=38.9123,-78.3456
  // - geo:38.9123,-78.3456?q=...
  // - wherelog://poi?lat=...&lng=...&name=...
  static List<PoiImportData> parseSharedText(String text) {
    final List<PoiImportData> results = [];
    if (text.trim().isEmpty) return results;

    final String lower = text.toLowerCase();

    // 1. Try wherelog:// scheme first - most specific
    try {
      if (lower.contains('wherelog://')) {
        final uri = Uri.parse(text.trim().split(RegExp(r'\s')).firstWhere((s) => s.contains('wherelog://'), orElse: () => ''));
        if (uri.scheme == 'wherelog') {
          final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
          final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
          if (lat != null && lng != null) {
            results.add(PoiImportData(
              name: uri.queryParameters['name'] ?? 'Imported POI',
              lat: lat,
              lng: lng,
              address: uri.queryParameters['address'] ?? '',
              source: 'wherelog link',
            ));
            return results; // exact, return early
          }
        }
      }
    } catch (_) {}

    // 2. Look for lat,lng in query params and Google formats
    final queryParamPatterns = [
      RegExp(r'[?&]query=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]destination=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]daddr=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]q=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'"lat":\s*(-?\d+\.\d+)\s*,\s*"lng":\s*(-?\d+\.\d+)'),
      RegExp(r'center=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)'),
    ];

    for (final pattern in queryParamPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          final name = _extractName(text) ?? 'Imported from Map Link';
          results.add(PoiImportData(
            name: name,
            lat: lat,
            lng: lng,
            address: '',
            source: 'map link',
          ));
          return results;
        }
      }
    }

    // 3. Fallback: find any lat,lng pair in text
    final matches = _latLngRegex.allMatches(text);
    for (final m in matches) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && _validLatLng(lat, lng)) {
        final name = _extractName(text) ?? 'Imported POI';
        results.add(PoiImportData(
          name: name,
          lat: lat,
          lng: lng,
          address: '',
          source: 'clipboard',
        ));
        // Only take first valid pair for clipboard import (usually 1 POI)
        break;
      }
    }

    return results;
  }

  static String? _extractName(String text) {
    // Try to get first line as name if it doesn't look like coords or URL
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    
    // If first line is "WhereLog POI: Name" format
    if (lines[0].toLowerCase().startsWith('wherelog poi:')) {
      return lines[0].substring('wherelog poi:'.length).trim();
    }
    
    // If first line doesn't contain http, geo:, or look like coords, use it as name
    final first = lines[0];
    if (!first.contains('http') && 
        !first.contains('geo:') && 
        !first.contains('maps.apple.com') &&
        !first.contains('google.com/maps') &&
        !_latLngRegex.hasMatch(first) &&
        first.length < 80) {
      return first;
    }
    return null;
  }

  static bool _validLatLng(double lat, double lng) {
    if (lat == 0 && lng == 0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  // ---- Clipboard ----
  static Future<List<PoiImportData>> importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return [];
      return parseSharedText(text);
    } catch (e) {
      return [];
    }
  }

  // ---- GPX File ----
  // Standard GPX waypoint format:
  // <wpt lat="38.9" lon="-78.3"><name>Stoney Creek</name></wpt>
  static Future<List<PoiImportData>> importFromGpxFile() async {
    try {
      final files = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['gpx'],
      );
      if (files == null || files.isEmpty) return [];

      final file = files.first;
      if (file.path == null) return [];
      final content = await File(file.path!).readAsString();

      return parseGpxContent(content);
    } catch (e) {
      return [];
    }
  }

  static List<PoiImportData> parseGpxContent(String gpxString) {
    final List<PoiImportData> results = [];
    try {
      final doc = xml.XmlDocument.parse(gpxString);
      final waypoints = doc.findAllElements('wpt');
      
      for (final wpt in waypoints) {
        final latStr = wpt.getAttribute('lat');
        final lonStr = wpt.getAttribute('lon');
        if (latStr == null || lonStr == null) continue;
        
        final lat = double.tryParse(latStr);
        final lng = double.tryParse(lonStr);
        if (lat == null || lng == null || !_validLatLng(lat, lng)) continue;

        final nameEl = wpt.findElements('name').isNotEmpty ? wpt.findElements('name').first.innerText : 'GPX Waypoint';
        final descEl = wpt.findElements('desc').isNotEmpty ? wpt.findElements('desc').first.innerText : '';
        final cmtEl = wpt.findElements('cmt').isNotEmpty ? wpt.findElements('cmt').first.innerText : '';

        results.add(PoiImportData(
          name: nameEl.trim().isNotEmpty ? nameEl.trim() : 'GPX Waypoint',
          lat: lat,
          lng: lng,
          address: descEl.isNotEmpty ? descEl : cmtEl,
          source: 'gpx file',
        ));
      }
    } catch (e) {
      // Fallback regex if XML parsing fails
      final wptRegex = RegExp(r'<wpt[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"[^>]*>.*?<name>(.*?)</name>', dotAll: true);
      for (final m in wptRegex.allMatches(gpxString)) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          results.add(PoiImportData(
            name: m.group(3)?.trim() ?? 'GPX Waypoint',
            lat: lat,
            lng: lng,
            source: 'gpx file',
          ));
        }
      }
    }
    return results;
  }
}
