import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/note.dart';
import '../../domain/models/study_progress.dart';
import '../../domain/repositories/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  final FirebaseFirestore _firestore;

  NotesRepositoryImpl(this._firestore);

  @override
  Stream<List<NoteListing>> watchNotes({
    String? university,
    String? subjectCategory,
    String? noteType,
    String? yearOfStudy,
    String? query,
    int? limit,
  }) {
    Query queryRef = _firestore.collection('notes')
        .orderBy('createdAt', descending: true);

    if (subjectCategory != null && subjectCategory != 'All') {
      queryRef = queryRef.where('subjectCategory', isEqualTo: subjectCategory);
    }

    if (noteType != null && noteType != 'All') {
      queryRef = queryRef.where('noteType', isEqualTo: noteType);
    }

    if (limit != null) {
      queryRef = queryRef.limit(limit);
    }

    return queryRef.snapshots().map((snapshot) {
      var items = snapshot.docs
          .map((doc) => NoteListing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();
      
      if (university != null) {
        items = items.where((n) => n.university == university).toList();
      }

      if (yearOfStudy != null && yearOfStudy != 'All') {
        items = items.where((n) => n.yearOfStudy == yearOfStudy).toList();
      }

      if (query != null && query.isNotEmpty) {
        final q = query.toLowerCase();
        items = items.where((note) {
          return note.title.toLowerCase().contains(q) || 
                 note.tags.any((tag) => tag.toLowerCase().contains(q)) ||
                 note.unitCode.toLowerCase().contains(q);
        }).toList();
      }

      return items;
    });
  }

  @override
  Future<List<NoteListing>> getNotes({
    String? subjectCategory,
    String? noteType,
    String? yearOfStudy,
    String? query,
    int limit = 20,
    NoteListing? startAfter,
  }) async {
    Query queryRef = _firestore.collection('notes')
        .orderBy('createdAt', descending: true)
        .limit(limit);

    if (startAfter != null) {
      final doc = await _firestore.collection('notes').doc(startAfter.id).get();
      if (doc.exists) {
        queryRef = queryRef.startAfterDocument(doc);
      }
    }

    final snapshot = await queryRef.get(const GetOptions(source: Source.serverAndCache));
    var items = snapshot.docs.map((doc) => NoteListing.fromJson(doc.data() as Map<String, dynamic>)).toList();

    // Secondary filtering
    if (subjectCategory != null && subjectCategory != 'All') items = items.where((n) => n.subjectCategory == subjectCategory).toList();
    if (noteType != null && noteType != 'All') items = items.where((n) => n.noteType == noteType).toList();
    if (yearOfStudy != null && yearOfStudy != 'All') items = items.where((n) => n.yearOfStudy == yearOfStudy).toList();

    return items;
  }

  @override
  Future<void> createNote(NoteListing note) async {
    debugPrint('📝 Firestore: Creating note ${note.id}');
    debugPrint('📝 Firestore: File URL: ${note.fileUrl}');
    try {
      await _firestore.collection('notes').doc(note.id).set(note.toJson());
      debugPrint('✅ Firestore: Note created successfully');
    } catch (e) {
      debugPrint('❌ Firestore: Failed to create note: $e');
      rethrow;
    }
  }

  @override
  Future<NoteListing?> getNoteById(String noteId) async {
    final doc = await _firestore.collection('notes').doc(noteId).get();
    if (!doc.exists) return null;
    return NoteListing.fromJson(doc.data()!);
  }

  @override
  Future<void> updateStudyProgress(StudyProgress progress) async {
    await _firestore
        .collection('users')
        .doc(progress.userId)
        .collection('study_progress')
        .doc(progress.noteId)
        .set(progress.toJson(), SetOptions(merge: true));
  }

  @override
  Stream<StudyProgress?> watchNoteProgress(String userId, String noteId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('study_progress')
        .doc(noteId)
        .snapshots()
        .map((doc) => doc.exists ? StudyProgress.fromJson(doc.data()!) : null);
  }

  @override
  Stream<List<StudyProgress>> watchStudyHistory(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('study_progress')
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => StudyProgress.fromJson(doc.data()))
              .toList();
          items.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
          return items.take(15).toList();
        });
  }

  @override
  Stream<List<StudyProgress>> watchBookmarks(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('study_progress')
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => StudyProgress.fromJson(doc.data()))
              .where((p) => p.isBookmarked)
              .toList();
          items.sort((a, b) => b.lastAccessed.compareTo(a.lastAccessed));
          return items;
        });
  }
}
