import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rxdart/rxdart.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/notes_repository_impl.dart';
import '../domain/models/note.dart';
import '../domain/models/study_progress.dart';
import '../domain/repositories/notes_repository.dart';
import 'package:unihub_mobile/core/services/cache_service.dart';

final notesRepositoryProvider = Provider<NotesRepository>((ref) {
  return NotesRepositoryImpl(
    ref.watch(firestoreProvider),
    cacheService: ref.watch(cacheServiceProvider),
  );
});

// Search and Filter States
final notesSearchQueryProvider = StateProvider<String>((ref) => '');
final notesCategoryFilterProvider = StateProvider<String>((ref) => 'All');
final notesTypeFilterProvider = StateProvider<String>((ref) => 'All');
final notesYearFilterProvider = StateProvider<String>((ref) => 'All');

final notesListingsProvider = StreamProvider.family<List<NoteListing>, int>((ref, limit) {
  final user = ref.watch(appUserProvider).valueOrNull;
  final query = ref.watch(notesSearchQueryProvider);
  final category = ref.watch(notesCategoryFilterProvider);
  final type = ref.watch(notesTypeFilterProvider);
  final year = ref.watch(notesYearFilterProvider);
  final cache = ref.watch(cacheServiceProvider);

  final stream = ref.watch(notesRepositoryProvider).watchNotes(
    university: user?.university,
    subjectCategory: category,
    noteType: type,
    yearOfStudy: year,
    query: query,
    limit: limit,
  );

  // Use cache only for initial 'All' load to avoid confusing filtered results
  if (query.isEmpty && category == 'All' && type == 'All' && year == 'All' && limit >= 20) {
    final cachedData = cache.getNotes();
    if (cachedData != null) {
      final cachedNotes = cachedData.map((e) => NoteListing.fromJson(e)).toList();
      return stream.startWith(cachedNotes).distinct();
    }
  }

  return stream;
});

final topNotesProvider = StreamProvider<List<NoteListing>>((ref) {
  return ref.watch(notesListingsProvider(40).stream);
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

final noteProgressProvider = StreamProvider.family<StudyProgress?, String>((ref, noteId) {
  final user = ref.watch(authStateProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  final cache = ref.watch(cacheServiceProvider);
  final stream = ref.watch(notesRepositoryProvider).watchNoteProgress(user.uid, noteId);

  final cached = cache.getStudyProgress(noteId);
  if (cached != null) {
    return stream.startWith(StudyProgress.fromJson(cached)).distinct();
  }

  return stream;
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

    // Optimistic UI/Local Cache
    _ref.read(cacheServiceProvider).saveStudyProgress(noteId, updated.toJson());

    await _ref.read(notesRepositoryProvider).updateStudyProgress(updated);
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
