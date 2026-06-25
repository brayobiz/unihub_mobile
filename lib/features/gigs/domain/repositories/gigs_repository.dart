import '../models/gig_application.dart';

abstract class GigsRepository {
  Future<void> submitApplication(GigApplication application);
  Stream<List<GigApplication>> watchApplicationsForGig(String gigId);
  Stream<List<GigApplication>> watchApplicationsForEmployer(String employerId);
  Stream<List<GigApplication>> watchApplicationsForFreelancer(String freelancerId);
  Future<void> updateApplicationStatus(String applicationId, ApplicationStatus status);
}
