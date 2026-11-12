import 'dart:io';
import 'dart:convert';
import 'dart:math' as math;
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
  final String source; // provenance value, e.g. 'Google Maps link'

  /// True when [name] is a generated staging label for an unnamed
  /// import ('POI import from Google Maps', 'Dropped pin', ...).
  /// The label exists so the user can tell staged items apart; it
  /// is scaffolding, never a name to keep — the add screen asks
  /// before saving and records 'Unnamed place' instead.
  final bool nameIsPlaceholder;

  /// True when this entry is not an import at all: a non-.gpx
  /// file opened or shared into WhereLog. It carries the file's
  /// name and no coordinates, and the queue offers Delete as its
  /// only action — it can never enter the verify gate.
  final bool rejected;

  /// True when [lat]/[lng] came from a viewport-grade pattern
  /// (the @ / center= camera of a map link) rather than from the
  /// place itself. Such results are approximate by construction
  /// and are eligible for the geocoding refinement pass.
  final bool coordsAreViewport;

  PoiImportData({
    required this.name,
    required this.lat,
    required this.lng,
    this.address = '',
    this.source = '',
    this.nameIsPlaceholder = false,
    this.coordsAreViewport = false,
    this.rejected = false,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'lat': lat,
    'lng': lng,
    'address': address,
    'source': source,
    'nameIsPlaceholder': nameIsPlaceholder,
    'coordsAreViewport': coordsAreViewport,
    'rejected': rejected,
  };

  factory PoiImportData.fromJson(Map<String, dynamic> j) {
    final name = j['name']?.toString() ?? 'Imported POI';
    return PoiImportData(
      name: name,
      lat: (j['lat'] is num) ? (j['lat'] as num).toDouble() : double.tryParse(j['lat']?.toString() ?? '') ?? 0,
      lng: (j['lng'] is num) ? (j['lng'] as num).toDouble() : double.tryParse(j['lng']?.toString() ?? '') ?? 0,
      address: j['address']?.toString() ?? '',
      source: _normalizeLegacySource(j['source']?.toString() ?? ''),
      // Queued entries from before the flag existed are recognised
      // by their generated labels.
      nameIsPlaceholder: j['nameIsPlaceholder'] == true || _legacyPlaceholders.contains(name),
      coordsAreViewport: j['coordsAreViewport'] == true,
      rejected: j['rejected'] == true,
    );
  }

  /// Source strings written by earlier versions, mapped to the
  /// current provenance values.
  static String _normalizeLegacySource(String s) {
    switch (s) {
      case 'map link':
        return 'Map link';
      case 'clipboard':
        return 'Pasted coordinates';
      case 'gpx file':
        return 'GPX file';
      case 'wherelog link':
        return 'WhereLog link';
      default:
        return s;
    }
  }

  static const Set<String> _legacyPlaceholders = {
    'Imported POI',
    'Imported from Map Link',
    'GPX Waypoint',
    'POI import from Google Maps',
    'POI import from Apple Maps',
    'POI import from Waze',
    'Dropped pin',
    'POI import',
  };
}

/// One geocoding answer, with its distance from the anchor
/// point it was biased to.
class _GeocodeHit {
  final double lat;
  final double lng;
  final String displayName;
  final double distanceM;
  const _GeocodeHit(this.lat, this.lng, this.displayName, this.distanceM);
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
      final isShort = url.contains('goo.gl') ||
          url.contains('maps.app.goo.gl') ||
          url.contains('maps.apple');
      if (!isShort) return text;

