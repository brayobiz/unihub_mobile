import '../models/verification_application.dart';
import '../models/professional_role.dart';
import '../models/student_verification.dart';
import '../models/identity_verification.dart';

abstract class TrustRepository {
  // Professional Verification
  Future<void> submitProfessionalApplication(VerificationApplication application);
  Future<VerificationApplication?> getLatestApplication(String userId, ProfessionalRole role);
  Stream<List<VerificationApplication>> watchUserApplications(String userId);
  
  // Student Verification
  Future<void> submitStudentVerification(String userId, String studentIdUrl);
  Future<StudentVerification?> getStudentVerification(String userId);
  Stream<StudentVerification?> watchStudentVerification(String userId);

  // Platform Identity Verification
  Future<void> submitIdentityVerification(String userId, String idUrl, String selfieUrl);
  Future<IdentityVerification?> getIdentityVerification(String userId);
  Stream<IdentityVerification?> watchIdentityVerification(String userId);
  
  // Reputation
  Future<void> updateReputation(String userId, Map<String, dynamic> delta);
}
