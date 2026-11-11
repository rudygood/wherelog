import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Share-intake diagnostics (added 2026-11-10, on the clipboard
/// describeClip precedent): when a share opens WhereLog on iOS but
/// nothing reaches the import queue, this makes the invisible
/// visible — a persistent log of everything the share intake was
/// handed (before parsing), and a native report of which app-group
/// containers the app can actually resolve on the device and what
/// is in them. Surfaced by long-pressing the POI tab's import
/// button. Remove with the rest of the diagnostic once the iOS
/// share path is proven.
class ShareDiagService {
  static const MethodChannel _channel = MethodChannel('com.wherelog/share_diag');
  static const String _logKey = 'shareDiagLog';

  /// What the native side can see of the app-group containers:
  /// which group identifiers resolve, and their contents. iOS only;
  /// on Android the bridge does not exist and this says so.
  static Future<String> containerReport() async {
    try {
      return await _channel.invokeMethod<String>('containerReport') ??
          '(no reply from the native side)';
    } catch (e) {
      return 'Container report unavailable: $e';
    }
  }

  /// Appends one timestamped line to the persistent intake log.
  static void logEvent(String event) {
    _append(event);
  }

  static Future<void> _append(String event) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final log = prefs.getStringList(_logKey) ?? <String>[];
      final stamp = DateTime.now().toIso8601String().substring(0, 19);
      log.add('$stamp  $event');
      while (log.length > 12) {
        log.removeAt(0);
      }
      await prefs.setStringList(_logKey, log);
    } catch (_) {}
  }

  static Future<List<String>> readLog() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_logKey) ?? <String>[];
  }

  static Future<void> clearLog() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_logKey);
  }
}
