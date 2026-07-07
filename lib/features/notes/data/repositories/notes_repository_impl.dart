import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../../domain/models/note.dart';
import '../../domain/models/study_progress.dart';
import '../../domain/repositories/notes_repository.dart';

class NotesRepositoryImpl implements NotesRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;

  NotesRepositoryImpl(this._firestore, this._browsingCampus);

  @override
  Stream<List<NoteListing>> watchNotes({
    String? subjectCategory,
    String? noteType,
    String? yearOfStudy,
    String? query,
    int? limit,
  }) {
    if (kDebugMode) {
      debugPrint('📖 Firestore: Watching notes. Category: $subjectCategory, Type: $noteType, Global Campus: $_browsingCampus');
    }
    
    Query queryRef = _firestore.collection('notes')
        .where('status', isEqualTo: 'active');

    if (subjectCategory != null && subjectCategory != 'All') {
      queryRef = queryRef.where('subjectCategory', isEqualTo: subjectCategory);
    }

    if (noteType != null && noteType != 'All') {
      queryRef = queryRef.where('noteType', isEqualTo: noteType);
    }

    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      queryRef = queryRef.where('university', isEqualTo: _browsingCampus);
    }

    // REMOVED: queryRef = queryRef.orderBy('createdAt', descending: true);
    // Reason: Avoids "Query requires an index" error when filtering by category/type.
    // Sorting will be done in-memory below.

    return queryRef.snapshots().map((snapshot) {
      if (kDebugMode) {
        debugPrint('📖 Firestore: Received notes snapshot with ${snapshot.docs.length} docs');
      }
      var items = snapshot.docs
          .map((doc) => NoteListing.fromJson(doc.data() as Map<String, dynamic>))
          .toList();

      // 2. Sorting is newest first by default in the list
      
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

      if (limit != null) {
        return items.take(limit).toList();
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
        .where('status', isEqualTo: 'active')
        .orderBy('createdAt', descending: true);

    if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
      queryRef = queryRef.where('university', isEqualTo: _browsingCampus);
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
    if (note.id.isEmpty) throw Exception('Note ID cannot be empty');
    if (kDebugMode) {
      debugPrint('📝 Firestore: Processing note ${note.id}');
    }
    
    final noteRef = _firestore.collection('notes').doc(note.id);
    final doc = await noteRef.get();
    final isNew = !doc.exists;

    final batch = _firestore.batch();
    
    // 1. Create/Update the note
    batch.set(noteRef, note.toJson(), SetOptions(merge: true));
    
    // 2. Increment counters only for NEW notes
    if (isNew && note.authorId.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(note.authorId);
      batch.update(userRef, {
        'resourcesSharedCount': FieldValue.increment(1),
        'trustScore': FieldValue.increment(2.0),
      });
    }

    try {
      await batch.commit();
      if (kDebugMode) {
        debugPrint('✅ Firestore: Note ${isNew ? 'created' : 'updated'} successfully');
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Firestore: Failed to process note: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> deleteNote(String noteId) async {
    final doc = await _firestore.collection('notes').doc(noteId).get();
    if (!doc.exists) return;
    
    final authorId = doc.data()?['authorId'];
    final batch = _firestore.batch();
    
    batch.delete(_firestore.collection('notes').doc(noteId));
    
    if (authorId != null && (authorId as String).isNotEmpty) {
      batch.update(_firestore.collection('users').doc(authorId), {
        'resourcesSharedCount': FieldValue.increment(-1),
      });
    }

    await batch.commit();
  }

  @override
  Stream<List<NoteListing>> watchNotesByAuthor(String authorId) {
    return _firestore
        .collection('notes')
        .where('authorId', isEqualTo: authorId)
        .snapshots()
        .map((snapshot) {
          var items = snapshot.docs
              .map((doc) => NoteListing.fromJson(doc.data()))
              .toList();
          // Sort in-memory to avoid composite index requirement
          items.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  @override
  Future<void> reportNote({
    required String noteId,
    required String reporterId,
    required String reason,
  }) async {
    await _firestore.collection('reports').add({
      'type': 'note',
      'targetId': noteId,
      'reporterId': reporterId,
      'reason': reason,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',
    });
  }

  @override
  Future<NoteListing?> getNoteById(String noteId) async {
    final doc = await _firestore.collection('notes').doc(noteId).get();
    if (!doc.exists) return null;
    return NoteListing.fromJson(doc.data()!);
  }

  @override
  Future<void> incrementShareCount(String noteId) async {
    if (noteId.isEmpty) return;
    await _firestore.collection('notes').doc(noteId).update({
      'sharesCount': FieldValue.increment(1),
    });
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
  Future<void> deleteStudyProgress(String userId, String noteId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('study_progress')
        .doc(noteId)
        .delete();
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

  @override
  Future<void> flagNote({
    required String noteId,
    required String reason,
    String? adminNotes,
  }) async {
    await _firestore.collection('notes').doc(noteId).update({
      'flagged': true,
      'flagReason': reason,
      'flagAdminNotes': adminNotes,
      'flaggedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> approveNote(String noteId) async {
    final noteDoc = await _firestore.collection('notes').doc(noteId).get();
    if (!noteDoc.exists) return;

    await _firestore.collection('notes').doc(noteId).update({
      'status': 'active',
      'flagged': false,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> suspendNote({
    required String noteId,
    required String reason,
    required String adminId,
  }) async {
    final noteDoc = await _firestore.collection('notes').doc(noteId).get();
    if (!noteDoc.exists) return;

    await _firestore.collection('notes').doc(noteId).update({
      'status': 'suspended',
      'suspensionReason': reason,
      'suspendedBy': adminId,
      'suspendedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> removeNote({
    required String noteId,
    required String reason,
    required String adminId,
  }) async {
    final noteDoc = await _firestore.collection('notes').doc(noteId).get();
    if (!noteDoc.exists) return;

    await _firestore.collection('notes').doc(noteId).update({
      'status': 'removed',
      'removalReason': reason,
      'removedBy': adminId,
      'removedAt': FieldValue.serverTimestamp(),
    });

    final authorId = noteDoc.data()?['authorId'];
    if (authorId != null && (authorId as String).isNotEmpty) {
      await _firestore.collection('users').doc(authorId).update({
        'resourcesSharedCount': FieldValue.increment(-1),
      });
    }
  }

  @override
  Stream<List<NoteListing>> watchFlaggedNotes(String campusId) {
    return _firestore
        .collection('notes')
        .where('flagged', isEqualTo: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => NoteListing.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }
}
