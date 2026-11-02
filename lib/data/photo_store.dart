import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// The one place that knows where item photos live on disk:
/// `<app documents>/WhereLog/photos/<filename>`.
///
/// Picking, copying and compressing a new photo already happens inside
/// PhotoDetailsSection, which drops the file into this same folder. What
/// lives here is the other half: turning the filename stored in the
/// database back into a file, and deleting a photo file when its item is
/// deleted (or its photo is removed/replaced on save) so files are never
/// left orphaned.
class PhotoStore {
  PhotoStore._();

  static Future<Directory> photosDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final photos = Directory(p.join(dir.path, 'WhereLog', 'photos'));
    if (!await photos.exists()) await photos.create(recursive: true);
    return photos;
  }

  static Future<File> fileFor(String filename) async {
    final dir = await photosDir();
    return File(p.join(dir.path, filename));
  }

  static Future<String> pathFor(String filename) async => (await fileFor(filename)).path;

  /// Deletes the named photo file if it exists. Tolerant by design:
  /// a missing file is not an error (a replaced photo may already have
  /// been removed by the picker).
  static Future<void> deletePhoto(String? filename) async {
    if (kIsWeb) return;
    if (filename == null || filename.isEmpty) return;
    try {
      final f = await fileFor(filename);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  /// The database stores filenames, screens hold full paths — this is
  /// the conversion at that boundary.
  static String? filenameOf(String? path) {
    if (path == null || path.isEmpty) return null;
    return p.basename(path);
  }
}
