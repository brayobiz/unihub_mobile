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
  Future<NoteListing?> getNoteById(String noteId);

  // Study Experience
  Future<void> updateStudyProgress(StudyProgress progress);
  Stream<StudyProgress?> watchNoteProgress(String userId, String noteId);
  Stream<List<StudyProgress>> watchStudyHistory(String userId);
  Stream<List<StudyProgress>> watchBookmarks(String userId);
}
