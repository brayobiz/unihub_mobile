import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/core/utils/app_logger.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';

final dataExportServiceProvider = Provider((ref) {
  return DataExportService(ref.watch(firestoreProvider));
});

class DataExportService {
  final FirebaseFirestore _firestore;

  DataExportService(this._firestore);

  Future<void> exportUserData(String uid) async {
    try {
      AppLogger.info('Starting data export for user: $uid', 'DATA_EXPORT');
      
      final Map<String, dynamic> exportData = {
        'export_date': DateTime.now().toIso8601String(),
        'app': 'UniHub',
      };

      // 1. User Profile
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        exportData['profile'] = userDoc.data();
      }

      // 2. Marketplace Listings
      final listings = await _firestore.collection('listings')
          .where('sellerId', isEqualTo: uid)
          .get();
      exportData['marketplace_listings'] = listings.docs.map((doc) => doc.data()).toList();

      // 3. Housing Listings
      final housing = await _firestore.collection('housing_listings')
          .where('plugId', isEqualTo: uid)
          .get();
      exportData['housing_listings'] = housing.docs.map((doc) => doc.data()).toList();

      // 4. Study Notes
      final notes = await _firestore.collection('notes')
          .where('authorId', isEqualTo: uid)
          .get();
      exportData['study_notes'] = notes.docs.map((doc) => doc.data()).toList();

      // 5. Events
      final events = await _firestore.collection('events')
          .where('organizerId', isEqualTo: uid)
          .get();
      exportData['events_organized'] = events.docs.map((doc) => doc.data()).toList();

      // 6. Community Feed Items (Confessions, Gigs, etc.)
      final feedItems = await _firestore.collection('feed')
          .where('authorId', isEqualTo: uid)
          .get();
      exportData['community_posts'] = feedItems.docs.map((doc) => doc.data()).toList();

      // 7. Gig Applications (Freelancer)
      final freelancerApps = await _firestore.collection('gig_applications')
          .where('freelancerId', isEqualTo: uid)
          .get();
      exportData['gig_applications_sent'] = freelancerApps.docs.map((doc) => doc.data()).toList();

      // 8. Gig Applications (Employer - Received)
      final employerApps = await _firestore.collection('gig_applications')
          .where('employerId', isEqualTo: uid)
          .get();
      exportData['gig_applications_received'] = employerApps.docs.map((doc) => doc.data()).toList();

      // 9. Chats
      final chats = await _firestore.collection('conversations')
          .where('participants', arrayContains: uid)
          .get();
      
      final List<Map<String, dynamic>> chatExports = [];
      for (var convDoc in chats.docs) {
        final convData = convDoc.data();
        final messages = await convDoc.reference.collection('messages')
            .orderBy('timestamp')
            .get();
        convData['messages'] = messages.docs.map((doc) => doc.data()).toList();
        chatExports.add(convData);
      }
      exportData['chats'] = chatExports;
      
      // 10. Saved Items
      final savedMarketplace = await _firestore.collection('users').doc(uid).collection('saved_listings').get();
      exportData['saved_marketplace_ids'] = savedMarketplace.docs.map((doc) => doc.id).toList();

      final savedHousing = await _firestore.collection('users').doc(uid).collection('saved_housing').get();
      exportData['saved_housing_ids'] = savedHousing.docs.map((doc) => doc.id).toList();

      // Convert to JSON string
      // Note: We need a way to handle Timestamp objects in JSON. 
      // Firestore data often contains Timestamps which aren't JSON serializable by default.
      final sanitizedData = _sanitizeData(exportData);
      final jsonString = const JsonEncoder.withIndent('  ').convert(sanitizedData);

      // Save to file
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/unihub_data_export.json');
      await file.writeAsString(jsonString);

      // Share file
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'application/json')],
        subject: 'My UniHub Personal Data Export',
        text: 'Attached is your personal data export from UniHub.',
      );
      
      AppLogger.info('Data export completed for user: $uid', 'DATA_EXPORT');
    } catch (e, st) {
      AppLogger.error('Failed to export user data', e, st, 'DATA_EXPORT');
      rethrow;
    }
  }

  /// Recursively converts Timestamps and other non-serializable objects to strings
  dynamic _sanitizeData(dynamic data) {
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    } else if (data is Map) {
      return data.map((key, value) => MapEntry(key.toString(), _sanitizeData(value)));
    } else if (data is List) {
      return data.map((item) => _sanitizeData(item)).toList();
    }
    return data;
  }
}