      final client = http.Client();
      try {
        final resp = await client.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
        // The URL the redirects land on is the prize: a resolved
        // google.com/maps URL carries the place's own !3d/!4d pin.
        // It leads the combined text so that, pattern for pattern,
        // its values are found before any lookalike pair buried in
        // the page body (which may hold other places' coordinates).
        final finalUrl = resp.request?.url.toString() ?? '';
        // Parse the whole body (capped only for safety): the
        // first chunk of Google's preview page holds only the
        // preview map's camera, never the place itself.
        final combined =
            resp.body.substring(0, resp.body.length > 400000 ? 400000 : resp.body.length);
        return '$finalUrl $combined $url $text';
      } finally {
        client.close();
      }
    } catch (e) {
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
            final qName = uri.queryParameters['name'];
            results.add(PoiImportData(
              name: qName ?? _senderFallbackName(text),
              lat: lat,
              lng: lng,
              address: uri.queryParameters['address'] ?? '',
              source: 'WhereLog link',
              nameIsPlaceholder: qName == null,
            ));
            return results;
          }
        }
      }
    } catch (_) {}

    // 2. Query-param and payload patterns. ORDER IS LOAD-BEARING:
    // patterns are tried in list order and the first match wins, so
    // sources that carry the place's own coordinates come before
    // sources that carry the map's viewport. A Google place URL
    // contains both — !3d/!4d is the pin, @ is only where the
    // sharer's camera was centred, which can be miles from the pin.
    final queryParamPatterns = [
      // The place's own pin, from a Google data payload.
      RegExp(r'!3d(-?\d+\.\d+)!4d(-?\d+\.\d+)'),
      // Explicit coordinate parameters: the destination/pin by
      // construction.
      RegExp(r'[?&]query=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]destination=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]daddr=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]q=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]ll=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      RegExp(r'[?&]coordinate=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)', caseSensitive: false),
      // A JSON place object's own coordinates.
      RegExp(r'"lat":\s*(-?\d+\.\d+)\s*,\s*"lng":\s*(-?\d+\.\d+)'),
      // Viewport centres — only when nothing exact exists.
      RegExp(r'@(-?\d+\.\d+),(-?\d+\.\d+)'),
      RegExp(r'center=(-?\d+\.\d+)[,\s%2C]+(-?\d+\.\d+)'),
      RegExp(r'\bq=.*@(-?\d+\.\d+),(-?\d+\.\d+)'),
    ];

    // The last three patterns in the list are the viewport-grade
    // ones (@, center=, q=...@): they describe the camera, not
    // the place. A win by one of them flags the result so the
    // caller can refine it by geocoding the address text.
    final firstViewportPattern = queryParamPatterns.length - 3;
    for (var pi = 0; pi < queryParamPatterns.length; pi++) {
      final pattern = queryParamPatterns[pi];
      final m = pattern.firstMatch(text);
      if (m != null) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          final name = _extractName(text) ?? _extractNameFromPlaceUrl(text) ?? 'Imported from Map Link';
          // Fix: if name is still generic but we have q= place name, use that
          final betterName = _extractNameFromPlaceUrl(text) ?? name;
          final resolvedName = betterName != 'Imported from Map Link' ? betterName : name;
          results.add(PoiImportData(
            name: resolvedName,
            lat: lat,
            lng: lng,
            // A nameless result is a bare pin: its package
            // carries no address, so anything the extractors
            // scrape for one is ambient page text, not the
            // place's address. Leave it empty.
            address: resolvedName == 'Imported from Map Link'
                ? ''
                : (_extractAddress(text) ?? _extractAddressFromPlaceUrl(text) ?? ''),
            source: _originSource(text, 'Map link'),
            nameIsPlaceholder: resolvedName == 'Imported from Map Link',
            coordsAreViewport: pi >= firstViewportPattern,
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
        final extracted = _extractName(text) ?? _extractNameFromPlaceUrl(text);
        results.add(PoiImportData(
          name: extracted ?? _senderFallbackName(text),
          lat: lat,
          lng: lng,
          // Bare pin, same as the pattern path: no address
          // exists to extract.
          address: extracted == null
              ? ''
              : (_extractAddress(text) ?? _extractAddressFromPlaceUrl(text) ?? ''),
          source: _originSource(text, 'Pasted coordinates'),
          nameIsPlaceholder: extracted == null,
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

  /// The provenance value for a text import: the sender app when
  /// the text betrays one, else [fallback] for the channel itself.
  static String _originSource(String text, String fallback) {
    final lower = text.toLowerCase();
    if (lower.contains('google.com/maps') || lower.contains('maps.app.goo.gl') || lower.contains('goo.gl')) return 'Google Maps link';
    if (lower.contains('maps.apple.com')) return 'Apple Maps link';
    if (lower.contains('waze.com')) return 'Waze link';
    return fallback;
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
        // skip if raw is purely lat,lng, in any separator form
        if (_isCoordPairText(raw)) {
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
        if (_isCoordPairText(raw)) continue;
        if (raw.contains('%2C') || raw.contains('+') || raw.contains('%20')) {
          raw = raw.replaceAll('+', ' ');
          try { raw = Uri.decodeComponent(raw); } catch (_) {}
          raw = raw.trim();
          if (_isCoordPairText(raw)) continue;
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
        if (raw.isNotEmpty && raw.length < 120 && raw.toLowerCase() != 'google maps' && !_isCoordPairText(raw)) return raw;
      }
      // 4. og:title
      final og = RegExp(r'property="og:title"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(text);
      if (og != null) {
        var raw = og.group(1)!.replaceAll(RegExp(r'\s*-\s*Google Maps.*', caseSensitive: false), '').trim();
        if (raw.isNotEmpty && raw.length < 120 && !raw.toLowerCase().contains('google maps') && !raw.contains('http') && !_isCoordPairText(raw)) return raw;
      }
    } catch (_) {}
    return null;
  }

  static String? _extractAddressFromPlaceUrl(String text) {
    try {
      final allQ = RegExp(r'q=([^&"\s]+)', caseSensitive: false).allMatches(text);
      for (final mm in allQ) {
        var raw = mm.group(1)!;
        if (_isCoordPairText(raw)) continue;
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

  /// True when [raw] is nothing but a coordinate pair, in any
  /// separator form (URL-encoded or plain comma, optional '+'
  /// space). A dropped pin's identity in a link IS its
  /// coordinates; scraped as a "name" or an "address" they are
  /// neither — a name field holding coordinates is a second,
  /// stalable copy of data the record already carries typed,
  /// and it silently bypasses the placeholder-name reminder.
  static bool _isCoordPairText(String raw) {
    var s = raw.trim();
    try {
      s = Uri.decodeComponent(s);
    } catch (_) {}
    s = s.replaceAll('+', ' ').trim();
    return RegExp(r'^-?\d+\.\d+,\s*-?\d+\.\d+$').hasMatch(s);
  }

  static bool _validLatLng(double lat, double lng) {
    if (lat == 0 && lng == 0) return false;
    if (lat < -90 || lat > 90) return false;
    if (lng < -180 || lng > 180) return false;
    return true;
  }

  /// Refinement pass for viewport-grade results. A Google
  /// address or place share yields only the preview camera's
  /// coordinates (proven in the field, Nov 2026: the fetched
  /// page itself contains no pin, only span/centre/zoom). Two
  /// recovery rungs, in order:
  ///
  /// 1. The preview page names a data endpoint
  ///    (/maps/preview/place) whose payload opens with the map
  ///    frame [span, lng, lat] for whatever it is displaying.
  ///    For a place share that frame is centred on the place
  ///    itself (Luray Caverns: the frame sat on the caverns
  ///    while the page's own camera sat on the sharer's home
  ///    area); for an address share it merely repeats the
  ///    camera. So adopt the endpoint's frame only when it
  ///    differs materially (> 100 m) from the camera point we
  ///    already have — agreement means it carried no new
  ///    information.
  /// 2. Geocode the share's own text with Nominatim (the
  ///    service the map picker's search already uses), biased
  ///    to a viewbox around the camera point, accepting only a
  ///    result within 30 km of it, nearest first. The raw
  ///    condensed query must never be geocoded unanchored:
  ///    "572 E Main St 4050" alone resolves to Maine or New
  ///    York.
  ///
  /// If both rungs fail, the camera point stands — approximate,
  /// never a fabricated fix — and the add screen asks the user
  /// to check the pin on the map.
  static Future<List<PoiImportData>> refineViewportResults(
      List<PoiImportData> results, String contextText) async {
    final out = <PoiImportData>[];
    for (final r in results) {
      if (!r.coordsAreViewport) {
        out.add(r);
        continue;
      }
      PoiImportData refined = r;
      try {
        // Rung 1: the preview data endpoint's own frame.
        final endpointPoint = await _previewEndpointPoint(contextText);
        if (endpointPoint != null &&
            _distanceMeters(r.lat, r.lng, endpointPoint[0], endpointPoint[1]) > 100) {
          refined = PoiImportData(
            name: r.name,
            lat: endpointPoint[0],
            lng: endpointPoint[1],
            address: r.address,
            source: r.source,
            nameIsPlaceholder: r.nameIsPlaceholder,
          );
        }
        // Rung 2: geocode the share's text, anchored.
        if (identical(refined, r)) {
          final candidates = _addressCandidates(contextText, r);
          String? locality;
          for (final candidate in candidates) {
            var hit = await _nominatimNearest(candidate, r.lat, r.lng);
            if (hit == null) {
              // One retry with the neighbourhood named: reverse-
              // geocode the camera point for its town and state.
              locality ??= await _nominatimLocality(r.lat, r.lng);
              if (locality != null && !candidate.toLowerCase().contains(locality.toLowerCase().split(',').first.trim())) {
                hit = await _nominatimNearest('$candidate, $locality', r.lat, r.lng);
              }
            }
            if (hit != null) {
              refined = PoiImportData(
                name: r.name,
                lat: hit.lat,
                lng: hit.lng,
                address: r.address.isNotEmpty ? r.address : hit.displayName,
                source: r.source,
                nameIsPlaceholder: r.nameIsPlaceholder,
              );
              break;
            }
          }
        }
      } catch (_) {
        // Any failure keeps the camera point.
        refined = r;
      }
      out.add(refined);
    }
    return out;
  }

  /// The /maps/preview/place link a Google preview page carries
  /// in its head, with HTML entity escaping undone; null when
  /// the text holds no such link.
  static String? _previewLink(String text) {
    final m = RegExp(r'/maps/preview/place\?[^"\s]+').firstMatch(text);
    if (m == null) return null;
    return m.group(0)!.replaceAll('&amp;', '&');
  }

  /// The share's own query text — for a Google place share, the
  /// fullest description available anywhere in the payload
  /// ("Luray Caverns, 101 Cave Hill Rd, Luray, VA 22835").
  /// Decoded from the preview link's q= parameter, falling back
  /// to any q= in the text itself. Null when what is found is
  /// just a coordinate pair, which needs no geocoding.
  static String? _shareQueryText(String text) {
    String? raw;
    final link = _previewLink(text);
    if (link != null) {
      raw = RegExp(r'[?&]q=([^&]+)').firstMatch(link)?.group(1);
    }
    raw ??= RegExp(r'[?&]q=([^&\s"]+)').firstMatch(text)?.group(1);
    if (raw == null) return null;
    var s = raw.replaceAll('+', ' ');
    try {
      s = Uri.decodeComponent(s);
    } catch (_) {}
    s = s.trim();
    if (s.isEmpty) return null;
    if (RegExp(r'^-?\d+\.\d+\s*,\s*-?\d+\.\d+$').hasMatch(s)) return null;
    return s;
  }

  /// Fetch the preview data endpoint named in [contextText]
  /// and read the map frame its payload opens with:
  /// [[spanMetres, lng, lat], ...]. Returns [lat, lng], or
  /// null when there is no link, the fetch fails, or the
  /// frame does not parse to a valid point.
  static Future<List<double>?> _previewEndpointPoint(String contextText) async {
    try {
      final link = _previewLink(contextText);
      if (link == null) return null;
      final resp = await http
          .get(Uri.parse('https://www.google.com$link'))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode != 200) return null;
      final m = RegExp(r'\[\[\s*(\d+(?:\.\d+)?)\s*,\s*(-?\d{1,3}\.\d+)\s*,\s*(-?\d{1,2}\.\d+)\s*\]')
          .firstMatch(resp.body);
      if (m == null) return null;
      final lng = double.tryParse(m.group(2)!);
      final lat = double.tryParse(m.group(3)!);
      if (lat == null || lng == null || !_validLatLng(lat, lng)) return null;
      return [lat, lng];
    } catch (_) {
      return null;
    }
  }


  /// Strings worth geocoding, best first: the share's own
  /// query text (the fullest description in the payload), the
  /// imported name itself (bare place names allowed — a
  /// trailhead has no house number, and Nominatim resolves
  /// "Luray Caverns" as surely as a street address), then page
  /// metadata (og tags, title, a JSON "address"), which keeps
  /// the old address-shape requirement to limit noise.
  /// Google's boilerplate page description is filtered out:
  /// geocoding it wastes calls and can never hit.
  static List<String> _addressCandidates(String text, PoiImportData r) {
    final out = <String>[];
    void add(String? raw, {bool requireSignal = false}) {
      if (raw == null) return;
      var s = raw
          .replaceAll('&amp;', '&')
          .replaceAll('&#39;', "'")
          .replaceAll('&quot;', '"')
          .replaceAll(RegExp(r'\s*[-\u00b7]\s*Google Maps.*$', caseSensitive: false), '')
          .trim();
      if (s.length < 3 || s.length > 200) return;
      final lower = s.toLowerCase();
      if (lower == 'google maps') return;
      if (lower.contains('find local businesses') ||
          lower.contains('get driving directions')) return;
      if (requireSignal && !RegExp(r'\d').hasMatch(s) && !s.contains(',')) return;
      if (!out.contains(s)) out.add(s);
    }

    add(_shareQueryText(text));
    if (!r.nameIsPlaceholder) add(r.name);
    add(_metaContent(text, 'og:description'), requireSignal: true);
    add(_metaContent(text, 'og:title'), requireSignal: true);
    add(RegExp(r'<title>([^<]+)</title>', caseSensitive: false).firstMatch(text)?.group(1), requireSignal: true);
    add(RegExp(r'"address"\s*:\s*"([^"]{8,200})"').firstMatch(text)?.group(1), requireSignal: true);
    return out;
  }


  static String? _metaContent(String text, String property) {
    final a = RegExp('(?:property|name)="$property"[^>]*content="([^"]+)"', caseSensitive: false).firstMatch(text);
    if (a != null) return a.group(1);
    final b = RegExp('content="([^"]+)"[^>]*(?:property|name)="$property"', caseSensitive: false).firstMatch(text);
    return b?.group(1);
  }

  static Future<_GeocodeHit?> _nominatimNearest(String query, double anchorLat, double anchorLng) async {
    try {
      const delta = 0.5;
      final viewbox =
          '${anchorLng - delta},${anchorLat + delta},${anchorLng + delta},${anchorLat - delta}';
      final uri = Uri.parse('https://nominatim.openstreetmap.org/search'
          '?q=${Uri.encodeComponent(query)}'
          '&format=json&limit=5&addressdetails=1'
          '&viewbox=$viewbox&bounded=0');
      final resp = await http.get(uri, headers: const {
        'User-Agent': 'WhereLog/1.0 (wherelog app; contact: wherelog.app)',
      }).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) {
        return null;
      }
      final List data = jsonDecode(resp.body) as List;
      _GeocodeHit? best;
      for (final e in data) {
        final lat = double.tryParse(e['lat'].toString());
        final lng = double.tryParse(e['lon'].toString());
        if (lat == null || lng == null) continue;
        final d = _distanceMeters(anchorLat, anchorLng, lat, lng);
        if (d > 30000) continue;
        if (best == null || d < best.distanceM) {
          best = _GeocodeHit(lat, lng, e['display_name']?.toString() ?? query, d);
        }
      }
      return best;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> _nominatimLocality(double lat, double lng) async {
    try {
      final uri = Uri.parse('https://nominatim.openstreetmap.org/reverse'
          '?lat=$lat&lon=$lng&format=json&zoom=14');
      final resp = await http.get(uri, headers: const {
        'User-Agent': 'WhereLog/1.0 (wherelog app; contact: wherelog.app)',
      }).timeout(const Duration(seconds: 12));
      if (resp.statusCode != 200) return null;
      final decoded = jsonDecode(resp.body);
      final addr = decoded['address'];
      if (addr is! Map) return null;
      final town = (addr['town'] ?? addr['city'] ?? addr['village'] ?? addr['hamlet'])?.toString();
      final state = addr['state']?.toString();
      if (town == null || town.isEmpty) return null;
      final loc = state == null || state.isEmpty ? town : '$town, $state';
      return loc;
    } catch (_) {
      return null;
    }
  }

  static double _distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    const earthKm = 6371.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLng = (lng2 - lng1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) * math.cos(lat2 * math.pi / 180.0) * math.sin(dLng / 2) * math.sin(dLng / 2);
    return earthKm * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a)) * 1000.0;
  }

  static Future<List<PoiImportData>> importFromClipboard() async {
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      final text = data?.text ?? '';
      if (text.isEmpty) return [];
      var results = parseSharedText(text);
      var contextText = text;
      if (results.isEmpty) {
        // Same courtesy the share-sheet path gets: a pasted short
        // link is expanded and parsed again before giving up.
        final lower = text.toLowerCase();
        if (lower.contains('goo.gl') || lower.contains('maps.app.goo.gl')) {
          final expanded = await tryExpandShortLink(text);
          contextText = expanded;
          results = parseSharedText(expanded);
          if (results.isEmpty) {
            results = parseSharedText('$expanded $text');
          }
        }
      }
      if (results.isNotEmpty) {
        results = await refineViewportResults(results, contextText);
      }
      return results;
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

  /// Parses a GPX file already on disk — the shape an external
  /// "Open with WhereLog" (or a share of the file itself)
  /// arrives in, as opposed to the in-app picker's own flow.
  static Future<List<PoiImportData>> importFromGpxPath(String path) async {
    try {
      final content = await File(path).readAsString();
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
        final rawName = wpt.findElements('name').isNotEmpty ? wpt.findElements('name').first.innerText.trim() : '';
        final descEl = wpt.findElements('desc').isNotEmpty ? wpt.findElements('desc').first.innerText : '';
        final cmtEl = wpt.findElements('cmt').isNotEmpty ? wpt.findElements('cmt').first.innerText : '';
        results.add(PoiImportData(
          name: rawName.isNotEmpty ? rawName : 'GPX Waypoint',
          lat: lat,
          lng: lng,
          address: descEl.isNotEmpty ? descEl : cmtEl,
          source: 'GPX file',
          nameIsPlaceholder: rawName.isEmpty,
        ));
      }
    } catch (e) {
      final wptRegex = RegExp(r'<wpt[^>]*lat="([^"]+)"[^>]*lon="([^"]+)"[^>]*>.*?<name>(.*?)</name>', dotAll: true);
      for (final m in wptRegex.allMatches(gpxString)) {
        final lat = double.tryParse(m.group(1)!);
        final lng = double.tryParse(m.group(2)!);
        if (lat != null && lng != null && _validLatLng(lat, lng)) {
          final rawName = m.group(3)?.trim() ?? '';
          results.add(PoiImportData(
            name: rawName.isNotEmpty ? rawName : 'GPX Waypoint',
            lat: lat,
            lng: lng,
            address: '',
            source: 'GPX file',
            nameIsPlaceholder: rawName.isEmpty,
          ));
        }
      }
    }
    return results;
  }
}
