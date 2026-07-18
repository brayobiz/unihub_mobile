import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'notification_service.dart';
import '../features/auth/shared/providers.dart';

final downloadServiceProvider = Provider((ref) => DownloadService(ref));

class DownloadService {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
    sendTimeout: const Duration(seconds: 30),
  ));

  DownloadService(this._ref);

  Future<String> getSavePath(String fileName) async {
    Directory? directory = await getApplicationDocumentsDirectory();
    final studyDir = Directory(p.join(directory.path, 'study_vault'));
    if (!await studyDir.exists()) {
      await studyDir.create(recursive: true);
    }
    return p.join(studyDir.path, fileName);
  }

  Future<bool> isFileDownloaded(String fileName) async {
    final path = await getSavePath(fileName);
    final file = File(path);
    return file.existsSync() && file.lengthSync() > 0;
  }

  Future<void> downloadFile({
    required String url,
    required String fileName,
    required String noteId,
  }) async {
    final savePath = await getSavePath(fileName);
    final tempPath = '$savePath.tmp';
    
    // Note: No storage permission required for getApplicationDocumentsDirectory() on Android

    try {
      final notificationId = noteId.hashCode;
      final Map<String, dynamic> headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };
      
      if (!url.contains('cloudinary.com')) {
        final currentUser = _ref.read(firebaseAuthProvider).currentUser;
        if (currentUser != null) {
          final token = await currentUser.getIdToken();
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
        }
      }

      await _dio.download(
        url,
        tempPath,
        options: Options(
          headers: headers,
          followRedirects: true,
          validateStatus: (status) => status != null && status < 400,
        ),
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = ((received / total) * 100).toInt();
            _ref.read(notificationServiceProvider).showDownloadNotification(
                  id: notificationId,
                  title: fileName,
                  progress: progress,
                );
          }
        },
      );

      final downloadedFile = File(tempPath);
      if (await downloadedFile.exists()) {
        if (await downloadedFile.length() < 100) {
          throw Exception('Downloaded material is too small to be valid.');
        }
        
        final targetFile = File(savePath);
        if (await targetFile.exists()) await targetFile.delete();
        await downloadedFile.rename(savePath);
      } else {
        throw Exception('Download failed - temporary file not found.');
      }

      await _ref.read(notificationServiceProvider).showDownloadNotification(
            id: notificationId,
            title: fileName,
            progress: 100,
            isDone: true,
            filePath: savePath,
          );
    } catch (e) {
      final f = File(tempPath);
      if (await f.exists()) await f.delete();
      rethrow;
    }
  }
}
