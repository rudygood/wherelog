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

  /// Diagnostic: a plain-text description of what the
  /// clipboard currently claims to hold (label, MIME types,
  /// and the shape of each item — link, text, HTML, intent),
  /// without reading any image content. Exists to learn how
  /// other apps package a copied image when [hasImage] does
  /// not recognise the wrapper.
  static Future<String> describeClip() async {
    try {
      final String? s = await _channel.invokeMethod<String>('describeClip');
      return s ?? 'No description returned';
    } catch (e) {
      return 'Clipboard description unavailable: $e';
    }
  }
}
