import '../models/gig_application.dart';

abstract class GigsRepository {
  Future<void> submitApplication(GigApplication application);
  Stream<List<GigApplication>> watchApplicationsForGig(String gigId);
  Stream<List<GigApplication>> watchApplicationsForEmployer(String employerId);
  Stream<List<GigApplication>> watchApplicationsForFreelancer(String freelancerId);
  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status);

  // Gig Posting Management
  Future<void> createGigPosting({
    required String gigId,
    required String employerId,
    required String title,
    required String description,
    required double budget,
    required DateTime deadline,
    required List<String> skillsRequired,
  });

  Future<void> closeGigPosting(String gigId);

  // Rating & Review System
  Future<void> rateFreelancer({
    required String freelancerId,
    required String gigId,
    required double rating,
    required String comment,
  });

  Future<void> rateEmployer({
    required String employerId,
    required String gigId,
    required double rating,
    required String comment,
  });

  // Dispute Handling
  Future<void> submitDispute({
    required String gigId,
    required String reporterId,
    required String reason,
    required String description,
  });

  Stream<List<Map<String, dynamic>>> watchGigDisputes(String adminId);

  Future<void> resolveDispute({
    required String disputeId,
    required String adminId,
    required String resolution,
  });

  // Moderation & Admin Methods
  Future<void> flagGig({
    required String gigId,
    required String reason,
    String? adminNotes,
  });

  Future<void> removeGig({
    required String gigId,
    required String reason,
    required String adminId,
  });

  Future<void> suspendFreelancer({
    required String freelancerId,
    required String reason,
    required String adminId,
  });

  Stream<List<Map<String, dynamic>>> watchFlaggedGigs(String campusId);
}
