import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../../domain/models/organizer.dart';
import '../../domain/models/organizer_member.dart';
import '../../domain/models/event.dart';

class OrganizerDashboardScreen extends ConsumerWidget {
  final String organizerId;

  const OrganizerDashboardScreen({super.key, required this.organizerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final organizerAsync = ref.watch(organizerProvider(organizerId));
    final membersAsync = ref.watch(organizerMembersProvider(organizerId));
    final currentUser = ref.watch(appUserProvider).valueOrNull;

    final myMember = membersAsync.valueOrNull?.firstWhere(
      (m) => m.userId == currentUser?.uid,
      orElse: () => OrganizerMember(id: '', organizerId: '', userId: '', userName: '', role: OrganizerRole.editor, joinedAt: DateTime.now()),
    );
    final isManagement = myMember?.role == OrganizerRole.owner || myMember?.role == OrganizerRole.administrator;

    final isApproved = organizerAsync.valueOrNull?.verificationStatus == OrganizerVerificationStatus.verified || 
                      organizerAsync.valueOrNull?.verificationStatus == OrganizerVerificationStatus.official;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isApproved ? 'Organizer Profile' : 'Organizer Application', 
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          if (isManagement)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                final organizer = organizerAsync.valueOrNull;
                if (organizer != null) {
                  context.push('/organizers/$organizerId/edit', extra: organizer);
                }
              },
            ),
        ],
      ),
      body: organizerAsync.when(
        data: (organizer) {
          if (organizer == null) return const Center(child: Text('Organizer not found'));

          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(organizerProvider(organizerId));
              ref.invalidate(organizerMembersProvider(organizerId));
              ref.invalidate(organizerEventsProvider(organizerId));
            },
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildOverviewCard(context, ref, organizer, isManagement),
                  if (organizer.verificationStatus == OrganizerVerificationStatus.submitted || 
                      organizer.verificationStatus == OrganizerVerificationStatus.underReview ||
                      organizer.verificationStatus == OrganizerVerificationStatus.draft ||
                      organizer.verificationStatus == OrganizerVerificationStatus.suspended)
                    _buildStatusNotice(context, ref, organizer),
                  
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Team Members', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      if (isManagement)
                        TextButton.icon(
                          onPressed: () => _showInviteDialog(context, ref),
                          icon: const Icon(Icons.person_add_outlined),
                          label: const Text('Invite'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildMembersList(context, ref, membersAsync, isManagement, currentUser?.uid),
                  
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Events', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      TextButton.icon(
                        onPressed: () => context.push('/organizers/$organizerId/events'),
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text('Manage'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildEventsSummary(context, ref, organizerId, isManagement),
                  
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: isManagement
          ? FloatingActionButton.extended(
              onPressed: () {
                final organizer = organizerAsync.value;
                if (organizer != null) {
                  context.push(
                    '/organizers/$organizerId/events/create',
                    extra: {'campusId': organizer.campusId},
                  );
                }
              },
              label: const Text('New Event'),
              icon: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildOverviewCard(BuildContext context, WidgetRef ref, Organizer organizer, bool isManagement) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: organizer.logoUrl != null ? NetworkImage(organizer.logoUrl!) : null,
                child: organizer.logoUrl == null ? Text(organizer.name.isNotEmpty ? organizer.name[0].toUpperCase() : 'O', style: const TextStyle(fontSize: 24)) : null,
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(organizer.name, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    Text(organizer.type.name.toUpperCase(), style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              _buildStatusBadge(organizer),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildSimpleStat(context, 'Followers', organizer.followerCount.toString()),
              _buildSimpleStat(context, 'Total Events', organizer.eventCount.toString()),
              _buildSimpleStat(context, 'Trust Score', '${organizer.trustScore.toInt()}%'),
            ],
          ),
          if (isManagement && (organizer.verificationStatus == OrganizerVerificationStatus.draft || 
                              organizer.verificationStatus == OrganizerVerificationStatus.rejected ||
                              organizer.verificationStatus == OrganizerVerificationStatus.withdrawn)) ...[
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _submitForVerification(context, ref, organizer.id),
                child: const Text('Submit for Verification'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusBadge(Organizer organizer) {
    Color color;
    switch (organizer.verificationStatus) {
      case OrganizerVerificationStatus.draft: color = Colors.grey; break;
      case OrganizerVerificationStatus.submitted: color = AppColors.warning; break;
      case OrganizerVerificationStatus.underReview: color = AppColors.primary; break;
      case OrganizerVerificationStatus.verified: color = AppColors.success; break;
      case OrganizerVerificationStatus.official: color = AppColors.primary; break;
      case OrganizerVerificationStatus.rejected: color = AppColors.error; break;
      case OrganizerVerificationStatus.suspended: color = AppColors.error; break;
      case OrganizerVerificationStatus.withdrawn: color = Colors.grey; break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        organizer.verificationStatus.name.toUpperCase(),
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 10),
      ),
    );
  }

  Widget _buildStatusNotice(BuildContext context, WidgetRef ref, Organizer organizer) {
    final status = organizer.verificationStatus;
    final isReviewing = status == OrganizerVerificationStatus.underReview || status == OrganizerVerificationStatus.submitted;
    final isRejected = status == OrganizerVerificationStatus.rejected;
    final isDraft = status == OrganizerVerificationStatus.draft;
    final isSuspended = status == OrganizerVerificationStatus.suspended;
    
    final color = isRejected || isSuspended ? AppColors.error : (isReviewing ? Theme.of(context).colorScheme.primary : Colors.amber);
    
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                isSuspended ? Icons.block_flipped : (isRejected ? Icons.error_outline_rounded : (isReviewing ? Icons.fact_check_rounded : Icons.edit_document)), 
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isSuspended
                    ? 'Your organization has been suspended. Please contact support for more information.'
                    : (isRejected
                        ? 'Your application was not approved. You can edit and resubmit your details for another review.'
                        : (isReviewing 
                            ? 'Your application is currently under review by administrators. You can prepare drafts in the meantime.'
                            : (isDraft ? 'Your application is in draft mode. Please complete and submit it for review.' : 'Your application is pending verification.'))),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          if (isReviewing && organizer.ownerId == ref.watch(appUserProvider).valueOrNull?.uid) ...[
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => _confirmWithdraw(context, ref, organizer.id),
                style: TextButton.styleFrom(foregroundColor: color),
                child: const Text('Withdraw Application', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _confirmWithdraw(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw Application?'),
        content: const Text('Are you sure you want to withdraw your organizer application? You can resubmit it later.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final userId = ref.read(appUserProvider).valueOrNull?.uid ?? '';
              Navigator.pop(dialogContext);
              try {
                await ref.read(organizerServiceProvider).withdrawApplication(id, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Application withdrawn.')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Withdraw', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleStat(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMembersList(BuildContext context, WidgetRef ref, AsyncValue<List<OrganizerMember>> membersAsync, bool isManagement, String? currentUserId) {
    return membersAsync.when(
      data: (members) => ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: members.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final member = members[index];
          final isMe = member.userId == currentUserId;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: CircleAvatar(
              backgroundImage: member.userPhotoUrl != null ? NetworkImage(member.userPhotoUrl!) : null,
              child: member.userPhotoUrl == null ? Text(member.userName.isNotEmpty ? member.userName[0] : '?') : null,
            ),
            title: Text(member.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(member.role.name.toUpperCase(), style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            trailing: isManagement && !isMe && member.role != OrganizerRole.owner
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () => _showMemberOptions(context, ref, member),
                  )
                : null,
          );
        },
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading members'),
    );
  }

  Widget _buildEventsSummary(BuildContext context, WidgetRef ref, String organizerId, bool isManagement) {
    final eventsAsync = ref.watch(organizerEventsProvider(organizerId));
    final theme = Theme.of(context);
    final organizer = ref.watch(organizerProvider(organizerId)).valueOrNull;

    return eventsAsync.when(
      data: (events) {
        if (events.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available_outlined, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4), size: 48),
                const SizedBox(height: 16),
                Text(
                  'No events yet', 
                  style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold)
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your upcoming events will appear here.', 
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey, fontSize: 13)
                ),
                if (isManagement) ...[
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: () => context.push('/organizers/$organizerId/events/create'),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Create Event'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ],
            ),
          );
        }
        
        final activeEvents = events.where((e) => e.status != EventStatus.ended && e.status != EventStatus.archived).toList();
        int totalGoing = 0;
        int totalSaved = 0;
        for (var e in events) {
          totalGoing += e.currentAttendeeCount;
          totalSaved += e.savedCount;
        }

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatPill(context, 'Active', activeEvents.length.toString(), Colors.blue),
                  _buildStatPill(context, 'Drafts', events.where((e) => e.status == EventStatus.draft).length.toString(), Colors.orange),
                  _buildStatPill(context, 'Total', events.length.toString(), Colors.indigo),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSimpleStat(context, 'Total RSVPs', totalGoing.toString()),
                  _buildSimpleStat(context, 'Total Saved', totalSaved.toString()),
                ],
              ),
            ),
          ],
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => const Text('Error loading events'),
    );
  }

  Widget _buildStatPill(BuildContext context, String label, String value, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value, 
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  void _showInviteDialog(BuildContext context, WidgetRef ref) {
    final identifierController = TextEditingController();
    OrganizerRole selectedRole = OrganizerRole.editor;
    bool isInviting = false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite Team Member'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Add members to help manage your organization and events.', style: TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 16),
              TextField(
                controller: identifierController,
                decoration: const InputDecoration(
                  labelText: 'User Email or ID',
                  hintText: 'student@university.edu',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_search_rounded),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Role', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              const SizedBox(height: 8),
              DropdownButtonFormField<OrganizerRole>(
                value: selectedRole,
                items: OrganizerRole.values.where((r) => r != OrganizerRole.owner).map((role) => DropdownMenuItem(
                  value: role,
                  child: Text(role.name.toUpperCase()),
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => selectedRole = val);
                },
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isInviting ? null : () => Navigator.pop(dialogContext), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: isInviting ? null : () async {
                final input = identifierController.text.trim();
                if (input.isEmpty) return;

                setState(() => isInviting = true);
                try {
                  final inviterId = ref.read(appUserProvider).valueOrNull?.uid ?? '';
                  await ref.read(organizerServiceProvider).inviteMember(
                    organizerId, 
                    input, 
                    selectedRole, 
                    inviterId
                  );
                  
                  if (context.mounted) {
                    Navigator.pop(dialogContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Member added successfully!'), backgroundColor: AppColors.success),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    setState(() => isInviting = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString().replaceAll('Exception: ', '')), backgroundColor: AppColors.error),
                    );
                  }
                }
              },
              child: isInviting 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : const Text('Add Member'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMemberOptions(BuildContext context, WidgetRef ref, OrganizerMember member) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.admin_panel_settings_outlined),
              title: const Text('Make Administrator'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref.read(organizerServiceProvider).updateMemberRole(organizerId, ref.read(appUserProvider).valueOrNull?.uid ?? '', member.userId, OrganizerRole.administrator);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Set as Editor'),
              onTap: () async {
                Navigator.pop(context);
                try {
                  await ref.read(organizerServiceProvider).updateMemberRole(organizerId, ref.read(appUserProvider).valueOrNull?.uid ?? '', member.userId, OrganizerRole.editor);
                } catch (e) {
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined, color: AppColors.error),
              title: const Text('Remove from Team', style: TextStyle(color: AppColors.error)),
              onTap: () async {
                Navigator.pop(context);
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Remove Member?'),
                    content: Text('Are you sure you want to remove ${member.userName} from the team?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                );

                if (confirmed == true) {
                  try {
                    await ref.read(organizerServiceProvider).removeMember(organizerId, ref.read(appUserProvider).valueOrNull?.uid ?? '', member.userId);
                  } catch (e) {
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                  }
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _submitForVerification(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Submit for Review?'),
        content: const Text('UniHub admins will review your organizer profile. Once verified, you can publish events to your campus.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final userId = ref.read(appUserProvider).valueOrNull?.uid ?? '';
              final service = ref.read(organizerServiceProvider);
              
              Navigator.pop(dialogContext);
              
              try {
                await service.submitForReview(id, userId);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Submitted successfully!')));
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
}
