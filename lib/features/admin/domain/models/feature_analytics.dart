class FeatureAnalytics {
  final MarketplaceStats marketplace;
  final HousingStats housing;
  final NotesStats notes;
  final EventStats events;
  final SupportStats support;
  final ModerationStats moderation;
  final AnnouncementStats announcements;
  final DateTime updatedAt;

  FeatureAnalytics({
    required this.marketplace,
    required this.housing,
    required this.notes,
    required this.events,
    required this.support,
    required this.moderation,
    required this.announcements,
    required this.updatedAt,
  });

  factory FeatureAnalytics.empty() => FeatureAnalytics(
    marketplace: MarketplaceStats.empty(),
    housing: HousingStats.empty(),
    notes: NotesStats.empty(),
    events: EventStats.empty(),
    support: SupportStats.empty(),
    moderation: ModerationStats.empty(),
    announcements: AnnouncementStats.empty(),
    updatedAt: DateTime.now(),
  );
}

class MarketplaceStats {
  final int totalListings;
  final int activeListings;
  final int soldListings;
  final int newListingsToday;
  final Map<String, int> listingsByCategory;
  final int totalViews;
  final int totalSaves;
  final int totalChatsStarted;

  MarketplaceStats({
    required this.totalListings,
    required this.activeListings,
    required this.soldListings,
    required this.newListingsToday,
    required this.listingsByCategory,
    required this.totalViews,
    required this.totalSaves,
    required this.totalChatsStarted,
  });

  factory MarketplaceStats.empty() => MarketplaceStats(
    totalListings: 0,
    activeListings: 0,
    soldListings: 0,
    newListingsToday: 0,
    listingsByCategory: {},
    totalViews: 0,
    totalSaves: 0,
    totalChatsStarted: 0,
  );
}

class HousingStats {
  final int totalListings;
  final int availableListings;
  final int takenListings;
  final int newListingsToday;
  final Map<String, int> listingsByUniversity;
  final int totalViews;
  final int totalSaves;

  HousingStats({
    required this.totalListings,
    required this.availableListings,
    required this.takenListings,
    required this.newListingsToday,
    required this.listingsByUniversity,
    required this.totalViews,
    required this.totalSaves,
  });

  factory HousingStats.empty() => HousingStats(
    totalListings: 0,
    availableListings: 0,
    takenListings: 0,
    newListingsToday: 0,
    listingsByUniversity: {},
    totalViews: 0,
    totalSaves: 0,
  );
}

class NotesStats {
  final int totalNotes;
  final int activeNotes;
  final int newNotesToday;
  final Map<String, int> notesByCategory;
  final int totalViews;
  final int totalDownloads;

  NotesStats({
    required this.totalNotes,
    required this.activeNotes,
    required this.newNotesToday,
    required this.notesByCategory,
    required this.totalViews,
    required this.totalDownloads,
  });

  factory NotesStats.empty() => NotesStats(
    totalNotes: 0,
    activeNotes: 0,
    newNotesToday: 0,
    notesByCategory: {},
    totalViews: 0,
    totalDownloads: 0,
  );
}

class EventStats {
  final int totalEvents;
  final int upcomingEvents;
  final int liveEvents;
  final int pendingApprovals;
  final int totalAttendees;

  EventStats({
    required this.totalEvents,
    required this.upcomingEvents,
    required this.liveEvents,
    required this.pendingApprovals,
    required this.totalAttendees,
  });

  factory EventStats.empty() => EventStats(
    totalEvents: 0,
    upcomingEvents: 0,
    liveEvents: 0,
    pendingApprovals: 0,
    totalAttendees: 0,
  );
}

class SupportStats {
  final int totalConversations;
  final int openConversations;
  final int waitingAdmin;
  final int waitingUser;
  final int resolvedToday;

  SupportStats({
    required this.totalConversations,
    required this.openConversations,
    required this.waitingAdmin,
    required this.waitingUser,
    required this.resolvedToday,
  });

  factory SupportStats.empty() => SupportStats(
    totalConversations: 0,
    openConversations: 0,
    waitingAdmin: 0,
    waitingUser: 0,
    resolvedToday: 0,
  );
}

class ModerationStats {
  final int pendingReports;
  final int resolvedReportsToday;
  final int pendingVerifications;
  final int rejectedVerificationsToday;

  ModerationStats({
    required this.pendingReports,
    required this.resolvedReportsToday,
    required this.pendingVerifications,
    required this.rejectedVerificationsToday,
  });

  factory ModerationStats.empty() => ModerationStats(
    pendingReports: 0,
    resolvedReportsToday: 0,
    pendingVerifications: 0,
    rejectedVerificationsToday: 0,
  );
}

class AnnouncementStats {
  final int activeAnnouncements;
  final int scheduledAnnouncements;
  final int expiredAnnouncements;

  AnnouncementStats({
    required this.activeAnnouncements,
    required this.scheduledAnnouncements,
    required this.expiredAnnouncements,
  });

  factory AnnouncementStats.empty() => AnnouncementStats(
    activeAnnouncements: 0,
    scheduledAnnouncements: 0,
    expiredAnnouncements: 0,
  );
}
