import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';

class SupportCenterScreen extends ConsumerStatefulWidget {
  const SupportCenterScreen({super.key});

  @override
  ConsumerState<SupportCenterScreen> createState() => _SupportCenterScreenState();
}

class _SupportCenterScreenState extends ConsumerState<SupportCenterScreen> {
  String _selectedStatus = 'waiting_admin';
  String _selectedPriority = 'all';
  String _selectedAssignment = 'all';
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _claimNext(List<Conversation> conversations) async {
    final currentUser = ref.read(appUserProvider).valueOrNull;
    if (currentUser == null) return;

    // Find oldest ticket waiting for admin that is not assigned to someone else
    final target = conversations
        .where((c) => c.supportStatus == 'waiting_admin' && (c.assignedAdminId == null || c.assignedAdminId == currentUser.uid))
        .toList();

    if (target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No pending tickets waiting for admin assistance.')),
      );
      return;
    }

    // Sort by oldest first
    target.sort((a, b) => a.lastMessageTime.compareTo(b.lastMessageTime));
    final oldest = target.first;

    setState(() => _searchQuery = ''); // Reset search for navigation

    // Assign if not already assigned
    if (oldest.assignedAdminId == null) {
      await ref.read(adminRepositoryProvider).assignSupportConversation(
        oldest.id, 
        currentUser.uid, 
        adminName: currentUser.fullName, 
        performingAdminId: currentUser.uid
      );
    }

