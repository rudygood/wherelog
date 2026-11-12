import 'package:flutter/services.dart';

/// Bridge for a GPX file iOS handed to WhereLog from outside
/// the app ("Open with WhereLog" on a .gpx in Files or Mail).
/// The native side holds the file's content in a mailbox: on a
/// cold start Dart takes it with [takePendingGpxContent]; while
/// the app is already running, the native side calls the
/// availability handler as soon as the file arrives.
class IncomingGpxService {
  static const MethodChannel _channel =
      MethodChannel('com.wherelog/incoming_gpx');

  static Future<String?> takePendingGpxContent() async {
    try {
      return await _channel.invokeMethod<String>('takePendingGpx');
    } catch (_) {
      return null;
    }
  }

  /// The Share Extension's native .gpx hand-off (2026-11-11):
  /// the extension copies a shared .gpx into the App Group
  /// container and records it; the app takes the content here.
  /// Returns null when no shared file is waiting.
  static Future<String?> takePendingSharedGpxContent() async {
    try {
      return await _channel.invokeMethod<String>('takePendingSharedGpx');
    } catch (_) {
      return null;
    }
  }

  /// A non-.gpx file the Share Extension recorded (2026-11-11):
  /// only its filename — the app turns it into a rejected queue
  /// entry. Returns null when no rejected file is waiting.
  static Future<String?> takePendingSharedRejected() async {
    try {
      return await _channel.invokeMethod<String>('takePendingSharedRejected');
    } catch (_) {
      return null;
    }
  }

  /// A non-.gpx file opened into WhereLog ("Open with", 2026-11-11):
  /// only its filename. Returns null when none is waiting.
  static Future<String?> takePendingRejected() async {
    try {
      return await _channel.invokeMethod<String>('takePendingRejected');
    } catch (_) {
      return null;
    }
  }

  static Future<void> Function(String content)? _gpxHandler;
  static Future<void> Function(String filename)? _rejectedHandler;
  static bool _handlerInstalled = false;

  static void _ensureHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'gpxAvailable' && call.arguments is String) {
        final h = _gpxHandler;
        if (h != null) await h(call.arguments as String);
      } else if (call.method == 'rejectedAvailable' &&
          call.arguments is String) {
        final h = _rejectedHandler;
        if (h != null) await h(call.arguments as String);
      }
    });
  }

  static void setAvailabilityHandler(
    Future<void> Function(String content) handler,
  ) {
    _gpxHandler = handler;
    _ensureHandler();
  }

  /// Called when a non-.gpx file arrives while the app is running.
  static void setRejectedHandler(
    Future<void> Function(String filename) handler,
  ) {
    _rejectedHandler = handler;
    _ensureHandler();
  }
}
