import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

final cloudinaryServiceProvider = Provider((ref) => CloudinaryService());

class CloudinaryService {
  final _cloudinary = CloudinaryPublic(
    'dawfn244r', // Your Cloud name
    'unihub_uploads', // Your Upload preset
    cache: false,
  );

  /// Compresses an image before upload
  Future<File> compressImage(File file) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(tempDir.path, "${DateTime.now().millisecondsSinceEpoch}.jpg");

    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: 70,
      format: CompressFormat.jpeg,
    );

    if (result == null) return file;
    return File(result.path);
  }

  bool _isImage(String path) {
    final mimeType = p.extension(path).toLowerCase();
    return ['.jpg', '.jpeg', '.png', '.webp', '.heic'].contains(mimeType);
  }

  /// Uploads a single file (image or document) and returns the secure URL
  Future<String> uploadFile({
    required File file,
    required String folder,
    String? publicId,
    bool compress = true,
    Function(int, int)? onProgress,
  }) async {
    final fileName = p.basename(file.path);
    debugPrint('☁️ Cloudinary: Starting upload for $fileName to folder unihub/$folder');
    
    try {
      if (!await file.exists()) {
        throw Exception('File does not exist at path: ${file.path}');
      }

      File fileToUpload = file;
      final isImg = _isImage(file.path);
      
      if (compress && isImg) {
        debugPrint('☁️ Cloudinary: Compressing image before upload...');
        fileToUpload = await compressImage(file);
        debugPrint('☁️ Cloudinary: Compression complete.');
      }

      // Proactive Fix: PDFs should be handled as RAW for guaranteed bit-for-bit retrieval
      // unless we specifically need image-like transformations. For the study reader,
      // we need the original bytes. 
      final isPdf = p.extension(file.path).toLowerCase() == '.pdf';
      final resourceType = isImg 
          ? CloudinaryResourceType.Image 
          : (isPdf ? CloudinaryResourceType.Raw : CloudinaryResourceType.Auto);

      final cloudinaryFile = CloudinaryFile.fromFile(
        fileToUpload.path,
        folder: 'unihub/$folder',
        publicId: publicId,
        resourceType: resourceType,
      );

      debugPrint('☁️ Cloudinary: Requesting upload with resourceType: ${cloudinaryFile.resourceType}');

      CloudinaryResponse response = await _cloudinary.uploadFile(
        cloudinaryFile,
        onProgress: onProgress,
      );
      
      debugPrint('☁️ Cloudinary: Upload successful! URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e, stack) {
      debugPrint('❌ Cloudinary: Upload failed for $fileName');
      debugPrint('Error: $e');
      debugPrint('Stack: $stack');
      throw Exception('Cloudinary upload failed: $e');
    }
  }

  /// Uploads multiple files and returns a list of secure URLs
  Future<List<String>> uploadMultipleFiles({
    required List<File> files,
    required String folder,
  }) async {
    List<String> urls = [];
    for (var file in files) {
      final url = await uploadFile(file: file, folder: folder);
      urls.add(url);
    }
    return urls;
  }

  /// Generates a thumbnail URL for a given image URL
  String getThumbnailUrl(String imageUrl, {int width = 200, int height = 200}) {
    if (!imageUrl.contains('cloudinary.com')) return imageUrl;
    
    // Check if it's an image before applying image transformations
    final ext = p.extension(imageUrl).toLowerCase();
    if (!['.jpg', '.jpeg', '.png', '.webp'].contains(ext)) return imageUrl;

    final parts = imageUrl.split('/upload/');
    if (parts.length != 2) return imageUrl;
    
    return '${parts[0]}/upload/c_thumb,w_$width,h_$height,g_face/${parts[1]}';
  }
}
