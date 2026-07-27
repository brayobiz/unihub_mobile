import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/notes/domain/models/note.dart';
import 'package:unihub_mobile/features/notes/shared/providers.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/shared/storage_repository.dart';

class NoteUploadState {
  final AsyncValue<void> status;
  final double uploadProgress;

  NoteUploadState({
    this.status = const AsyncValue.data(null),
    this.uploadProgress = 0,
  });

  NoteUploadState copyWith({
    AsyncValue<void>? status,
    double? uploadProgress,
  }) {
    return NoteUploadState(
      status: status ?? this.status,
      uploadProgress: uploadProgress ?? this.uploadProgress,
    );
  }
}

class NoteUploadController extends StateNotifier<NoteUploadState> {
  final Ref _ref;

  NoteUploadController(this._ref) : super(NoteUploadState());

  Future<bool> uploadNote({
    required NoteListing baseNote,
    File? selectedFile,
  }) async {
    state = state.copyWith(status: const AsyncValue.loading(), uploadProgress: 0);

    final result = await AsyncValue.guard(() async {
      final user = _ref.read(appUserProvider).valueOrNull;
      if (user == null) throw Exception('User not authenticated');

      String fileUrl = baseNote.fileUrl;
      
      if (selectedFile != null) {
        fileUrl = await _ref.read(storageRepositoryProvider).uploadFile(
          path: 'notes/${baseNote.id}',
          id: 'document',
          file: selectedFile,
          onProgress: (sent, total) {
            state = state.copyWith(uploadProgress: sent / total);
          },
        );
      }

      final finalNote = baseNote.copyWith(
        fileUrl: fileUrl,
        authorId: user.uid,
        authorName: user.fullName,
        university: user.university ?? 'Unknown',
      );

      await _ref.read(notesRepositoryProvider).createNote(finalNote);
    });

    state = state.copyWith(status: result);
    return !result.hasError;
  }
}

final noteUploadControllerProvider = StateNotifierProvider<NoteUploadController, NoteUploadState>((ref) {
  return NoteUploadController(ref);
});
