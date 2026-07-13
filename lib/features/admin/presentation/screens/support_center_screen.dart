import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../chat/domain/models/conversation.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../../core/constants/campus_constants.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';
import '../controllers/support_center_controller.dart';

class SupportCenterScreen extends ConsumerWidget {
  const SupportCenterScreen({super.key});

  Future<void> _claimNext(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final conversationId = await ref.read(supportCenterFiltersProvider.notifier).claimNext();

    if (conversationId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No pending tickets waiting for admin assistance.')),
      );
      return;
    }

    if (context.mounted) {
      context.push('/admin/support/$conversationId');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final supportAsync = ref.watch(filteredSupportConversationsProvider);
    final statsAsync = ref.watch(supportStatsProvider);
    final filters = ref.watch(supportCenterFiltersProvider);
    final controller = ref.read(supportCenterFiltersProvider.notifier);

    return AdminLayout(
      title: 'Support Center',
      actions: [
        TextButton.icon(
          onPressed: () => _claimNext(context, ref),
          icon: const Icon(Icons.add_task_rounded, color: Colors.white),
          label: const Text('Claim Next', style: TextStyle(color: Colors.white)),
          style: TextButton.styleFrom(
            backgroundColor: AppColors.success, 
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
        ),
        const SizedBox(width: 16),
      ],
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildStatsSummary(statsAsync)),
          SliverToBoxAdapter(child: _buildFilters(context, filters, controller)),
          supportAsync.when(
            data: (conversations) => _buildSliverConversationList(context, conversations, controller),
            loading: () => const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
            error: (err, _) => SliverFillRemaining(child: Center(child: Text('Error: $err'))),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSummary(AsyncValue<Map<String, dynamic>> statsAsync) {
    return statsAsync.when(
      data: (stats) => Container(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE TICKET OVERVIEW',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.2,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final crossAxisCount = constraints.maxWidth > 900 ? 4 : (constraints.maxWidth > 600 ? 2 : 2);
                return GridView.count(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: constraints.maxWidth > 900 ? 2.2 : 1.6,
                  children: [
                    _StatItem(
                      label: 'NEEDS ATTENTION',
                      subLabel: 'Waiting Admin',
                      value: stats['waitingAdmin'].toString(),
                      color: AppColors.error,
                      icon: Icons.priority_high_rounded,
                    ),
                    _StatItem(
                      label: 'PENDING USER',
                      subLabel: 'Waiting Resp',
                      value: stats['waitingUser'].toString(),
                      color: AppColors.warning,
                      icon: Icons.hourglass_empty_rounded,
                    ),
                    _StatItem(
                      label: 'RESOLVED',
                      subLabel: 'Closed Today',
                      value: stats['resolved'].toString(),
                      color: AppColors.success,
                      icon: Icons.task_alt_rounded,
                    ),
                    _StatItem(
                      label: 'TOTAL TICKETS',
                      subLabel: 'All Sessions',
                      value: stats['total'].toString(),
                      color: AppColors.primary,
                      icon: Icons.analytics_rounded,
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
      loading: () => const SizedBox(height: 100, child: Center(child: LinearProgressIndicator())),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildSliverConversationList(BuildContext context, List<Conversation> conversations, SupportCenterController controller) {
    if (conversations.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.chat_bubble_outline, size: 64, color: AppColors.grey400),
              const SizedBox(height: 16),
              const Text('No support conversations found.', style: TextStyle(color: AppColors.grey600)),
              TextButton(
                onPressed: () => controller.clearFilters(),
                child: const Text('Clear Filters'),
              ),
            ],
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.all(24),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final conv = conversations[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SupportConversationTile(conversation: conv),
            );
          },
          childCount: conversations.length,
        ),
      ),
    );
  }

  Widget _buildFilters(BuildContext context, SupportCenterFilters filters, SupportCenterController controller) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          TextField(
            onChanged: (val) => controller.setSearch(val),
            decoration: InputDecoration(
              hintText: 'Search by user, email, or ID...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDropdown(
                  context,
                  label: 'Status',
                  value: filters.status,
                  items: ['all', 'waiting_admin', 'waiting_user', 'resolved', 'closed'],
                  onChanged: (val) => controller.setStatus(val!),
                ),
                const SizedBox(width: 12),
                _buildDropdown(
                  context,
                  label: 'Priority',
                  value: filters.priority,
                  items: ['all', 'low', 'normal', 'high', 'urgent'],
                  onChanged: (val) => controller.setPriority(val!),
                ),
                const SizedBox(width: 12),
                _buildDropdown(
                  context,
                  label: 'Assigned',
                  value: filters.assignment,
                  items: ['all', 'me', 'unassigned'],
                  onChanged: (val) => controller.setAssignment(val!),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown(BuildContext context, {required String label, required String value, required List<String> items, required Function(String?) onChanged}) {
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

}

class _StatItem extends StatelessWidget {
  final String label;
  final String subLabel;
  final String value;
  final Color color;
  final IconData icon;

  const _StatItem({
    required this.label,
    required this.subLabel,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.1),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned(
              right: -10,
              top: -10,
              child: Icon(
                icon,
                size: 60,
                color: color.withOpacity(0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: color, size: 14),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 8,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subLabel,
                    style: TextStyle(
                      fontSize: 9,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
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
    final isWaiting = conversation.supportStatus == 'waiting_admin';
    
    // Priority-based accent color
    Color priorityColor = AppColors.grey;
    if (conversation.supportPriority == 'high') priorityColor = AppColors.warning;
    if (conversation.supportPriority == 'urgent') priorityColor = AppColors.error;
    if (conversation.supportPriority == 'low') priorityColor = AppColors.success;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isWaiting ? priorityColor.withOpacity(0.3) : Theme.of(context).dividerColor),
        boxShadow: [
          if (isWaiting) 
            BoxShadow(color: priorityColor.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
          else
            BoxShadow(color: Colors.black.withOpacity(0.01), blurRadius: 5, offset: const Offset(0, 2)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Left Accent Bar
              Container(
                width: 6,
                color: priorityColor,
              ),
              Expanded(
                child: InkWell(
                  onTap: () => context.push('/admin/support/${conversation.id}', extra: conversation),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildAvatarStack(userAsync),
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
                                            user?.fullName ?? 'Unknown Student',
                                            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          loading: () => const Text('Loading user...', style: TextStyle(fontSize: 15)),
                                          error: (_, __) => const Text('User Error', style: TextStyle(fontSize: 15)),
                                        ),
                                      ),
                                      _buildRelativeTime(conversation.lastMessageTime),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  userAsync.when(
                                    data: (user) => Text(
                                      user?.university != null ? CampusConstants.getDisplayName(user!.university) : 'New Member',
                                      style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w500),
                                    ),
                                    loading: () => const SizedBox.shrink(),
                                    error: (_, __) => const SizedBox.shrink(),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    conversation.lastMessage ?? 'No messages yet',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.onSurfaceVariant, 
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        const Divider(height: 1),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _buildModernStatusChip(conversation.supportStatus ?? 'waiting_admin'),
                            const SizedBox(width: 8),
                            _buildModernPriorityIndicator(conversation.supportPriority ?? 'normal'),
                            const Spacer(),
                            if (conversation.assignedAdminId != null)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: (conversation.assignedAdminId == currentUser?.uid ? AppColors.success : AppColors.grey).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.assignment_ind_rounded, 
                                      size: 12, 
                                      color: conversation.assignedAdminId == currentUser?.uid ? AppColors.success : AppColors.grey600
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      conversation.assignedAdminId == currentUser?.uid ? 'ME' : 'ASSIGNED',
                                      style: TextStyle(
                                        fontSize: 9, 
                                        fontWeight: FontWeight.w900, 
                                        color: conversation.assignedAdminId == currentUser?.uid ? AppColors.success : AppColors.grey600
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            else
                              const Text('UNASSIGNED', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.grey, letterSpacing: 0.5)),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right_rounded, size: 20, color: Colors.grey),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarStack(AsyncValue<AppUser?> userAsync) {
    return userAsync.when(
      data: (user) => Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
            child: user?.photoUrl == null ? const Icon(Icons.person, color: AppColors.primary) : null,
          ),
          if (user?.isVerified == true)
            Positioned(
              right: -2,
              bottom: -2,
              child: Container(
                padding: const EdgeInsets.all(2),
                decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                child: const Icon(Icons.verified_rounded, color: AppColors.primary, size: 14),
              ),
            ),
        ],
      ),
      loading: () => const CircleAvatar(radius: 24, child: CircularProgressIndicator(strokeWidth: 2)),
      error: (_, __) => const CircleAvatar(radius: 24, child: Icon(Icons.error_outline)),
    );
  }

  Widget _buildRelativeTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    String text;
    
    if (diff.inMinutes < 1) {
      text = 'Just now';
    } else if (diff.inMinutes < 60) {
      text = '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      text = '${diff.inHours}h ago';
    } else {
      text = DateFormat('MMM d').format(time);
    }

    return Text(
      text,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey),
    );
  }

  Widget _buildModernStatusChip(String status) {
    Color color = AppColors.primary;
    String label = status.replaceAll('_', ' ').toUpperCase();
    
    if (status == 'waiting_admin') color = AppColors.error;
    if (status == 'waiting_user') color = AppColors.warning;
    if (status == 'resolved') color = AppColors.success;
    if (status == 'closed') color = AppColors.grey;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w900, letterSpacing: 0.3),
      ),
    );
  }

  Widget _buildModernPriorityIndicator(String priority) {
    Color color = AppColors.grey;
    if (priority == 'high') color = AppColors.warning;
    if (priority == 'urgent') color = AppColors.error;
    if (priority == 'low') color = AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            priority.toUpperCase(),
            style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
