import '../models/note.dart';
import '../models/study_progress.dart';

abstract class NotesRepository {
  Stream<List<NoteListing>> watchNotes({
    String? subjectCategory,
    String? noteType,
    String? yearOfStudy,
    String? query,
    int? limit,
  });

  Future<List<NoteListing>> getNotes({
    String? subjectCategory,
    String? noteType,
    String? yearOfStudy,
    String? query,
    int limit = 20,
    NoteListing? startAfter,
  });

  Future<void> createNote(NoteListing note);
  Future<void> deleteNote(String noteId);
  Future<NoteListing?> getNoteById(String noteId);
  Future<void> incrementShareCount(String noteId);
  Stream<List<NoteListing>> watchNotesByAuthor(String authorId);
  
  Future<void> reportNote({
    required String noteId,
    required String reporterId,
    required String reason,
  });

  // Study Experience
  Future<void> updateStudyProgress(StudyProgress progress);
  Future<void> deleteStudyProgress(String userId, String noteId);
  Stream<StudyProgress?> watchNoteProgress(String userId, String noteId);
  Stream<List<StudyProgress>> watchStudyHistory(String userId);
  Stream<List<StudyProgress>> watchBookmarks(String userId);

  // Moderation & Admin Methods
  Future<void> flagNote({
    required String noteId,
    required String reason,
    String? adminNotes,
  });

  Future<void> approveNote(String noteId);

  Future<void> suspendNote({
    required String noteId,
    required String reason,
    required String adminId,
  });

  Future<void> removeNote({
    required String noteId,
    required String reason,
    required String adminId,
  });

  Stream<List<NoteListing>> watchFlaggedNotes(String campusId);
}
