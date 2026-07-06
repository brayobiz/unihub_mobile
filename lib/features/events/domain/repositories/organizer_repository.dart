import '../models/organizer.dart';
import '../models/organizer_member.dart';

abstract class OrganizerRepository {
  // Organizer Profile
  Future<Organizer?> getOrganizerById(String id);
  Stream<Organizer?> watchOrganizerById(String id);
  Future<List<Organizer>> getOrganizersByCampus(String campusId, {int limit = 20});
  Stream<List<Organizer>> watchUserManagedOrganizers(String userId);
  
  Future<void> createOrganizer(Organizer organizer);
  Future<void> updateOrganizer(Organizer organizer);
  Future<void> deleteOrganizer(String id);
  
  // Membership
  Future<List<OrganizerMember>> getOrganizerMembers(String organizerId);
  Stream<List<OrganizerMember>> watchOrganizerMembers(String organizerId);
  Future<OrganizerMember?> getMember(String organizerId, String userId);
  Future<void> addMember(OrganizerMember member);
  Future<void> updateMemberRole(String organizerId, String userId, OrganizerRole newRole);
  Future<void> removeMember(String organizerId, String userId);
  
  // Verification & Trust
  Future<void> requestVerification(String organizerId, Map<String, dynamic> applicationData);
  Future<void> updateTrustScore(String organizerId, double delta);
  
  // Engagement
  Future<void> toggleFollowOrganizer(String userId, String organizerId);
  Stream<bool> isFollowingOrganizer(String userId, String organizerId);
  Stream<List<Organizer>> watchFollowedOrganizers(String userId);
}
