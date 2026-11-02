import 'dart:typed_data';
import 'package:flutter/services.dart';

class ClipboardImageService {
  static const MethodChannel _channel = MethodChannel('com.wherelog/clipboard_image');

  static Future<bool> hasImage() async {
    try {
      final bool? has = await _channel.invokeMethod<bool>('hasImage');
      return has ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<Uint8List?> getImageBytes() async {
    try {
      final Uint8List? bytes = await _channel.invokeMethod<Uint8List>('getImage');
      return bytes;
    } catch (_) {
      return null;
    }
  }
}
