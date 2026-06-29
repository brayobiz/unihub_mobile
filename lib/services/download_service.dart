import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as p;
import 'notification_service.dart';

final downloadServiceProvider = Provider((ref) => DownloadService(ref));

class DownloadService {
  final Ref _ref;
  final Dio _dio = Dio();

  DownloadService(this._ref);

  Future<String> getSavePath(String fileName) async {
    Directory? directory;
    if (Platform.isAndroid) {
      // Use internal storage to avoid permission issues and ensure accessibility for renderers
      directory = await getApplicationDocumentsDirectory();
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
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
    debugPrint('☁️ DownloadService: Starting download for $fileName');
    debugPrint('☁️ DownloadService: URL: $url');
    
    final savePath = await getSavePath(fileName);
    final tempPath = '$savePath.tmp';
    
    debugPrint('☁️ DownloadService: Target Save Path: $savePath');
    
    // 1. Request Permission
    if (Platform.isAndroid) {
      debugPrint('☁️ DownloadService: Requesting storage permissions');
      await Permission.storage.request();
    }

    try {
      final notificationId = noteId.hashCode;
      final tempFile = File(tempPath);
      if (!await tempFile.parent.exists()) {
        debugPrint('☁️ DownloadService: Creating parent directories');
        await tempFile.parent.create(recursive: true);
      }

      // 2. Prepare Headers
      final Map<String, dynamic> headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36',
      };
      final isCloudinary = url.contains('cloudinary.com');
      
      if (!isCloudinary) {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          debugPrint('☁️ DownloadService: Attaching Firebase Auth Token');
          final token = await currentUser.getIdToken();
          if (token != null) {
            headers['Authorization'] = 'Bearer $token';
          }
        }
      } else {
        debugPrint('☁️ DownloadService: Cloudinary detected, using browser user-agent only');
      }

      // 3. Start Download to temp file
      debugPrint('☁️ DownloadService: Initiating Dio download to temp file');
      debugPrint('☁️ DownloadService: Headers: $headers');
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

      // 4. Validate file content (simple check)
      final downloadedFile = File(tempPath);
      if (await downloadedFile.exists()) {
        final bytes = await downloadedFile.length();
        debugPrint('☁️ DownloadService: Downloaded file size: $bytes bytes');
        
        if (bytes < 100) {
          debugPrint('☁️ DownloadService: ERROR - File too small');
          throw Exception('Downloaded material is too small to be valid.');
        }
        
        // Success: Rename temp to actual
        if (await File(savePath).exists()) {
          debugPrint('☁️ DownloadService: Deleting existing file at save path');
          await File(savePath).delete();
        }
        debugPrint('☁️ DownloadService: Renaming temp file to final path');
        await downloadedFile.rename(savePath);
      } else {
        debugPrint('☁️ DownloadService: ERROR - Temp file does not exist after download');
        throw Exception('Download failed - temporary file not found.');
      }

      // 5. Show completion
      debugPrint('☁️ DownloadService: Download success. Showing completion notification');
      await _ref.read(notificationServiceProvider).showDownloadNotification(
            id: notificationId,
            title: fileName,
            progress: 100,
            isDone: true,
            filePath: savePath,
          );
    } on DioException catch (e) {
      debugPrint('☁️ DownloadService: Dio Error: ${e.type} - ${e.message}');
      debugPrint('☁️ DownloadService: Dio Response Status: ${e.response?.statusCode}');
      debugPrint('☁️ DownloadService: Dio Response Data: ${e.response?.data}');
      if (e.response?.statusCode == 401) {
        throw Exception('Access Denied (401) from Storage Provider. The resource might be restricted.');
      }
      throw Exception('Download failed: ${e.message}');
    } catch (e, stack) {
      debugPrint('☁️ DownloadService: Unexpected Error: $e');
      debugPrint('☁️ DownloadService: StackTrace: $stack');
      // Cleanup temp file on failure
      final f = File(tempPath);
      if (await f.exists()) await f.delete();
      rethrow;
    }
  }
}
