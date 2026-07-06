import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import 'package:unihub_mobile/features/campus_filter/shared/providers.dart';
import 'package:unihub_mobile/services/notification_service.dart';
import '../data/repositories/attendance_repository_impl.dart';
import '../data/repositories/event_repository_impl.dart';
import '../data/repositories/organizer_repository_impl.dart';
import '../domain/models/attendance.dart';
import '../domain/models/event.dart';
import '../domain/models/event_category.dart';
import '../domain/models/organizer.dart';
import '../domain/models/organizer_member.dart';
import '../domain/repositories/attendance_repository.dart';
import '../domain/repositories/event_repository.dart';
import '../domain/repositories/organizer_repository.dart';
import '../domain/services/event_service.dart';
import '../domain/services/organizer_service.dart';

final organizerRepositoryProvider = Provider<OrganizerRepository>((ref) {
  return OrganizerRepositoryImpl(
    ref.watch(firestoreProvider),
  );
});

final organizerServiceProvider = Provider<OrganizerService>((ref) {
  return OrganizerService(
    ref.watch(organizerRepositoryProvider),
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final eventRepositoryProvider = Provider<EventRepository>((ref) {
  return EventRepositoryImpl(
    ref.watch(firestoreProvider),
  );
});

final eventServiceProvider = Provider<EventService>((ref) {
  return EventService(
    ref.watch(eventRepositoryProvider),
    ref.watch(organizerRepositoryProvider),
    ref.watch(attendanceRepositoryProvider),
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

final attendanceRepositoryProvider = Provider<AttendanceRepository>((ref) {
  return AttendanceRepositoryImpl(
    ref.watch(firestoreProvider),
    ref.watch(notificationServiceProvider),
  );
});

// Organizers
final organizerProvider = StreamProvider.autoDispose.family<Organizer?, String>((ref, id) {
  return ref.watch(organizerRepositoryProvider).watchOrganizerById(id);
});

final userManagedOrganizersProvider = StreamProvider.autoDispose<List<Organizer>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(organizerRepositoryProvider).watchUserManagedOrganizers(user.uid);
});

final organizerMembersProvider = StreamProvider.autoDispose.family<List<OrganizerMember>, String>((ref, organizerId) {
  return ref.watch(organizerRepositoryProvider).watchOrganizerMembers(organizerId);
});

final isFollowingOrganizerProvider = StreamProvider.autoDispose.family<bool, String>((ref, organizerId) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(false);
  return ref.watch(organizerRepositoryProvider).isFollowingOrganizer(user.uid, organizerId);
});

final followedOrganizersProvider = StreamProvider.autoDispose<List<Organizer>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(organizerRepositoryProvider).watchFollowedOrganizers(user.uid);
});

// Events
final eventProvider = StreamProvider.autoDispose.family<Event?, String>((ref, id) {
  return ref.watch(eventRepositoryProvider).watchEventById(id);
});

final campusEventsProvider = StreamProvider.autoDispose.family<List<Event>, List<EventStatus>?>((ref, statuses) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  return ref.watch(eventRepositoryProvider).watchEventsByCampus(campusId, statuses: statuses);
});

final organizerEventsProvider = StreamProvider.autoDispose.family<List<Event>, String>((ref, organizerId) {
  return ref.watch(eventRepositoryProvider).watchEventsByOrganizer(organizerId);
});

final eventCategoriesProvider = StreamProvider.autoDispose<List<EventCategory>>((ref) {
  return ref.watch(eventRepositoryProvider).watchCategories();
});

final featuredEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  return ref.watch(eventRepositoryProvider).watchFeaturedEvents(campusId);
});

final liveEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  return ref.watch(eventRepositoryProvider).watchLiveEvents(campusId);
});

final todayEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = startOfDay.add(const Duration(days: 1));
  
  return ref.watch(eventRepositoryProvider).watchEventsByCampus(
    campusId,
    after: startOfDay,
  ).map((events) => events.where((e) => e.startAt.isBefore(endOfDay)).toList());
});

final thisWeekEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  final now = DateTime.now();
  final endOfWeek = now.add(const Duration(days: 7));
  
  return ref.watch(eventRepositoryProvider).watchEventsByCampus(
    campusId,
    after: now,
  ).map((events) => events.where((e) => e.startAt.isBefore(endOfWeek)).toList());
});

final eventsByCategoryProvider = StreamProvider.autoDispose.family<List<Event>, String>((ref, categoryId) {
  final campusId = ref.watch(effectiveCampusFilterProvider);
  if (campusId == null) return Stream.value([]);
  return ref.watch(eventRepositoryProvider).watchEventsByCampus(
    campusId,
    categoryId: categoryId,
  );
});

