import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../domain/models/announcement.dart';

class AnnouncementRepository {
  final FirebaseFirestore _firestore;
  final String? _browsingCampus;

  AnnouncementRepository(this._firestore, [this._browsingCampus]);

  CollectionReference get _collection => _firestore.collection('announcements');

  Stream<List<Announcement>> watchAllAnnouncements() {
    return _collection
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => Announcement.fromJson(doc.data() as Map<String, dynamic>))
            .toList());
  }

  Stream<List<Announcement>> watchActiveAnnouncements() {
    return _collection.snapshots().map((snapshot) {
      // Add 5 minute tolerance for clock skew between device and server
      final now = DateTime.now().add(const Duration(minutes: 5));
      var items = snapshot.docs
          .map((doc) => Announcement.fromJson(doc.data() as Map<String, dynamic>))
          .where((a) {
            final isActiveStatus = a.status == AnnouncementStatus.published || 
                                   a.status == AnnouncementStatus.scheduled;
            final isTimeStarted = a.publishAt.isBefore(now);
            final isNotExpired = a.expiresAt == null || a.expiresAt!.isAfter(DateTime.now());
            
            return isActiveStatus && isTimeStarted && isNotExpired;
          })
          .toList();

      // Apply Global Campus Filter
      if (_browsingCampus != null && _browsingCampus!.isNotEmpty) {
        items = items.where((a) {
          final targetUni = a.targetAudience['university'] as String? ?? 'All';
          if (targetUni == 'All') return true;
          
          final targetId = CampusConstants.resolveToId(targetUni) ?? targetUni;
          return targetId == _browsingCampus;
        }).toList();
      }
      
      return items;
    });
  }

  Future<void> createAnnouncement(Announcement announcement) async {
    await _collection.doc(announcement.id).set(announcement.toJson());
  }

  Future<void> updateAnnouncement(Announcement announcement) async {
    await _collection.doc(announcement.id).update(announcement.toJson());
  }

  Future<void> deleteAnnouncement(String id) async {
    await _collection.doc(id).delete();
  }

  Future<Announcement?> getAnnouncementById(String id) async {
    final doc = await _collection.doc(id).get();
    if (doc.exists) {
      return Announcement.fromJson(doc.data() as Map<String, dynamic>);
    }
    return null;
  }
}
