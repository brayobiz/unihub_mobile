import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../services/cloudinary_service.dart';

final storageRepositoryProvider = Provider((ref) => StorageRepository(ref.watch(cloudinaryServiceProvider)));

class StorageRepository {
  final CloudinaryService _cloudinaryService;
  StorageRepository(this._cloudinaryService);

  Future<String> uploadFile({
    required String path,
    required String id,
    required File file,
    Function(int, int)? onProgress,
  }) async {
    // We map Firebase style path/id to Cloudinary folder structure
    final folder = path.replaceAll('/', '_');
    
    debugPrint('📦 StorageRepo: Prepared folder name: $folder');
    
    return await _cloudinaryService.uploadFile(
      file: file,
      folder: folder,
      publicId: id,
      onProgress: onProgress,
    );
  }

  /// Optional: method for multiple uploads if needed specifically
  Future<List<String>> uploadMultipleFiles({
    required String path,
    required List<File> files,
  }) async {
    final folder = path.replaceAll('/', '_');
    return await _cloudinaryService.uploadMultipleFiles(
      files: files,
      folder: folder,
    );
  }

  String getThumbnail(String url) {
    return _cloudinaryService.getThumbnailUrl(url);
  }
}
