import 'dart:io';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class ImageUtils {
  static Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final path = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');
    
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      path,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    return File(result!.path);
  }
}
