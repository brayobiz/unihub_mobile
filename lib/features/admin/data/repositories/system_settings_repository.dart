import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/system_settings.dart';

class SystemSettingsRepository {
  final FirebaseFirestore _firestore;

  SystemSettingsRepository(this._firestore);

  DocumentReference get _settingsDoc => 
      _firestore.collection('config').doc('system_settings');

  static final SystemSettings _defaultSettings = SystemSettings(
    supportEmail: 'support.ulify@gmail.com',
    privacyPolicyUrl: 'https://unihub-3663e.web.app/privacy',
    termsOfServiceUrl: 'https://unihub-3663e.web.app/terms',
    websiteUrl: 'https://unihub-3663e.web.app',
    socialLinks: {
      'instagram': 'https://instagram.com/unihub_campus',
      'twitter': 'https://twitter.com/unihub_campus',
    },
    maintenanceMode: false,
    maintenanceMessage: 'Ulify is currently under maintenance. We\'ll be back shortly!',
    appVersion: '1.0.0',
    lastUpdated: DateTime.now(),
    updatedBy: 'system',
  );

  Stream<SystemSettings> watchSettings() {
    return _settingsDoc.snapshots().map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return _defaultSettings;
      }
      
      final settings = SystemSettings.fromJson(snapshot.data() as Map<String, dynamic>);
      return _applyAutoCorrections(settings);
    });
  }

  Future<SystemSettings> getSettings() async {
    final snapshot = await _settingsDoc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return _defaultSettings;
    }
    
    final settings = SystemSettings.fromJson(snapshot.data() as Map<String, dynamic>);
    return _applyAutoCorrections(settings);
  }

  SystemSettings _applyAutoCorrections(SystemSettings settings) {
    // Auto-correction for legacy or placeholder URLs
    if (settings.privacyPolicyUrl.contains('unihub.com')) {
      return settings.copyWith(
        privacyPolicyUrl: 'https://unihub-3663e.web.app/privacy',
        termsOfServiceUrl: 'https://unihub-3663e.web.app/terms',
        websiteUrl: 'https://unihub-3663e.web.app',
      );
    }
    return settings;
  }

  Future<void> updateSettings(SystemSettings settings) async {
    await _settingsDoc.set(settings.toJson(), SetOptions(merge: true));
  }
}