// Attendance
final eventAttendanceProvider = StreamProvider.autoDispose.family<EventAttendance?, String>((ref, eventId) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);
  return ref.watch(attendanceRepositoryProvider).watchAttendance(user.uid, eventId);
});

final userGoingEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(attendanceRepositoryProvider).watchGoingEvents(user.uid);
});

final userSavedEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(attendanceRepositoryProvider).watchSavedEvents(user.uid);
});

final userPastEventsProvider = StreamProvider.autoDispose<List<Event>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(attendanceRepositoryProvider).watchPastEvents(user.uid);
});

class EventDiscoveryData {
  final List<Event> featured;
  final List<Event> live;
  final List<Event> today;
  final List<Event> thisWeek;
  final List<EventCategory> categories;

  EventDiscoveryData({
    required this.featured,
    required this.live,
    required this.today,
    required this.thisWeek,
    required this.categories,
  });
}

final eventDiscoveryDataProvider = Provider.autoDispose<AsyncValue<EventDiscoveryData>>((ref) {
  final featured = ref.watch(featuredEventsProvider);
  final live = ref.watch(liveEventsProvider);
  final today = ref.watch(todayEventsProvider);
  final thisWeek = ref.watch(thisWeekEventsProvider);
  final categories = ref.watch(eventCategoriesProvider);

  if (featured.isLoading || live.isLoading || today.isLoading || thisWeek.isLoading || categories.isLoading) {
    return const AsyncValue.loading();
  }

  if (featured.hasError) return AsyncValue.error(featured.error!, featured.stackTrace!);
  if (live.hasError) return AsyncValue.error(live.error!, live.stackTrace!);
  if (today.hasError) return AsyncValue.error(today.error!, today.stackTrace!);
  if (thisWeek.hasError) return AsyncValue.error(thisWeek.error!, thisWeek.stackTrace!);
  if (categories.hasError) return AsyncValue.error(categories.error!, categories.stackTrace!);

  return AsyncValue.data(EventDiscoveryData(
    featured: featured.value ?? [],
    live: live.value ?? [],
    today: today.value ?? [],
    thisWeek: thisWeek.value ?? [],
    categories: categories.value ?? [],
  ));
});

// Homepage Integration
class HomepageEventsData {
  final List<Event> goingSoon;
  final List<Event> liveNow;
  final List<Event> today;
  final List<Event> featured;

  HomepageEventsData({
    required this.goingSoon,
    required this.liveNow,
    required this.today,
    required this.featured,
  });

  bool get isEmpty => goingSoon.isEmpty && liveNow.isEmpty && today.isEmpty && featured.isEmpty;
}

final homepageEventsProvider = Provider.autoDispose<AsyncValue<HomepageEventsData>>((ref) {
  final goingAsync = ref.watch(userGoingEventsProvider);
  final liveAsync = ref.watch(liveEventsProvider);
  final todayAsync = ref.watch(todayEventsProvider);
  final featuredAsync = ref.watch(featuredEventsProvider);

  if (goingAsync.isLoading || liveAsync.isLoading || todayAsync.isLoading || featuredAsync.isLoading) {
    return const AsyncValue.loading();
  }

  final now = DateTime.now();
  final goingSoon = (goingAsync.value ?? []).where((e) {
    return e.startAt.isAfter(now) && e.startAt.isBefore(now.add(const Duration(hours: 24)));
  }).toList();

  final goingIds = goingSoon.map((e) => e.id).toSet();
  
  final liveNow = (liveAsync.value ?? []).toList();
  final liveIds = liveNow.map((e) => e.id).toSet();

  final isLateEvening = now.hour >= 18;
  final startRange = isLateEvening ? DateTime(now.year, now.month, now.day + 1) : now;
  final endRange = DateTime(startRange.year, startRange.month, startRange.day + 1);

  final upcoming = (todayAsync.value ?? []).where((e) {
    if (goingIds.contains(e.id) || liveIds.contains(e.id)) return false;
    return e.startAt.isAfter(now) && e.startAt.isBefore(endRange);
  }).toList();

  final featured = (featuredAsync.value ?? []).where((e) {
    return !goingIds.contains(e.id) && !liveIds.contains(e.id) && 
           !upcoming.any((t) => t.id == e.id);
  }).toList();

  return AsyncValue.data(HomepageEventsData(
    goingSoon: goingSoon,
    liveNow: liveNow,
    today: upcoming,
    featured: featured,
  ));
});
