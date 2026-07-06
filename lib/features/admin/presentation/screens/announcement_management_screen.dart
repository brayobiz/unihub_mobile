import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../announcements/domain/models/announcement.dart';
import '../../../announcements/shared/providers.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../layout/admin_layout.dart';

class AnnouncementManagementScreen extends ConsumerStatefulWidget {
  const AnnouncementManagementScreen({super.key});

  @override
  ConsumerState<AnnouncementManagementScreen> createState() => _AnnouncementManagementScreenState();
}

class _AnnouncementManagementScreenState extends ConsumerState<AnnouncementManagementScreen> {
  AnnouncementStatus? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final announcementsAsync = ref.watch(allAnnouncementsProvider);

    return AdminLayout(
      title: 'Announcement Center',
      child: Column(
        children: [
          _buildStats(announcementsAsync),
          _buildFilters(),
          Expanded(
            child: announcementsAsync.when(
              data: (announcements) {
                var filtered = announcements;
                if (_filterStatus != null) {
                  filtered = filtered.where((a) => a.status == _filterStatus).toList();
                }

                if (filtered.isEmpty) {
                  return const Center(child: Text('No announcements found'));
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(24),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) => _AnnouncementCard(announcement: filtered[index]),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
      // Action button to create new
    );
  }

  Widget _buildStats(AsyncValue<List<Announcement>> asyncData) {
    return asyncData.when(
      data: (items) {
        final active = items.where((a) => a.status == AnnouncementStatus.published && 
            a.publishAt.isBefore(DateTime.now()) && 
            (a.expiresAt == null || a.expiresAt!.isAfter(DateTime.now()))).length;
        final drafts = items.where((a) => a.status == AnnouncementStatus.draft).length;
        final scheduled = items.where((a) => a.status == AnnouncementStatus.scheduled || 
            (a.status == AnnouncementStatus.published && a.publishAt.isAfter(DateTime.now()))).length;

        return Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            children: [
              _StatCard(label: 'Active', value: active.toString(), color: AppColors.success),
              const SizedBox(width: 24),
              _StatCard(label: 'Scheduled', value: scheduled.toString(), color: AppColors.primary),
              const SizedBox(width: 24),
              _StatCard(label: 'Drafts', value: drafts.toString(), color: AppColors.grey600),
            ],
          ),
        );
      },
      loading: () => const SizedBox(height: 100),
      error: (_, __) => const SizedBox(),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      color: Theme.of(context).cardColor,
      child: Row(
        children: [
          DropdownButton<AnnouncementStatus?>(
            value: _filterStatus,
            hint: const Text('Filter by Status'),
            items: [
              const DropdownMenuItem(value: null, child: Text('All Statuses')),
              ...AnnouncementStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))),
            ],
            onChanged: (val) => setState(() => _filterStatus = val),
          ),
          const Spacer(),
          ElevatedButton.icon(
            onPressed: () => _showCreateEditDialog(),
            icon: const Icon(Icons.add),
            label: const Text('New Announcement'),
          ),
        ],
      ),
    );
  }

  void _showCreateEditDialog([Announcement? announcement]) {
    showDialog(
      context: context,
      builder: (context) => _AnnouncementEditDialog(announcement: announcement),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
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

class _AnnouncementCard extends ConsumerWidget {
  final Announcement announcement;

  const _AnnouncementCard({required this.announcement});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isActive = announcement.status == AnnouncementStatus.published && 
        announcement.publishAt.isBefore(DateTime.now()) && 
        (announcement.expiresAt == null || announcement.expiresAt!.isAfter(DateTime.now()));

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: theme.dividerColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildPriorityBadge(announcement.priority),
                const SizedBox(width: 8),
                _buildStatusBadge(announcement.status, isActive),
                const Spacer(),
                Text(
                  'ID: ${announcement.id.substring(0, 8)}',
                  style: theme.textTheme.bodySmall?.copyWith(color: AppColors.grey500),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(announcement.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 4),
            Text(
              announcement.content,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _InfoChip(icon: Icons.layers, label: announcement.type.name.toUpperCase()),
                if (announcement.type == AnnouncementType.featureSpecific) ...[
                  const SizedBox(width: 8),
                  _InfoChip(icon: Icons.extension, label: announcement.targetFeatures.join(', ')),
                ],
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () {
                     showDialog(
                      context: context,
                      builder: (context) => _AnnouncementEditDialog(announcement: announcement),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.error),
                  onPressed: () => _confirmDelete(context, ref),
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Text(
                  'Published: ${DateFormat('MMM dd, HH:mm').format(announcement.publishAt)}',
                  style: theme.textTheme.bodySmall,
                ),
                if (announcement.expiresAt != null) ...[
                  const SizedBox(width: 16),
                  Text(
                    'Expires: ${DateFormat('MMM dd, HH:mm').format(announcement.expiresAt!)}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: announcement.expiresAt!.isBefore(DateTime.now()) ? AppColors.error : null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              await ref.read(announcementRepositoryProvider).deleteAnnouncement(announcement.id);
              navigator.pop();
            },
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityBadge(AnnouncementPriority priority) {
    Color color = AppColors.primary;
    if (priority == AnnouncementPriority.critical) color = AppColors.error;
    if (priority == AnnouncementPriority.high) color = AppColors.warning;
    if (priority == AnnouncementPriority.low) color = AppColors.success;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(priority.name.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildStatusBadge(AnnouncementStatus status, bool isActive) {
    Color color = AppColors.grey600;
    String label = status.name.toUpperCase();
    
    if (status == AnnouncementStatus.published) {
      if (isActive) {
        color = AppColors.success;
        label = 'ACTIVE';
      } else {
        color = AppColors.primary;
        label = 'SCHEDULED';
      }
    } else if (status == AnnouncementStatus.draft) {
      color = AppColors.grey500;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(0.5),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: AppColors.grey600),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppColors.grey600)),
        ],
      ),
    );
  }
}

class _AnnouncementEditDialog extends ConsumerStatefulWidget {
  final Announcement? announcement;

  const _AnnouncementEditDialog({this.announcement});

  @override
  ConsumerState<_AnnouncementEditDialog> createState() => _AnnouncementEditDialogState();
}

class _AnnouncementEditDialogState extends ConsumerState<_AnnouncementEditDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _contentController;
  late AnnouncementType _type;
  late AnnouncementDisplayStyle _displayStyle;
  late AnnouncementPriority _priority;
  late AnnouncementStatus _status;
  late DateTime _publishAt;
  DateTime? _expiresAt;
  List<String> _targetFeatures = [];
  
  // Audience
  bool _verifiedOnly = false;
  String _university = 'All';
  List<String> _selectedRoles = [];

  @override
  void initState() {
    super.initState();
    final a = widget.announcement;
    _titleController = TextEditingController(text: a?.title ?? '');
    _contentController = TextEditingController(text: a?.content ?? '');
    _type = a?.type ?? AnnouncementType.global;
    _displayStyle = a?.displayStyle ?? AnnouncementDisplayStyle.banner;
    _priority = a?.priority ?? AnnouncementPriority.normal;
    _status = a?.status ?? AnnouncementStatus.draft;
    _publishAt = a?.publishAt ?? DateTime.now();
    _expiresAt = a?.expiresAt;
    _targetFeatures = List.from(a?.targetFeatures ?? []);
    
    _verifiedOnly = a?.targetAudience['verifiedOnly'] ?? false;
    _university = a?.targetAudience['university'] ?? 'All';
    _selectedRoles = List.from(a?.targetAudience['roles'] ?? []);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final admin = ref.read(authStateProvider).valueOrNull;
    if (admin == null) return;

    final id = widget.announcement?.id ?? const Uuid().v4();
    final now = DateTime.now();

    final announcement = Announcement(
      id: id,
      title: _titleController.text,
      content: _contentController.text,
      type: _type,
      targetFeatures: _targetFeatures,
      targetAudience: {
        'verifiedOnly': _verifiedOnly,
        'university': _university,
        'roles': _selectedRoles,
      },
      displayStyle: _displayStyle,
      priority: _priority,
      status: _status,
      publishAt: _publishAt,
      expiresAt: _expiresAt,
      createdBy: admin.uid,
      createdAt: widget.announcement?.createdAt ?? now,
      updatedAt: now,
    );

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin not logged in');

      await ref.read(adminServiceProvider).publishAnnouncement(
        announcement, 
        adminId: admin.uid, 
        adminName: admin.fullName,
      );
      if (mounted) messenger.showSnackBar(const SnackBar(content: Text('Announcement saved successfully')));
      if (mounted) navigator.pop();
    } catch (e) {
      if (mounted) messenger.showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.announcement == null ? 'New Announcement' : 'Edit Announcement'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _contentController,
                decoration: const InputDecoration(labelText: 'Content'),
                maxLines: 3,
                validator: (v) => v?.isEmpty == true ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              const Text('Targeting', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              DropdownButtonFormField<AnnouncementType>(
                value: _type,
                decoration: const InputDecoration(labelText: 'Type'),
                items: AnnouncementType.values.map((t) => DropdownMenuItem(value: t, child: Text(t.name.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _type = val!),
              ),
              if (_type == AnnouncementType.featureSpecific) ...[
                const SizedBox(height: 16),
                const Text('Target Features', style: TextStyle(fontSize: 12)),
                Wrap(
                  spacing: 8,
                  children: ['marketplace', 'housing', 'notes', 'chat', 'profile'].map((f) {
                    final isSelected = _targetFeatures.contains(f);
                    return FilterChip(
                      label: Text(f, style: const TextStyle(fontSize: 12)),
                      selected: isSelected,
                      onSelected: (val) {
                        setState(() {
                          if (val) _targetFeatures.add(f);
                          else _targetFeatures.remove(f);
                        });
                      },
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 24),
              const Text('Presentation', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<AnnouncementDisplayStyle>(
                      value: _displayStyle,
                      decoration: const InputDecoration(labelText: 'Display Style'),
                      items: AnnouncementDisplayStyle.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _displayStyle = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: DropdownButtonFormField<AnnouncementPriority>(
                      value: _priority,
                      decoration: const InputDecoration(labelText: 'Priority'),
                      items: AnnouncementPriority.values.map((p) => DropdownMenuItem(value: p, child: Text(p.name.toUpperCase()))).toList(),
                      onChanged: (val) => setState(() => _priority = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text('Audience', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              SwitchListTile(
                title: const Text('Verified Users Only', style: TextStyle(fontSize: 14)),
                value: _verifiedOnly,
                onChanged: (val) => setState(() => _verifiedOnly = val),
              ),
              DropdownButtonFormField<String>(
                value: _university,
                decoration: const InputDecoration(labelText: 'University'),
                items: ['All', 'University of Nairobi', 'Kenyatta University', 'Strathmore', 'Jkuat', 'USIU']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                onChanged: (val) => setState(() => _university = val!),
              ),
              const SizedBox(height: 24),
              const Text('Scheduling', style: TextStyle(fontWeight: FontWeight.bold)),
              const Divider(),
              DropdownButtonFormField<AnnouncementStatus>(
                value: _status,
                decoration: const InputDecoration(labelText: 'Status'),
                items: AnnouncementStatus.values.map((s) => DropdownMenuItem(value: s, child: Text(s.name.toUpperCase()))).toList(),
                onChanged: (val) => setState(() => _status = val!),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Publish At', style: TextStyle(fontSize: 14)),
                subtitle: Text(DateFormat('MMM dd, yyyy HH:mm').format(_publishAt)),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _publishAt,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_publishAt));
                    if (time != null) {
                      setState(() => _publishAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    }
                  }
                },
              ),
              ListTile(
                title: const Text('Expires At (Optional)', style: TextStyle(fontSize: 14)),
                subtitle: Text(_expiresAt == null ? 'Never' : DateFormat('MMM dd, yyyy HH:mm').format(_expiresAt!)),
                trailing: _expiresAt == null ? const Icon(Icons.calendar_today) : IconButton(icon: const Icon(Icons.clear), onPressed: () => setState(() => _expiresAt = null)),
                onTap: () async {
                  final date = await showDatePicker(
                    context: context,
                    initialDate: _expiresAt ?? DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
                  );
                  if (date != null) {
                    final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_expiresAt ?? DateTime.now()));
                    if (time != null) {
                      setState(() => _expiresAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                    }
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(onPressed: _save, child: const Text('Save Announcement')),
      ],
    );
  }
}
