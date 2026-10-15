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

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'address': address,
    'source': source,
  };

  factory PoiImportData.fromJson(Map<String, dynamic> j) => PoiImportData(
    name: j['name']?.toString() ?? 'Imported POI',
    lat: (j['lat'] is num) ? (j['lat'] as num).toDouble() : double.tryParse(j['lat']?.toString() ?? '') ?? 0,
    lng: (j['lng'] is num) ? (j['lng'] as num).toDouble() : double.tryParse(j['lng']?.toString() ?? '') ?? 0,
    address: j['address']?.toString() ?? '',
    source: j['source']?.toString() ?? '',
  );
}

class PoiImportUtils {
  static final RegExp _latLngRegex = RegExp(
    r'(-?\d{1,2}\.\d+)[,\s]+(-?\d{1,3}\.\d+)',
  );

  static Future<String> tryExpandShortLink(String text) async {
    try {
      final urlMatch = RegExp(r'https?://[^\s]+').firstMatch(text);
      if (urlMatch == null) return text;
      String url = urlMatch.group(0)!;
      url = url.replaceAll(RegExp(r'[\).,]+$'), '');
      final isShort = url.contains('goo.gl') || url.contains('maps.app.goo.gl');
      if (!isShort) return text;

      final client = http.Client();
      try {
        final resp = await client.get(Uri.parse(url)).timeout(Duration(seconds: 10));
        String combined = resp.body;
        return combined.substring(0, combined.length > 15000 ? 15000 : combined.length) + ' ' + url + ' ' + text;
      } finally {
        client.close();
      }
    } catch (_) {
      return text;
    }
  }

  static List<PoiImportData> parseSharedText(String text) {
    final List<PoiImportData> results = [];
    if (text.trim().isEmpty) return results;

    final String lower = text.toLowerCase();

    // 1. wherelog:// scheme
    try {
      if (lower.contains('wherelog://')) {
        final uri = Uri.parse(text.trim().split(RegExp(r'\s')).firstWhere((s) => s.contains('wherelog://'), orElse: () => ''));
        if (uri.scheme == 'wherelog') {
          final lat = double.tryParse(uri.queryParameters['lat'] ?? '');
          final lng = double.tryParse(uri.queryParameters['lng'] ?? '');
          if (lat != null && lng != null) {
            results.add(PoiImportData(
              name: uri.queryParameters['name'] ?? _senderFallbackName(text),
              lat: lat,
              lng: lng,
              address: uri.queryParameters['address'] ?? '',
              source: 'wherelog link',
            ));
            return results;
          }
        }
      }
    } catch (_) {}

    // 2. query param patterns including Apple ll, center, etc.
    final queryParamPatterns = [
      RegExp(r'[?&]query=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]destination=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]daddr=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]q=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]ll=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]coordinate=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      RegExp(r'"lat":\s*(-?\d+\.\d+)\s*,\s*"lng":\s*(-?\d+\.\d+)'),
      RegExp(r'center=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)'),
      RegExp(r'\bq=.*@(-?\d+\.\d+),(-?\d+\.\d+)'),
    ];

    for (final pattern in queryParamPatterns) {
      final m = pattern.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          final name = _extractName(text) ?? _extractNameFromPlaceUrl(text) ?? 'Imported from Map Link';
          // Fix: if name is still generic but we have q= place name, use that
          final betterName = _extractNameFromPlaceUrl(text) ?? name;
          results.add(PoiImportData(
            name: betterName != 'Imported from Map Link' ? betterName : name,
            lat: lat,
            lng: lng,
            address: _extractAddress(text) ?? _extractAddressFromPlaceUrl(text) ?? '',
            source: 'map link',
          ));
          return results;
        }
      }
    }

    // 3. Fallback lat,lng pair
    final matches = _latLngRegex.allMatches(text);
    for (final m in matches) {
      final lat = double.tryParse(m.group(1)!);
      final lng = double.tryParse(m.group(2)!);
      if (lat != null && lng != null && _validLatLng(lat, lng)) {
        final name = _extractName(text) ?? _extractNameFromPlaceUrl(text) ?? _senderFallbackName(text);
        results.add(PoiImportData(
          name: name,
          lat: lat,
          lng: lng,
          address: _extractAddress(text) ?? _extractAddressFromPlaceUrl(text) ?? '',
          source: 'clipboard',
        ));
        break;
      }
    }