    if (mounted) {
      context.push('/admin/support/${oldest.id}', extra: oldest);
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = ref.watch(appUserProvider).valueOrNull;
    final String? assignmentFilter = _selectedAssignment == 'me' 
        ? currentUser?.uid 
        : (_selectedAssignment == 'unassigned' ? 'unassigned' : 'all');

    final filters = (
      status: _selectedStatus, 
      priority: _selectedPriority, 
      assignedAdminId: assignmentFilter,
      search: _searchQuery
    );
    final supportAsync = ref.watch(supportConversationsProvider(filters));
    final statsAsync = ref.watch(supportStatsProvider);

    return AdminLayout(
      title: 'Support Center',
      actions: [
        supportAsync.when(
          data: (conversations) => TextButton.icon(
            onPressed: () => _claimNext(conversations),
            icon: const Icon(Icons.add_task_rounded, color: Colors.white),
            label: const Text('Claim Next', style: TextStyle(color: Colors.white)),
            style: TextButton.styleFrom(backgroundColor: AppColors.success, padding: const EdgeInsets.symmetric(horizontal: 16)),
          ),
          loading: () => const SizedBox(),
          error: (_, __) => const SizedBox(),
        ),
        const SizedBox(width: 16),
      ],
      child: Column(
        children: [
          _buildStatsSummary(statsAsync),
          _buildFilters(),
          Expanded(
            child: supportAsync.when(
              data: (conversations) => _buildConversationList(conversations),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(AsyncValue<Map<String, dynamic>> statsAsync) {
    return statsAsync.when(
      data: (stats) => Container(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            _StatItem(label: 'Waiting Admin', value: stats['waitingAdmin'].toString(), color: AppColors.error),
            const SizedBox(width: 24),
            _StatItem(label: 'Waiting User', value: stats['waitingUser'].toString(), color: AppColors.warning),
            const SizedBox(width: 24),
            _StatItem(label: 'Resolved Today', value: stats['resolved'].toString(), color: AppColors.success),
            const SizedBox(width: 24),
            _StatItem(label: 'Total Open', value: (stats['total'] - stats['resolved']).toString(), color: AppColors.primary),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by user, email, or ID...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            onSubmitted: (val) => setState(() => _searchQuery = val),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown(
                  label: 'Status',
                  value: _selectedStatus,
                  items: ['all', 'waiting_admin', 'waiting_user', 'resolved', 'closed'],
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const SizedBox(width: 12),
                _buildDropdown(
                  label: 'Priority',
                  value: _selectedPriority,
                  items: ['all', 'low', 'normal', 'high', 'urgent'],
                  onChanged: (val) => setState(() => _selectedPriority = val!),
                ),
                const SizedBox(width: 12),
                _buildDropdown(
                  label: 'Assigned',
                  value: _selectedAssignment,
                  items: ['all', 'me', 'unassigned'],
                  onChanged: (val) => setState(() => _selectedAssignment = val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({required String label, required String value, required List<String> items, required Function(String?) onChanged}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          DropdownButton<String>(
            value: value,
            underline: const SizedBox(),
            style: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color),
            items: items.map((i) => DropdownMenuItem(value: i, child: Text(i.replaceAll('_', ' ').toUpperCase(), style: const TextStyle(fontSize: 12)))).toList(),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildConversationList(List<Conversation> conversations) {
    if (conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.grey400),
            const SizedBox(height: 16),
            const Text('No support conversations found.', style: TextStyle(color: AppColors.grey600)),
            if (_searchQuery.isNotEmpty || _selectedStatus != 'all')
              TextButton(
                onPressed: () => setState(() {
                  _searchQuery = '';
                  _selectedStatus = 'all';
                  _selectedAssignment = 'all';
                  _selectedPriority = 'all';
                  _searchController.clear();
                }),
                child: const Text('Clear Filters'),
              ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(24),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final conv = conversations[index];
        return _SupportConversationTile(conversation: conv);
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatItem({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _SupportConversationTile extends ConsumerWidget {
  final Conversation conversation;

  const _SupportConversationTile({required this.conversation});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userId = conversation.participants.firstWhere((p) => p != 'unihub_admin', orElse: () => '');
    final userAsync = ref.watch(userByIdProvider(userId));
    final currentUser = ref.watch(appUserProvider).valueOrNull;

    final isUrgent = conversation.supportPriority == 'urgent';

    return Card(
      elevation: isUrgent ? 2 : 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgent ? AppColors.error : Theme.of(context).dividerColor,
          width: isUrgent ? 2 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => context.push('/admin/support/${conversation.id}', extra: conversation),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              userAsync.when(
                data: (user) => CircleAvatar(
                  radius: 24,
                  backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                  child: user?.photoUrl == null ? const Icon(Icons.person) : null,
                ),
                loading: () => const CircleAvatar(radius: 24, child: CircularProgressIndicator()),
                error: (_, __) => const CircleAvatar(radius: 24, child: Icon(Icons.error)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: userAsync.when(
                            data: (user) => Text(
                              user?.fullName ?? 'Unknown User',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            loading: () => const Text('Loading...'),
                            error: (_, __) => const Text('Error'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: _buildStatusChip(conversation.supportStatus ?? 'active'),
                        ),
                        if (conversation.assignedAdminId != null) ...[
                          const SizedBox(width: 8),
                          Icon(
                            Icons.assignment_ind_rounded, 
                            size: 14, 
                            color: conversation.assignedAdminId == currentUser?.uid ? AppColors.success : AppColors.grey
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      conversation.lastMessage ?? 'No messages',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    DateFormat('MMM dd, HH:mm').format(conversation.lastMessageTime),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  _buildPriorityIndicator(conversation.supportPriority ?? 'normal'),
                ],
              ),
              const SizedBox(width: 16),
              const Icon(Icons.chevron_right, color: AppColors.grey400),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.primary;
    if (status == 'waiting_admin') color = AppColors.error;
    if (status == 'waiting_user') color = AppColors.warning;
    if (status == 'resolved') color = AppColors.success;
    if (status == 'closed') color = AppColors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.replaceAll('_', ' ').toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPriorityIndicator(String priority) {
    Color color = AppColors.grey;
    if (priority == 'high') color = AppColors.warning;
    if (priority == 'urgent') color = AppColors.error;
    if (priority == 'low') color = AppColors.success;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.flag, color: color, size: 14),
        const SizedBox(width: 4),
        Text(priority.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
