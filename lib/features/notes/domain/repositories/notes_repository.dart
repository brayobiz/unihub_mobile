import '../models/note.dart';
import '../models/study_progress.dart';

abstract class NotesRepository {
  Stream<List<NoteListing>> watchNotes({
    String? university,
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
  Stream<List<NoteListing>> watchNotesByAuthor(String authorId);

  // Study Experience
  Future<void> updateStudyProgress(StudyProgress progress);
  Future<void> deleteStudyProgress(String userId, String noteId);
  Stream<StudyProgress?> watchNoteProgress(String userId, String noteId);
  Stream<List<StudyProgress>> watchStudyHistory(String userId);
  Stream<List<StudyProgress>> watchBookmarks(String userId);
}
