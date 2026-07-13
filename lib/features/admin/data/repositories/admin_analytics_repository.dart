import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/platform_analytics.dart';
import '../../domain/models/user_analytics.dart';
import '../../domain/models/feature_analytics.dart';

class AdminAnalyticsRepository {
  final FirebaseFirestore _firestore;

  AdminAnalyticsRepository(this._firestore);

  /// Helper to calculate time-based metrics safely in-memory to avoid Index errors
  int _countInRange(QuerySnapshot snap, String field, DateTime start, {DateTime? end}) {
    int count = 0;
    for (var doc in snap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final timestamp = (data[field] as Timestamp?)?.toDate();
      if (timestamp == null) continue;
      if (timestamp.isAfter(start) && (end == null || timestamp.isBefore(end))) {
        count++;
      }
    }
    return count;
  }

  /// Helper to count by status in-memory
  int _countByStatus(QuerySnapshot snap, String field, String status) {
    return snap.docs.where((doc) => (doc.data() as Map<String, dynamic>)[field] == status).length;
  }

  Future<PlatformAnalytics> getPlatformAnalytics() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    // FETCH RAW COLLECTIONS (Index-Free)
    // For a production app with huge data, this would be slow.
    // But for MVP, this is the only way to avoid the "Index Required" screen entirely.
    final results = await Future.wait([
      _firestore.collection('users').get(),           // 0
      _firestore.collection('listings').get(),        // 1
      _firestore.collection('housing_listings').get(),// 2
      _firestore.collection('notes').get(),           // 3
      _firestore.collection('reports').get(),         // 4
      _firestore.collection('housing_reports').get(), // 5
      _firestore.collection('identity_verifications').get(), // 6
      _firestore.collection('student_verifications').get(),  // 7
      _firestore.collection('verification_applications').get(), // 8
      _firestore.collection('organizer_verification_requests').get(), // 9
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).get(), // 10
      _firestore.collection('announcements').get(),   // 11
      _firestore.collection('events').get(),          // 12
    ]);

    final usersSnap = results[0] as QuerySnapshot;
    final listingsSnap = results[1] as QuerySnapshot;
    final housingSnap = results[2] as QuerySnapshot;
    final notesSnap = results[3] as QuerySnapshot;
    final reportsSnap = results[4] as QuerySnapshot;
    final hReportsSnap = results[5] as QuerySnapshot;
    final idVerifSnap = results[6] as QuerySnapshot;
    final stuVerifSnap = results[7] as QuerySnapshot;
    final proVerifSnap = results[8] as QuerySnapshot;
    final orgVerifSnap = results[9] as QuerySnapshot;
    final supportSnap = results[10] as QuerySnapshot;
    final announcementsSnap = results[11] as QuerySnapshot;
    final eventsSnap = results[12] as QuerySnapshot;

    // Platform Overview Calculations
    final activeUsers = _countInRange(usersSnap, 'lastSeen', thirtyDaysAgo);
    final verifiedUsers = usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['isIdentityVerified'] == true).length;
    final pendingReports = _countByStatus(reportsSnap, 'status', 'pending') + _countByStatus(hReportsSnap, 'status', 'pending');
    final pendingVerif = _countByStatus(idVerifSnap, 'status', 'pending') + 
                        _countByStatus(stuVerifSnap, 'status', 'pending') + 
                        _countByStatus(proVerifSnap, 'status', 'pending') + 
                        _countByStatus(orgVerifSnap, 'status', 'pending');
    
    final openSupport = supportSnap.docs.where((d) {
      final s = (d.data() as Map<String, dynamic>)['supportStatus'];
      return s == 'waiting_admin' || s == 'active';
    }).length;

    int activeAnn = 0;
    for (var doc in announcementsSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final p = (data['publishAt'] as Timestamp?)?.toDate();
      final e = (data['expiresAt'] as Timestamp?)?.toDate();
      if (p != null && p.isBefore(now) && (e == null || e.isAfter(now))) activeAnn++;
    }

    return PlatformAnalytics(
      totalUsers: usersSnap.size,
      activeUsers: activeUsers,
      verifiedUsers: verifiedUsers,
      totalMarketplaceListings: _countByStatus(listingsSnap, 'status', 'active'),
      totalHousingListings: _countByStatus(housingSnap, 'status', 'available'),
      totalNotes: _countByStatus(notesSnap, 'status', 'active'),
      pendingReports: pendingReports,
      pendingVerifications: pendingVerif,
      openSupportConversations: openSupport,
      activeAnnouncements: activeAnn,
      totalEvents: eventsSnap.size,
      pendingEventApprovals: _countByStatus(eventsSnap, 'status', 'submitted'),
      newUsersToday: _countInRange(usersSnap, 'createdAt', startOfToday),
      currentlyActive: usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['isOnline'] == true).length,
      updatedAt: now,
    );
  }

  Future<UserAnalytics> getUserAnalytics() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final startOfMonth = DateTime(now.year, now.month, 1);
    final thirtyDaysAgo = now.subtract(const Duration(days: 30));

    final results = await Future.wait([
      _firestore.collection('users').get(),
      _firestore.collection('identity_verifications').get(),
      _firestore.collection('student_verifications').get(),
      _firestore.collection('verification_applications').get(),
      _firestore.collection('organizer_verification_requests').get(),
    ]);

    final usersSnap = results[0] as QuerySnapshot;
    final allVerifDocs = [
      ...(results[1] as QuerySnapshot).docs,
      ...(results[2] as QuerySnapshot).docs,
      ...(results[3] as QuerySnapshot).docs,
      ...(results[4] as QuerySnapshot).docs,
    ];

    final trendDays = List.generate(7, (i) => DateTime(now.year, now.month, now.day).subtract(Duration(days: 6 - i)));
    final growthTrend = trendDays.map((date) {
      return GrowthDataPoint(date, _countInRange(usersSnap, 'createdAt', date, end: date.add(const Duration(days: 1))));
    }).toList();

    double totalTrust = 0;
    for (var d in usersSnap.docs) {
      totalTrust += ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0.0);
    }

    final verified = usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['isIdentityVerified'] == true).length;
    final rejected = allVerifDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'rejected').length;

    return UserAnalytics(
      totalUsers: usersSnap.size,
      newUsersToday: _countInRange(usersSnap, 'createdAt', startOfToday),
      newUsersThisWeek: _countInRange(usersSnap, 'createdAt', startOfWeek),
      newUsersThisMonth: _countInRange(usersSnap, 'createdAt', startOfMonth),
      dailyActiveUsers: _countInRange(usersSnap, 'lastSeen', startOfToday),
      weeklyActiveUsers: _countInRange(usersSnap, 'lastSeen', startOfWeek),
      monthlyActiveUsers: _countInRange(usersSnap, 'lastSeen', thirtyDaysAgo),
      currentlyActive: usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['isOnline'] == true).length,
      verifiedUsers: verified,
      pendingVerifications: allVerifDocs.where((d) => (d.data() as Map<String, dynamic>)['status'] == 'pending').length,
      rejectedVerifications: rejected,
      verificationApprovalRate: (verified + rejected) > 0 ? (verified / (verified + rejected)) : 0.0,
      usersByUniversity: {},
      usersByAccountType: {
        'Student': usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['accountType'] == 'student').length,
        'Business': usersSnap.docs.where((d) => (d.data() as Map<String, dynamic>)['accountType'] == 'business').length,
      },
      averageTrustScore: usersSnap.size > 0 ? totalTrust / usersSnap.size : 0.0,
      trustScoreDistribution: {
        '0-20': usersSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) < 20).length,
        '21-40': usersSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) >= 20 && ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) < 40).length,
        '41-60': usersSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) >= 40 && ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) < 60).length,
        '61-80': usersSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) >= 60 && ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) < 80).length,
        '81-100': usersSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['trustScore'] ?? 0) >= 80).length,
      },
      growthTrend: growthTrend,
      updatedAt: now,
    );
  }

  Future<FeatureAnalytics> getFeatureAnalytics() async {
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    final results = await Future.wait([
      _firestore.collection('listings').get(),        // 0
      _firestore.collection('housing_listings').get(),// 1
      _firestore.collection('notes').get(),           // 2
      _firestore.collection('events').get(),          // 3
      _firestore.collection('reports').get(),         // 4
      _firestore.collection('housing_reports').get(), // 5
      _firestore.collection('conversations').where('isSupport', isEqualTo: true).get(), // 6
      _firestore.collection('announcements').get(),   // 7
      _firestore.collection('identity_verifications').get(), // 8
    ]);

    final mSnap = results[0] as QuerySnapshot;
    final hSnap = results[1] as QuerySnapshot;
    final nSnap = results[2] as QuerySnapshot;
    final eSnap = results[3] as QuerySnapshot;
    final rSnap = results[4] as QuerySnapshot;
    final hrSnap = results[5] as QuerySnapshot;
    final sSnap = results[6] as QuerySnapshot;
    final aSnap = results[7] as QuerySnapshot;
    final vSnap = results[8] as QuerySnapshot;

    // Aggregations helper
    double getSum(QuerySnapshot snap, String field) {
      double sum = 0;
      for (var d in snap.docs) {
        sum += ((d.data() as Map<String, dynamic>)[field] ?? 0).toDouble();
      }
      return sum;
    }

    return FeatureAnalytics(
      marketplace: MarketplaceStats(
        totalListings: mSnap.size,
        activeListings: _countByStatus(mSnap, 'status', 'active'),
        soldListings: _countByStatus(mSnap, 'status', 'sold'),
        newListingsToday: _countInRange(mSnap, 'createdAt', startOfToday),
        listingsByCategory: {},
        totalViews: getSum(mSnap, 'viewsCount').toInt(),
        totalSaves: getSum(mSnap, 'savesCount').toInt(),
        totalChatsStarted: getSum(mSnap, 'chatsStartedCount').toInt(),
      ),
      housing: HousingStats(
        totalListings: hSnap.size,
        availableListings: _countByStatus(hSnap, 'status', 'available'),
        takenListings: _countByStatus(hSnap, 'status', 'taken'),
        newListingsToday: _countInRange(hSnap, 'createdAt', startOfToday),
        listingsByUniversity: {},
        totalViews: getSum(hSnap, 'views').toInt(),
        totalSaves: getSum(hSnap, 'saves').toInt(),
      ),
      notes: NotesStats(
        totalNotes: nSnap.size,
        activeNotes: _countByStatus(nSnap, 'status', 'active'),
        newNotesToday: _countInRange(nSnap, 'createdAt', startOfToday),
        notesByCategory: {},
        totalViews: getSum(nSnap, 'views').toInt(),
        totalDownloads: getSum(nSnap, 'downloadsCount').toInt(),
      ),
      events: EventStats(
        totalEvents: eSnap.size,
        upcomingEvents: 0,
        liveEvents: _countByStatus(eSnap, 'status', 'approved'),
        pendingApprovals: _countByStatus(eSnap, 'status', 'submitted'),
        totalAttendees: 0,
      ),
      support: SupportStats(
        totalConversations: sSnap.size,
        openConversations: sSnap.docs.where((d) => ['active', 'waiting_admin'].contains((d.data() as Map<String, dynamic>)['supportStatus'])).length,
        waitingAdmin: _countByStatus(sSnap, 'supportStatus', 'waiting_admin'),
        waitingUser: _countByStatus(sSnap, 'supportStatus', 'waiting_user'),
        resolvedToday: _countInRange(sSnap, 'updatedAt', startOfToday), // Approximation using updatedAt
      ),
      moderation: ModerationStats(
        pendingReports: _countByStatus(rSnap, 'status', 'pending') + _countByStatus(hrSnap, 'status', 'pending'),
        resolvedReportsToday: _countInRange(rSnap, 'updatedAt', startOfToday),
        pendingVerifications: _countByStatus(vSnap, 'status', 'pending'),
        rejectedVerificationsToday: _countInRange(vSnap, 'updatedAt', startOfToday),
      ),
      announcements: AnnouncementStats(
        activeAnnouncements: aSnap.docs.where((d) {
          final data = d.data() as Map<String, dynamic>;
          final p = (data['publishAt'] as Timestamp?)?.toDate();
          final e = (data['expiresAt'] as Timestamp?)?.toDate();
          return p != null && p.isBefore(now) && (e == null || e.isAfter(now));
        }).length,
        scheduledAnnouncements: aSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['publishAt'] as Timestamp?)?.toDate()?.isAfter(now) ?? false).length,
        expiredAnnouncements: aSnap.docs.where((d) => ((d.data() as Map<String, dynamic>)['expiresAt'] as Timestamp?)?.toDate()?.isBefore(now) ?? false).length,
      ),
      updatedAt: now,
    );
  }

  Stream<PlatformAnalytics> watchPlatformAnalytics() async* {
    yield await getPlatformAnalytics();
    yield* Stream.periodic(const Duration(minutes: 5)).asyncMap((_) => getPlatformAnalytics());
  }

  Stream<UserAnalytics> watchUserAnalytics() async* {
    yield await getUserAnalytics();
    yield* Stream.periodic(const Duration(minutes: 10)).asyncMap((_) => getUserAnalytics());
  }

  Stream<FeatureAnalytics> watchFeatureAnalytics() async* {
    yield await getFeatureAnalytics();
    yield* Stream.periodic(const Duration(minutes: 15)).asyncMap((_) => getFeatureAnalytics());
  }
}
