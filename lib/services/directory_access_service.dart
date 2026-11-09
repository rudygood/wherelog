import 'package:flutter/services.dart';

/// iOS-only bridge to a folder picker that keeps the picked
/// folder's security-scoped access open while Dart writes into
/// it. A path returned by the ordinary file picker is only a
/// string: iOS will not let the app write through it, because
/// the permission lives in the native URL the picker produced,
/// not in the path. The native side therefore presents its own
/// folder picker, starts access on the chosen folder, and holds
/// that access until [releaseDirectory] is called after the
/// write has finished (or failed).
class DirectoryAccessService {
  static const MethodChannel _channel =
      MethodChannel('com.wherelog/directory_access');

  static Future<String?> pickDirectory() async {
    try {
      return await _channel.invokeMethod<String>('pickDirectory');
    } catch (_) {
      return null;
    }
  }

  static Future<void> releaseDirectory() async {
    try {
      await _channel.invokeMethod<void>('releaseDirectory');
    } catch (_) {
      // Releasing is housekeeping; a failure here must not mask
      // the export's own result.
    }
  }
}