    return results;
  }

  static String? _extractName(String text) {
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.isEmpty) return null;
    final first = lines[0];
    if (!first.contains('http') &&
        !first.contains('geo:') &&
        !first.contains('maps.apple.com') &&
        !first.contains('google.com/maps') &&
        !first.contains('maps.app.goo.gl') &&
        !_latLngRegex.hasMatch(first) &&
        first.length < 120) {
      return first;
    }
    if (lines.length > 1) {
      final second = lines[1];
      if (!second.contains('http') && !_latLngRegex.hasMatch(second) && second.length < 120) {
        if (first.contains('http') || first.contains('Check out')) {
          return second;
        }
      }
    }
    // Try place URL name as fallback
    final fromUrl = _extractNameFromPlaceUrl(text);
    if (fromUrl != null) return fromUrl;
    return null;
  }

  static String? _extractAddress(String text) {
    // First try q= address
    final fromQ = _extractAddressFromPlaceUrl(text);
    if (fromQ != null) return fromQ;
    final lines = text.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    if (lines.length >= 2) {
      for (int i = 1; i < lines.length && i <= 4; i++) {
        final line = lines[i];
        if (line.contains('http') || line.contains('geo:')) continue;
        if (_latLngRegex.hasMatch(line)) continue;
        if (line.length > 8 && line.length < 250) {
          if (line.contains(',')) {
            if (lines[0].toLowerCase() != line.toLowerCase()) return line;
          }
          if (i == 1 && line.length > 10 && RegExp(r'\d').hasMatch(line)) {
            return line;
          }
        }
      }
    }
    try {
      final fmt = RegExp(r'"formatted_address"\s*:\s*"([^"]+)"').firstMatch(text);
      if (fmt != null) {
        var raw = fmt.group(1)!.trim();
        if (raw.length > 8 && raw.length < 250) return raw;
      }
    } catch (_) {}
    return null;
  }

  static String _senderFallbackName(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('google.com/maps') || lower.contains('maps.app.goo.gl') || lower.contains('goo.gl')) {
      return 'POI import from Google Maps';
    }
    if (lower.contains('maps.apple.com')) return 'POI import from Apple Maps';
    if (lower.contains('waze.com')) return 'POI import from Waze';
    if (_latLngRegex.hasMatch(text)) return 'Dropped pin';
    return 'POI import';
  }

  static String? _extractNameFromPlaceUrl(String text) {
    try {
      // 1. q= param: q=The+Bramblewood+Lodge%2C+901+Wildwood+Ln%2C+Shenandoah%2C+VA+22849
      final qMatch = RegExp(r'q=([^&"\s]+)', caseSensitive: false).firstMatch(text);
      if (qMatch != null) {
        var raw = qMatch.group(1)!;
        // skip if raw is purely lat,lng
        if (RegExp(r'^-?\d+\.\d+%2C-?\d+\.\d+$').hasMatch(raw)) {
          // try next q= occurrence
        } else {
          raw = raw.replaceAll('+', ' ');
          try { raw = Uri.decodeComponent(raw); } catch (_) {}
          // raw like "The Bramblewood Lodge, 901 Wildwood Ln, Shenandoah, VA 22849"
          raw = raw.trim();
          if (raw.isNotEmpty && raw.length < 200) {
            final parts = raw.split(',');
            final first = parts[0].trim();
            if (first.isNotEmpty && first.length < 120 && first.toLowerCase() != 'google maps' && !first.contains('http')) {
              // Ensure first is not just a number and not lat,lng
              if (!RegExp(r'^-?\d+\.\d+$').hasMatch(first)) {
                return first;
              }
            }
          }
        }
      }
      // 2. Look for all q= occurrences, second might be name
      final allQ = RegExp(r'q=([^&"\s]+)', caseSensitive: false).allMatches(text);
      for (final mm in allQ) {
        var raw = mm.group(1)!;
        if (RegExp(r'^-?\d+\.\d+%2C-?\d+\.\d+$').hasMatch(raw)) continue;
        if (raw.contains('%2C') || raw.contains('+') || raw.contains('%20')) {
          raw = raw.replaceAll('+', ' ');
          try { raw = Uri.decodeComponent(raw); } catch (_) {}
          raw = raw.trim();
          if (raw.contains(',')) {
            final first = raw.split(',')[0].trim();
            if (first.length > 2 && first.length < 120 && !first.contains('http') && first.toLowerCase() != 'google maps') {
              return first;
            }
          }
        }
      }
      // 3. /place/NAME
      final pr = RegExp(r'/place/([^/@]+)', caseSensitive: false).firstMatch(text);
      if (pr != null) {
        var raw = pr.group(1)!.replaceAll('+', ' ');
        try { raw = Uri.decodeComponent(raw); } catch (_) {}
        raw = raw.trim();
        if (raw.isNotEmpty && raw.length < 120 && raw.toLowerCase() != 'google maps') return raw;
      }
      // 4. og:title
      final og = RegExp(r'property="og:title"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(text);
      if (og != null) {
        var raw = og.group(1)!.replaceAll(RegExp(r'\s*-\s*Google Maps.*', caseSensitive: false), '').trim();
        if (raw.isNotEmpty && raw.length < 120 && !raw.toLowerCase().contains('google maps') && !raw.contains('http')) return raw;
      }
    } catch (_) {}
    return null;
  }

  static String? _extractAddressFromPlaceUrl(String text) {
    try {
      final allQ = RegExp(r'q=([^&"\s]+)', caseSensitive: false).allMatches(text);
      for (final mm in allQ) {
        var raw = mm.group(1)!;
        if (RegExp(r'^-?\d+\.\d+%2C-?\d+\.\d+$').hasMatch(raw)) continue;
        if (raw.contains('%2C')) {
          raw = raw.replaceAll('+', ' ');
          try { raw = Uri.decodeComponent(raw); } catch (_) {}
          raw = raw.trim();
          if (raw.contains(',')) {
            final idx = raw.indexOf(',');
            var addr = raw.substring(idx+1).trim();
            if (addr.length > 5 && addr.length < 250) return addr;
          }
        }
      }
    } catch (_) {}
    return null;
  }

  static bool _validLatLng(double lat, double lng) {
    if (lat == 0 && lng == 0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

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
      final wptRegex = RegExp(r'<wpt[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"[^>]*>.*?<name>(.*?)</name>', dotAll: true);
      for (final m in wptRegex.allMatches(gpxString)) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          results.add(PoiImportData(
            name: m.group(3)?.trim() ?? 'GPX Waypoint',
            lat: lat,
            lng: lng,
            address: '',
            source: 'gpx file',
          ));
        }
      }
    }
    return results;
  }
}
