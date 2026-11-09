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

  static void setAvailabilityHandler(
    Future<void> Function(String content) handler,
  ) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'gpxAvailable' && call.arguments is String) {
        await handler(call.arguments as String);
      }
    });
  }
}
