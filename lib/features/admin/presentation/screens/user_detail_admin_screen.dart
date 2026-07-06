import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/verification_request.dart';
import '../../domain/models/report.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';

class UserDetailAdminScreen extends ConsumerStatefulWidget {
  final String userId;
  final AppUser? initialUser;

  const UserDetailAdminScreen({
    super.key,
    required this.userId,
    this.initialUser,
  });

  @override
  ConsumerState<UserDetailAdminScreen> createState() => _UserDetailAdminScreenState();
}

class _UserDetailAdminScreenState extends ConsumerState<UserDetailAdminScreen> {
  Map<String, dynamic>? _activityStats;
  List<AdminVerificationRequest>? _verifHistory;
  List<AdminReport>? _reportsReceived;
  List<AdminReport>? _reportsSubmitted;
  bool _isLoadingExtra = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadExtraData();
  }

  Future<void> _loadExtraData() async {
    try {
      final repo = ref.read(adminRepositoryProvider);
      final stats = await repo.getUserActivityStats(widget.userId);
      final history = await repo.getUserVerificationHistory(widget.userId);
      final received = await repo.getUserReports(widget.userId, received: true);
      final submitted = await repo.getUserReports(widget.userId, received: false);

      if (mounted) {
        setState(() {
          _activityStats = stats;
          _verifHistory = history;
          _reportsReceived = received;
          _reportsSubmitted = submitted;
          _isLoadingExtra = false;
        });
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error loading extra user data: $e');
      }
      if (mounted) setState(() => _isLoadingExtra = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 900;

    // Watch the specific user to get real-time updates
    final usersAsync = ref.watch(adminUsersProvider((
      search: widget.userId,
      isBanned: null,
      isSuspended: null,
      isVerified: null,
      role: null,
      university: null,
      sortBy: 'name',
      descending: false,
      startDate: null,
      endDate: null,
    )));

    return AdminLayout(
      title: 'User Details',
      child: usersAsync.when(
        data: (users) {
          final user = users.firstWhere((u) => u.uid == widget.userId, orElse: () => users.isNotEmpty ? users.first : widget.initialUser!);
          return _buildContent(user, isMobile);
        },
        loading: () => widget.initialUser != null 
          ? _buildContent(widget.initialUser!, isMobile) 
          : const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
    );
  }

  Widget _buildContent(AppUser user, bool isMobile) {
    final mainContent = Column(
      children: [
        _buildSectionCard(
          title: 'User Information',
          child: _buildInfoGrid(user),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Platform Activity',
          child: _buildActivityDetails(user),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Verification History',
          child: _buildVerificationHistory(),
        ),
      ],
    );

    final sideContent = Column(
      children: [
        _buildSectionCard(
          title: 'Management Actions',
          child: _buildActions(user),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Moderation Record',
          child: _buildModerationRecord(),
        ),
        const SizedBox(height: 24),
        _buildSectionCard(
          title: 'Administrative Notes',
          child: _buildAdminNotes(user),
        ),
      ],
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(user),
          const SizedBox(height: 24),
          _buildQuickStats(user),
          const SizedBox(height: 24),
          if (user.isRestricted) ...[
            _buildModerationStatus(user),
            const SizedBox(height: 24),
          ],
          if (isMobile) ...[
            mainContent,
            const SizedBox(height: 24),
            sideContent,
          ] else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 2, child: mainContent),
                const SizedBox(width: 24),
                Expanded(flex: 1, child: sideContent),
              ],
            ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(height: 32),
            child,
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AppUser user) {
    return Row(
      children: [
        IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
        const SizedBox(width: 8),
        _buildAvatar(user, radius: 40),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      user.fullName,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (user.isVerified) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.verified, color: AppColors.primary),
                  ],
                ],
              ),
              Text(
                '${user.email} • ID: ${user.uid}',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14),
              ),
              const SizedBox(height: 8),
              Row(
                children: user.roles.map((role) => Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _getRoleColor(role).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    role.toUpperCase(),
                    style: TextStyle(color: _getRoleColor(role), fontSize: 10, fontWeight: FontWeight.bold),
                  ),
                )).toList(),
              ),
            ],
          ),
        ),
        _buildLastActive(user),
      ],
    );
  }

  Widget _buildLastActive(AppUser user) {
    if (user.lastSeen == null) return const SizedBox();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Text('Last Active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        Text(
          DateFormat('MMM dd, HH:mm').format(user.lastSeen!),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAvatar(AppUser user, {double radius = 24}) {
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppColors.primary.withOpacity(0.1),
      backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
      child: user.photoUrl == null
          ? Text(
              user.fullName.substring(0, 1).toUpperCase(),
              style: TextStyle(color: AppColors.primary, fontSize: radius * 0.8, fontWeight: FontWeight.bold),
            )
          : null,
    );
  }

  Widget _buildQuickStats(AppUser user) {
    return Row(
      children: [
        _StatCard(label: 'Trust Score', value: user.trustScore.toStringAsFixed(0), color: AppColors.success),
        const SizedBox(width: 12),
        _StatCard(label: 'Total Reports', value: _activityStats?['reportsReceived']?.toString() ?? '...', color: AppColors.error),
        const SizedBox(width: 12),
        _StatCard(label: 'Deal Rating', value: user.averageRating.toStringAsFixed(1), color: Colors.amber),
        const SizedBox(width: 12),
        _StatCard(label: 'Tier', value: user.tier.toUpperCase(), color: Colors.purple),
      ],
    );
  }

  Widget _buildActivityDetails(AppUser user) {
    if (_isLoadingExtra) return const Center(child: CircularProgressIndicator());
    
    return Column(
      children: [
        _ActivityTile(
          icon: Icons.shopping_bag,
          label: 'Marketplace Listings',
          count: _activityStats?['listingsCount'] ?? 0,
          onTap: () => context.push('/admin/marketplace', extra: {'userId': user.uid}),
        ),
        const Divider(),
        _ActivityTile(
          icon: Icons.home,
          label: 'Housing Listings',
          count: _activityStats?['housingCount'] ?? 0,
          onTap: () => context.push('/admin/housing', extra: {'userId': user.uid}),
        ),
        const Divider(),
        _ActivityTile(
          icon: Icons.description,
          label: 'Shared Notes',
          count: _activityStats?['notesCount'] ?? 0,
          onTap: () => context.push('/admin/notes', extra: {'userId': user.uid}),
        ),
      ],
    );
  }

  Widget _buildVerificationHistory() {
    if (_isLoadingExtra) return const Center(child: CircularProgressIndicator());
    if (_verifHistory == null || _verifHistory!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Text('No verification requests found.', style: TextStyle(color: Colors.grey)),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _verifHistory!.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        final req = _verifHistory![index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(req.type.name.toUpperCase()),
          subtitle: Text(DateFormat('MMM dd, yyyy').format(req.submittedAt)),
          trailing: _buildVerifStatusChip(req.status),
          onTap: () => context.push('/admin/verifications/${req.id}', extra: req),
        );
      },
    );
  }

  Widget _buildVerifStatusChip(AdminVerificationStatus status) {
    Color color = AppColors.grey;
    if (status == AdminVerificationStatus.approved) color = AppColors.success;
    if (status == AdminVerificationStatus.rejected) color = AppColors.error;
    if (status == AdminVerificationStatus.pending) color = AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildModerationRecord() {
    if (_isLoadingExtra) return const Center(child: CircularProgressIndicator());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RecordItem(label: 'Reports Received', count: _reportsReceived?.length ?? 0, color: AppColors.error),
        _RecordItem(label: 'Reports Submitted', count: _reportsSubmitted?.length ?? 0, color: AppColors.primary),
        const SizedBox(height: 16),
        if (_reportsReceived != null && _reportsReceived!.isNotEmpty) ...[
          const Text('Recent Reports Received:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ..._reportsReceived!.take(3).map((r) => ListTile(
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: Text(r.reason, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(DateFormat('MMM dd').format(r.createdAt)),
            trailing: const Icon(Icons.chevron_right, size: 16),
            onTap: () => context.push('/admin/reports/${r.id}', extra: r),
          )),
        ],
      ],
    );
  }

  Widget _buildAdminNotes(AppUser user) {
    return Column(
      children: [
        ElevatedButton.icon(
          onPressed: () => _showAddNoteDialog(user),
          icon: const Icon(Icons.add_comment, size: 18),
          label: const Text('Add Internal Note'),
          style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 40)),
        ),
        const SizedBox(height: 16),
        const Text('Note: Moderation history and internal logs are stored securely.', 
          style: TextStyle(fontSize: 10, color: Colors.grey, fontStyle: FontStyle.italic)),
      ],
    );
  }

  Widget _buildActions(AppUser user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isProcessing)
          const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ))
        else ...[
          _ActionButton(
            label: user.isBanned ? 'Restore Account' : 'Ban Permanently',
            icon: Icons.gavel,
            color: AppColors.error,
            onPressed: () => _showBanDialog(user),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: user.isCurrentlySuspended ? 'Remove Suspension' : 'Suspend Account',
            icon: Icons.timer,
            color: AppColors.warning,
            onPressed: () => _showSuspendDialog(user),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Edit User Roles',
            icon: Icons.admin_panel_settings,
            color: Colors.purple,
            onPressed: () => _showRolesDialog(user),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Reset Verification',
            icon: Icons.refresh,
            color: AppColors.primary,
            onPressed: () => _showResetVerifDialog(user),
          ),
          const SizedBox(height: 12),
          _ActionButton(
            label: 'Adjust Trust Score',
            icon: Icons.star,
            color: AppColors.success,
            onPressed: () => _showTrustScoreDialog(user),
          ),
        ],
      ],
    );
  }

  void _showResetVerifDialog(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reset Verification?'),
        content: Text('This will remove all verification badges and roles for ${user.fullName}. They will need to re-verify.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_isProcessing) return;
              final admin = ref.read(appUserProvider).valueOrNull;
              if (admin == null) return;
              
              final navigator = Navigator.of(context);
              setState(() => _isProcessing = true);
              
              try {
                await ref.read(adminRepositoryProvider).resetUserVerification(
                  user.uid,
                  adminId: admin.uid,
                  adminName: admin.fullName,
                );
              } finally {
                if (mounted) setState(() => _isProcessing = false);
                navigator.pop();
              }
            },
            child: const Text('Confirm Reset'),
          ),
        ],
      ),
    );
  }

  void _showAddNoteDialog(AppUser user) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add Admin Note'),
        content: TextField(
          controller: noteController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter internal administrative note...'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_isProcessing) return;
              final admin = ref.read(appUserProvider).valueOrNull;
              if (admin == null) return;
              
              final navigator = Navigator.of(context);
              if (noteController.text.isNotEmpty) {
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminRepositoryProvider).addAdminNote(user.uid, noteController.text, admin.uid);
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              }
              navigator.pop();
            },
            child: const Text('Save Note'),
          ),
        ],
      ),
    );
  }

  void _showTrustScoreDialog(AppUser user) {
    final scoreController = TextEditingController(text: user.trustScore.toStringAsFixed(0));
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Adjust Trust Score'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Manual adjustments will override calculated scores.'),
            const SizedBox(height: 12),
            TextField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Score (0-100)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (_isProcessing) return;
              final admin = ref.read(appUserProvider).valueOrNull;
              if (admin == null) return;
              
              final navigator = Navigator.of(context);
              final score = double.tryParse(scoreController.text);
              if (score != null) {
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminServiceProvider).updateUserTrustScore(
                    user.uid, 
                    score,
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
              }
              navigator.pop();
            },
            child: const Text('Save Score'),
          ),
        ],
      ),
    );
  }

  void _showBanDialog(AppUser user) {
    if (user.isBanned) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Restore Account?'),
          content: Text('Are you sure you want to lift the ban for ${user.fullName}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (_isProcessing) return;
                final admin = ref.read(appUserProvider).valueOrNull;
                if (admin == null) return;

                final navigator = Navigator.of(context);
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminServiceProvider).toggleUserBan(
                    user.uid, 
                    false,
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
                navigator.pop();
              },
              child: const Text('Restore Account'),
            ),
          ],
        ),
      );
    } else {
      final reasonController = TextEditingController();
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ban Permanently'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Enter reason for banning ${user.fullName}:'),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'e.g. Repeated scam attempts'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                if (_isProcessing) return;
                final admin = ref.read(appUserProvider).valueOrNull;
                if (admin == null) return;

                final navigator = Navigator.of(context);
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminServiceProvider).toggleUserBan(
                    user.uid, 
                    true, 
                    reason: reasonController.text,
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
                navigator.pop();
              },
              child: const Text('Ban Permanently', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
    }
  }

  void _showSuspendDialog(AppUser user) {
    if (user.isCurrentlySuspended) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Remove Suspension?'),
          content: Text('Lift current suspension for ${user.fullName}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (_isProcessing) return;
                final admin = ref.read(appUserProvider).valueOrNull;
                if (admin == null) return;

                final navigator = Navigator.of(context);
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminServiceProvider).suspendUser(
                    user.uid, 
                    DateTime.now().subtract(const Duration(days: 1)), 
                    'Suspension lifted by admin',
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
                navigator.pop();
              },
              child: const Text('Lift Suspension'),
            ),
          ],
        ),
      );
      return;
    }

    final reasonController = TextEditingController();
    int days = 7;
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Suspend User'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Suspend ${user.fullName} for:'),
              DropdownButton<int>(
                value: days,
                isExpanded: true,
                items: [3, 7, 14, 30, 90].map((d) => DropdownMenuItem(value: d, child: Text('$d Days'))).toList(),
                onChanged: (val) => setDialogState(() => days = val!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(hintText: 'Reason for suspension'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (_isProcessing) return;
                final admin = ref.read(appUserProvider).valueOrNull;
                if (admin == null) return;

                final navigator = Navigator.of(context);
                final until = DateTime.now().add(Duration(days: days));
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminServiceProvider).suspendUser(
                    user.uid, 
                    until, 
                    reasonController.text,
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
                navigator.pop();
              },
              child: const Text('Suspend'),
            ),
          ],
        ),
      ),
    );
  }

  void _showRolesDialog(AppUser user) {
    List<String> currentRoles = List.from(user.roles);
    const availableRoles = ['student', 'admin', 'housing_plug', 'seller'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage User Roles'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: availableRoles.map((role) => CheckboxListTile(
              title: Text(role.toUpperCase()),
              value: currentRoles.contains(role),
              onChanged: (val) {
                setDialogState(() {
                  if (val == true) {
                    currentRoles.add(role);
                  } else {
                    currentRoles.remove(role);
                  }
                });
              },
            )).toList(),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (_isProcessing) return;
                final admin = ref.read(appUserProvider).valueOrNull;
                if (admin == null) return;

                final navigator = Navigator.of(context);
                setState(() => _isProcessing = true);
                try {
                  await ref.read(adminRepositoryProvider).updateUserRoles(
                    user.uid, 
                    currentRoles,
                    adminId: admin.uid,
                    adminName: admin.fullName,
                  );
                } finally {
                  if (mounted) setState(() => _isProcessing = false);
                }
                navigator.pop();
              },
              child: const Text('Update Roles'),
            ),
          ],
        ),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin': return Colors.purple;
      case 'student': return AppColors.primary;
      case 'housing_plug': return Colors.orange;
      case 'seller': return Colors.green;
      default: return AppColors.grey600;
    }
  }

  Widget _buildInfoGrid(AppUser user) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.of(context).size.width < 600 ? 1 : 2,
      mainAxisExtent: 64,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        _InfoTile(label: 'Username', value: user.username ?? 'N/A'),
        _InfoTile(label: 'University', value: user.university ?? 'N/A'),
        _InfoTile(label: 'Campus', value: user.campus ?? 'N/A'),
        _InfoTile(label: 'Course', value: user.course ?? 'N/A'),
        _InfoTile(label: 'Year', value: user.yearOfStudy ?? 'N/A'),
        _InfoTile(label: 'Joined', value: user.createdAt != null ? DateFormat('MMM dd, yyyy').format(user.createdAt!) : 'N/A'),
        _InfoTile(label: 'ID Verified', value: user.isIdentityVerified ? 'YES' : 'NO'),
        _InfoTile(label: 'Student Verified', value: user.isStudentVerified ? 'YES' : 'NO'),
      ],
    );
  }

  Widget _buildModerationStatus(AppUser user) {
    if (user.isBanned) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.error.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.gavel, color: AppColors.error),
                SizedBox(width: 8),
                Text('ACCOUNT BANNED', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Reason: ${user.banReason ?? "Not specified"}', style: const TextStyle(color: AppColors.error)),
          ],
        ),
      );
    }

    if (user.isCurrentlySuspended) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.warning.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.warning.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.timer, color: AppColors.warning),
                SizedBox(width: 8),
                Text('ACCOUNT SUSPENDED', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 8),
            Text('Until: ${DateFormat('MMM dd, yyyy').format(user.suspendedUntil!)}', 
              style: const TextStyle(color: AppColors.warning)),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }
}

class _ActivityTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final VoidCallback onTap;

  const _ActivityTile({required this.icon, required this.label, required this.count, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.primary),
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(count.toString(), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(width: 8),
          const Icon(Icons.chevron_right, size: 16),
        ],
      ),
      onTap: onTap,
    );
  }
}

class _RecordItem extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _RecordItem({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(count.toString(), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCard({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 12, color: color.withOpacity(0.8))),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(label, 
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10, 
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Text(value, 
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold), 
              maxLines: 1, 
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
