import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/notes_repository_impl.dart';
import '../domain/models/note.dart';
import '../domain/models/study_progress.dart';
import '../domain/repositories/notes_repository.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(
    ref.watch(firestoreProvider),
  );
});

// Search and Filter States
final notesSearchQueryProvider = StateProvider<String>((ref) => '');
final notesCategoryFilterProvider = StateProvider<String>((ref) => 'All');
final notesTypeFilterProvider = StateProvider<String>((ref) => 'All');
final notesYearFilterProvider = StateProvider<String>((ref) => 'All');
final notesUniversityFilterProvider = StateProvider<String?>((ref) => null);
final notesCourseFilterProvider = StateProvider<String>((ref) => 'All');

final notesListingsProvider = StreamProvider.family<List<NoteListing>, int>((ref, limit) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final query = ref.watch(notesSearchQueryProvider);
  final category = ref.watch(notesCategoryFilterProvider);
  final type = ref.watch(notesTypeFilterProvider);
  final year = ref.watch(notesYearFilterProvider);
  final selectedUni = ref.watch(notesUniversityFilterProvider);

  return ref.watch(notesRepositoryProvider).watchNotes(
    university: selectedUni ?? user?.university,
    subjectCategory: category,
    noteType: type,
    yearOfStudy: year,
    query: query,
    limit: limit,
  );
});

final topNotesProvider = StreamProvider<List<NoteListing>>((ref) {
  return ref.watch(notesListingsProvider(40).stream);
});

final trendingNotesProvider = StreamProvider<List<NoteListing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  // In a real app, the repository would handle "trending" logic
  // For now, we'll fetch notes with a higher limit and sort by downloads in UI if needed,
  // or assume watchNotes supports some sorting (though not in the current interface).
  // We'll just use the watchNotes with a limit for now.
  return ref.watch(notesRepositoryProvider).watchNotes(
    university: user?.university,
    limit: 10,
  );
});

final recentNotesProvider = StreamProvider<List<NoteListing>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  return ref.watch(notesRepositoryProvider).watchNotes(
    university: user?.university,
    limit: 10,
  );
});

final userNotesProvider = StreamProvider<List<NoteListing>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchNotesByAuthor(user.uid);
});

// Study Specific Providers
final studyHistoryProvider = StreamProvider<List<StudyProgress>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchStudyHistory(user.uid);
});

final bookmarksProvider = StreamProvider<List<StudyProgress>>((ref) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(notesRepositoryProvider).watchBookmarks(user.uid);
});

// Derived Library Providers
final continueReadingProvider = Provider<AsyncValue<List<StudyProgress>>>((ref) {
  final historyAsync = ref.watch(studyHistoryProvider);
  return historyAsync.whenData((history) => 
    history.where((p) => p.progress > 0 && p.progress < 0.95).toList()
  );
});

final recentlyOpenedProvider = Provider<AsyncValue<List<StudyProgress>>>((ref) {
  final historyAsync = ref.watch(studyHistoryProvider);
  return historyAsync.whenData((history) => 
    history.take(10).toList()
  );
});

final noteProgressProvider = StreamProvider.family<StudyProgress?, String>((ref, noteId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(notesRepositoryProvider).watchNoteProgress(user.uid, noteId);
});

// Helper provider to resolve NoteListing from StudyProgress
final noteByIdProvider = FutureProvider.family<NoteListing?, String>((ref, noteId) {
  return ref.watch(notesRepositoryProvider).getNoteById(noteId);
});

// Study Experience Controller
final studyControllerProvider = Provider((ref) => StudyController(ref));

class StudyController {
  final Ref _ref;
  StudyController(this._ref);

  Future<void> markAsOpened(String noteId) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final existing = await _ref.read(notesRepositoryProvider).watchNoteProgress(user.uid, noteId).first;
    
    final progress = existing?.copyWith(lastAccessed: DateTime.now()) ?? 
      StudyProgress(
        noteId: noteId,
        userId: user.uid,
        lastAccessed: DateTime.now(),
      );
    
    await _ref.read(notesRepositoryProvider).updateStudyProgress(progress);
  }

  Future<void> updateProgress(String noteId, {int? page, int? total, double? progress}) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final existing = await _ref.read(notesRepositoryProvider).watchNoteProgress(user.uid, noteId).first;
    if (existing == null) return;

    final updated = existing.copyWith(
      lastPage: page,
      totalPages: total,
      progress: progress,
      lastAccessed: DateTime.now(),
    );

    await _ref.read(notesRepositoryProvider).updateStudyProgress(updated);
  }

  Future<void> removeFromHistory(String noteId) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    await _ref.read(notesRepositoryProvider).deleteStudyProgress(user.uid, noteId);
  }

  Future<void> clearHistory() async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;
    
    // For simplicity, we can fetch and delete, or just implement a more robust 
    // clear in the repository. Let's do a simple clear for now.
    final history = await _ref.read(notesRepositoryProvider).watchStudyHistory(user.uid).first;
    for (var item in history) {
      await _ref.read(notesRepositoryProvider).deleteStudyProgress(user.uid, item.noteId);
    }
  }

  Future<void> toggleBookmark(String noteId) async {
    final user = _ref.read(authStateProvider).valueOrNull;
    if (user == null) return;

    final existing = await _ref.read(notesRepositoryProvider).watchNoteProgress(user.uid, noteId).first;
    
    final progress = existing?.copyWith(
      isBookmarked: !(existing.isBookmarked),
      lastAccessed: DateTime.now(),
    ) ?? StudyProgress(
      noteId: noteId,
      userId: user.uid,
      isBookmarked: true,
      lastAccessed: DateTime.now(),
    );

    await _ref.read(notesRepositoryProvider).updateStudyProgress(progress);
  }
}
