import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';

class SupportCenterFilters {
  final String status;
  final String priority;
  final String assignment;
  final String search;

  const SupportCenterFilters({
    this.status = 'waiting_admin',
    this.priority = 'all',
    this.assignment = 'all',
    this.search = '',
  });

  SupportCenterFilters copyWith({
    String? status,
    String? priority,
    String? assignment,
    String? search,
  }) {
    return SupportCenterFilters(
      status: status ?? this.status,
      priority: priority ?? this.priority,
      assignment: assignment ?? this.assignment,
      search: search ?? this.search,
    );
  }
}

class SupportCenterController extends StateNotifier<SupportCenterFilters> {
  final Ref _ref;

  SupportCenterController(this._ref) : super(const SupportCenterFilters());

  void setStatus(String status) => state = state.copyWith(status: status);
  void setPriority(String priority) => state = state.copyWith(priority: priority);
  void setAssignment(String assignment) => state = state.copyWith(assignment: assignment);
  void setSearch(String search) => state = state.copyWith(search: search);

  void clearFilters() {
    state = const SupportCenterFilters(status: 'all');
  }

  Future<String?> claimNext() async {
    final currentUser = _ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) return null;

    // We fetch a fresh list of "waiting_admin" + "unassigned" tickets 
    // specifically for the claim logic, ignoring current UI filters.
    final conversations = await _ref.read(adminRepositoryProvider).watchSupportConversations(
      status: 'waiting_admin',
      assignedAdminId: 'unassigned',
    ).first;

    if (conversations.isEmpty) {
       // Check if I already have an active ticket assigned to me that I haven't resolved
       final myActive = await _ref.read(adminRepositoryProvider).watchSupportConversations(
         status: 'waiting_admin',
         assignedAdminId: currentUser.uid,
       ).first;
       
       if (myActive.isNotEmpty) {
         // Sort by oldest first
         myActive.sort((a, b) => a.lastMessageTime.compareTo(b.lastMessageTime));
         return myActive.first.id;
       }
       return null;
    }

    // Sort by oldest first to prioritize students who have been waiting longest
    final available = List<Conversation>.from(conversations);
    available.sort((a, b) => a.lastMessageTime.compareTo(b.lastMessageTime));
    final oldest = available.first;

    // Assign the ticket to me
    await _ref.read(adminRepositoryProvider).assignSupportConversation(
      oldest.id, 
      currentUser.uid, 
      adminName: currentUser.fullName, 
      performingAdminId: currentUser.uid
    );

    return oldest.id;
  }

  // Internal helper to map assignment string to the specific format expected by the provider
  ({String? status, String? priority, String? assignedAdminId, String? search}) 
  _getFiltersForProvider(SupportCenterFilters filters) {
    final currentUser = _ref.read(appUserProvider).valueOrNull;
    final String? assignmentFilter = filters.assignment == 'me' 
        ? currentUser?.uid 
        : (filters.assignment == 'unassigned' ? 'unassigned' : 'all');

    return (
      status: filters.status,
      priority: filters.priority,
      assignedAdminId: assignmentFilter,
      search: filters.search,
    );
  }
}

final supportCenterFiltersProvider = StateNotifierProvider<SupportCenterController, SupportCenterFilters>((ref) {
  return SupportCenterController(ref);
});

final filteredSupportConversationsProvider = StreamProvider.autoDispose<List<Conversation>>((ref) {
  final filters = ref.watch(supportCenterFiltersProvider);
  final currentUser = ref.watch(appUserProvider).valueOrNull;
  
  final String? assignmentFilter = filters.assignment == 'me' 
      ? currentUser?.uid 
      : (filters.assignment == 'unassigned' ? 'unassigned' : 'all');

  return ref.watch(supportConversationsProvider((
    status: filters.status,
    priority: filters.priority,
    assignedAdminId: assignmentFilter,
    search: filters.search,
  )).stream).map((conversations) {
    if (currentUser == null) return conversations;

    // Filter logic:
    // 1. If explicitly filtering for 'me', only show mine (already handled by provider/repo usually, but we double check or refine here if 'all' is tricky)
    // 2. If 'all', user wants "unassigned OR mine"
    if (filters.assignment == 'all') {
      return conversations.where((c) => 
        c.assignedAdminId == null || c.assignedAdminId == currentUser.uid
      ).toList();
    }
    
    return conversations;
  });
});
