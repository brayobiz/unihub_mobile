import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import 'package:unihub_mobile/core/error/error_handler.dart';
import '../../domain/models/organizer.dart';
import '../../domain/models/organizer_member.dart';
import '../../domain/repositories/organizer_repository.dart';

class OrganizerRepositoryImpl implements OrganizerRepository {
  final FirebaseFirestore _firestore;

  OrganizerRepositoryImpl(this._firestore);

  @override
  Future<Organizer?> getOrganizerById(String id) async {
    if (id.isEmpty) return null;
    final doc = await _firestore.collection('organizers').doc(id).get();
    if (!doc.exists) return null;
    return Organizer.fromFirestore(doc);
  }

  @override
  Stream<Organizer?> watchOrganizerById(String id) {
    if (id.isEmpty) return Stream.value(null);
    return _firestore.collection('organizers').doc(id).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Organizer.fromFirestore(doc);
    });
  }

  @override
  Future<List<Organizer>> getOrganizersByCampus(String campusId, {int limit = 20}) async {
    final snapshot = await _firestore.collection('organizers')
        .where('campusId', isEqualTo: campusId)
        .where('isDeleted', isEqualTo: false)
        .orderBy('trustScore', descending: true)
        .limit(limit)
        .get();
    
    return snapshot.docs.map((doc) => Organizer.fromFirestore(doc)).toList();
  }

  @override
  Stream<List<Organizer>> watchUserManagedOrganizers(String userId) {
    // We combine two sources to ensure reliability:
    // 1. Organizers owned by the user (direct collection query, no complex index needed)
    // 2. Organizers where the user is a member (collection group query, requires index)
    
    final ownedStream = _firestore.collection('organizers')
        .where('ownerId', isEqualTo: userId)
        .where('isDeleted', isEqualTo: false)
        .snapshots();

    final membershipStream = _firestore.collectionGroup('members')
        .where('userId', isEqualTo: userId)
        .snapshots();

    return Rx.combineLatest2<QuerySnapshot, QuerySnapshot, List<String>>(
      ownedStream,
      membershipStream,
      (ownedSnap, memberSnap) {
        final Set<String> ids = {};
        for (var doc in ownedSnap.docs) {
          ids.add(doc.id);
        }
        for (var doc in memberSnap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final orgId = data['organizerId'] as String?;
          if (orgId != null && orgId.isNotEmpty) {
            ids.add(orgId);
          }
        }
        return ids.toList();
      },
    ).asyncMap((ids) async {
      if (ids.isEmpty) return [];
      return _getOrganizersByIds(ids);
    });
  }

  Future<List<Organizer>> _getOrganizersByIds(List<String> ids) async {
    final List<Organizer> results = [];
    // Firestore whereIn is limited to 30 items
    for (var i = 0; i < ids.length; i += 30) {
      final chunk = ids.sublist(i, i + 30 > ids.length ? ids.length : i + 30);
      final snapshot = await _firestore.collection('organizers')
          .where(FieldPath.documentId, whereIn: chunk)
          .get();
      results.addAll(snapshot.docs.map((doc) => Organizer.fromFirestore(doc)));
    }
    return results;
  }

  @override
  Future<void> createOrganizer(Organizer organizer) async {
    try {
      final batch = _firestore.batch();
      final organizerRef = _firestore.collection('organizers').doc(organizer.id);
      
      batch.set(organizerRef, organizer.toFirestore());
      
      // Add owner as a member
      final memberId = '${organizer.id}_${organizer.ownerId}';
      final memberRef = organizerRef.collection('members').doc(memberId);
      
      // Fetch user details to create a complete member record
      final userDoc = await _firestore.collection('users').doc(organizer.ownerId).get();
      final userData = userDoc.data();
      final userName = userData?['fullName'] ?? 'Organizer Owner';
      final userPhotoUrl = userData?['photoUrl'];

      final member = OrganizerMember(
        id: memberId,
        organizerId: organizer.id,
        userId: organizer.ownerId,
        userName: userName,
        userPhotoUrl: userPhotoUrl,
        role: OrganizerRole.owner,
        joinedAt: DateTime.now(),
      );
      
      batch.set(memberRef, member.toFirestore());
      
      await batch.commit();
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> updateOrganizer(Organizer organizer) async {
    try {
      await _firestore.collection('organizers').doc(organizer.id).update(organizer.toFirestore());
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<void> deleteOrganizer(String id) async {
    try {
      await _firestore.collection('organizers').doc(id).update({
        'isDeleted': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw Exception(AppErrorHandler.mapError(e));
    }
  }

  @override
  Future<List<OrganizerMember>> getOrganizerMembers(String organizerId) async {
    // DEFENSIVE: Validate organizerId
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }

    final snapshot = await _firestore.collection('organizers').doc(organizerId).collection('members').get();
    return snapshot.docs.map((doc) => OrganizerMember.fromFirestore(doc)).toList();
  }

  @override
  Stream<List<OrganizerMember>> watchOrganizerMembers(String organizerId) {
    // DEFENSIVE: Validate organizerId
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      return Stream.error(Exception('Invalid organizerId: cannot be empty'));
    }

    return _firestore.collection('organizers').doc(organizerId).collection('members')
        .snapshots()
        .map((s) => s.docs.map((d) => OrganizerMember.fromFirestore(d)).toList());
  }

  @override
  Future<OrganizerMember?> getMember(String organizerId, String userId) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final doc = await _firestore.collection('organizers').doc(organizerId).collection('members').doc('${organizerId}_$userId').get();
    if (!doc.exists) return null;
    return OrganizerMember.fromFirestore(doc);
  }

  @override
  Future<void> addMember(OrganizerMember member) async {
    // DEFENSIVE: Validate member data
    if (member.organizerId.isEmpty) {
      throw Exception('Member organizerId cannot be empty');
    }
    if (member.userId.isEmpty) {
      throw Exception('Member userId cannot be empty');
    }
    if (member.id.isEmpty) {
      throw Exception('Member id cannot be empty');
    }

    await _firestore.collection('organizers')
        .doc(member.organizerId)
        .collection('members')
        .doc(member.id)
        .set(member.toFirestore());
  }

  @override
  Future<void> updateMemberRole(String organizerId, String userId, OrganizerRole newRole) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final memberId = '${organizerId}_$userId';
    await _firestore.collection('organizers')
        .doc(organizerId)
        .collection('members')
        .doc(memberId)
        .update({'role': newRole.name});
  }

  @override
  Future<void> removeMember(String organizerId, String userId) async {
    // DEFENSIVE: Validate parameters
    if (organizerId.isEmpty || organizerId.trim().isEmpty) {
      throw Exception('Invalid organizerId: cannot be empty');
    }
    if (userId.isEmpty || userId.trim().isEmpty) {
      throw Exception('Invalid userId: cannot be empty');
    }

    final memberId = '${organizerId}_$userId';
    await _firestore.collection('organizers')
        .doc(organizerId)
        .collection('members')
        .doc(memberId)
        .delete();
  }

  @override
  Future<void> requestVerification(
    String organizerId, 
    Map<String, dynamic> applicationData, {
    OrganizerVerificationStatus status = OrganizerVerificationStatus.submitted,
  }) async {
    final batch = _firestore.batch();
    
    final requestRef = _firestore.collection('organizer_verification_requests').doc();
    final organizerRef = _firestore.collection('organizers').doc(organizerId);

    final Map<String, dynamic> data = {
      'organizerId': organizerId,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
      ...applicationData,
    };
    
    batch.set(requestRef, data);
    
    batch.update(organizerRef, {
      'verificationStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
  }

  @override
  Future<void> updateTrustScore(String organizerId, double delta) async {
    await _firestore.collection('organizers').doc(organizerId).update({
      'trustScore': FieldValue.increment(delta),
    });
  }

  @override
  Future<void> toggleFollowOrganizer(String userId, String organizerId) async {
    final followRef = _firestore.collection('users').doc(userId).collection('followed_organizers').doc(organizerId);
    final doc = await followRef.get();
    
    final batch = _firestore.batch();
    if (doc.exists) {
      batch.delete(followRef);
      batch.update(_firestore.collection('organizers').doc(organizerId), {
        'followerCount': FieldValue.increment(-1),
      });
    } else {
      batch.set(followRef, {'followedAt': FieldValue.serverTimestamp()});
      batch.update(_firestore.collection('organizers').doc(organizerId), {
        'followerCount': FieldValue.increment(1),
      });
    }
    await batch.commit();
  }

  @override
  Future<void> incrementShareCount(String organizerId) async {
    if (organizerId.isEmpty) return;
    await _firestore.collection('organizers').doc(organizerId).update({
      'sharesCount': FieldValue.increment(1),
    });
  }

  @override
  Stream<bool> isFollowingOrganizer(String userId, String organizerId) {
    if (userId.isEmpty) return Stream.value(false);
    return _firestore.collection('users').doc(userId).collection('followed_organizers').doc(organizerId)
        .snapshots()
        .map((doc) => doc.exists);
  }

  @override
  Stream<List<Organizer>> watchFollowedOrganizers(String userId) {
    if (userId.isEmpty) return Stream.value([]);
    return _firestore.collection('users').doc(userId).collection('followed_organizers')
        .snapshots()
        .asyncMap((snapshot) async {
          final ids = snapshot.docs.map((doc) => doc.id).toList();
          if (ids.isEmpty) return [];
          
          return _getOrganizersByIds(ids);
        });
  }
}
