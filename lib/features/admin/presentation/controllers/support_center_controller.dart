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
    final conversations = _ref.read(supportConversationsProvider(_getFiltersForProvider(state))).valueOrNull;
    if (conversations == null || conversations.isEmpty) return null;

    final currentUser = _ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) return null;

    // Find oldest ticket waiting for admin that is not assigned to someone else
    final target = conversations
        .where((c) => 
            c.supportStatus == 'waiting_admin' && 
            (c.assignedAdminId == null || c.assignedAdminId == currentUser.uid))
        .toList();

    if (target.isEmpty) return null;

    // Sort by oldest first
    target.sort((a, b) => a.lastMessageTime.compareTo(b.lastMessageTime));
    final oldest = target.first;

    // Assign if not already assigned
    if (oldest.assignedAdminId == null) {
      await _ref.read(adminRepositoryProvider).assignSupportConversation(
        oldest.id, 
        currentUser.uid, 
        adminName: currentUser.fullName, 
        performingAdminId: currentUser.uid
      );
    }

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
  )).stream);
});
