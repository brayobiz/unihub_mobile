import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      directory = await getDownloadsDirectory();
      directory ??= Directory('/storage/emulated/0/Download');
    } else {
      directory = await getApplicationDocumentsDirectory();
    }
    return p.join(directory.path, fileName);
  }

  Future<bool> isFileDownloaded(String fileName) async {
    final path = await getSavePath(fileName);
    return File(path).exists();
  }

  Future<void> downloadFile({
    required String url,
    required String fileName,
    required String noteId,
  }) async {
    final savePath = await getSavePath(fileName);
    
    // Check if already exists
    if (await File(savePath).exists()) {
      return;
    }

    // 1. Request Permission
    if (Platform.isAndroid) {
      await Permission.storage.request();
    }

    try {
      final notificationId = noteId.hashCode;
      final file = File(savePath);
      if (!await file.parent.exists()) {
        await file.parent.create(recursive: true);
      }

      // 2. Prepare Headers (Add Auth if available)
      final Map<String, dynamic> headers = {};
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final token = await currentUser.getIdToken();
        if (token != null) {
          headers['Authorization'] = 'Bearer $token';
        }
      }

      // 3. Start Download
      await _dio.download(
        url,
        savePath,
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

      // 4. Show completion
      await _ref.read(notificationServiceProvider).showDownloadNotification(
            id: notificationId,
            title: fileName,
            progress: 100,
            isDone: true,
            filePath: savePath,
          );
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        throw Exception('Access Denied (401). Please try logging in again.');
      }
      throw Exception('Download failed: ${e.message}');
    } catch (e) {
      print('Download error: $e');
      rethrow;
    }
  }
}
