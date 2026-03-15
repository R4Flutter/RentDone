import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';

class CloudinaryFilePreparer {
  static Future<File> prepare(File originalFile, String fileName) async {
    final extension = fileName.toLowerCase();
    final isImage =
        extension.endsWith('.jpg') ||
        extension.endsWith('.jpeg') ||
        extension.endsWith('.png') ||
        extension.endsWith('.webp');
    if (!isImage) return originalFile;

    final compressed = await FlutterImageCompress.compressAndGetFile(
      originalFile.absolute.path,
      '${originalFile.absolute.path}_compressed.jpg',
      quality: 75,
      minWidth: 1440,
      minHeight: 1440,
    );
    return compressed == null ? originalFile : File(compressed.path);
  }
}
