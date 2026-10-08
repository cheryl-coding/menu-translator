import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;

class ImageService {
  // ==================================================
  // NORMALIZE IMAGE ORIENTATION
  // ==================================================
  Future<File> normalizeOrientation(File file) async {
    try {
      final bytes = await file.readAsBytes();

      final decoded = img.decodeImage(bytes);

      if (decoded == null) {
        return file;
      }

      final oriented = img.bakeOrientation(decoded);

      final outputPath =
          '${file.parent.path}/normalized'
          '_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final outputFile = File(outputPath);

      await outputFile.writeAsBytes(img.encodeJpg(oriented, quality: 95));

      return outputFile;
    } catch (e) {
      debugPrint('Image orientation error: $e');

      return file;
    }
  }

  // ==================================================
  // IMAGE SIZE
  // ==================================================

  Future<Size> getImageSize(File file) async {
    final bytes = await file.readAsBytes();

    final decoded = img.decodeImage(bytes);

    if (decoded == null) {
      throw Exception('Could not decode image');
    }

    return Size(decoded.width.toDouble(), decoded.height.toDouble());
  }
}
