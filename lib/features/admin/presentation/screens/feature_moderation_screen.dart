import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/core/constants/campus_constants.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/moderation_content.dart';
import '../../domain/models/audit_log.dart';
import '../../shared/providers.dart';
import '../../../../services/notification_service.dart';

class FeatureModerationScreen extends ConsumerStatefulWidget {
  final ContentType contentType;
  final String? initialUserId;

  const FeatureModerationScreen({super.key, required this.contentType, this.initialUserId});

  @override
  ConsumerState<FeatureModerationScreen> createState() => _FeatureModerationScreenState();
}

class _FeatureModerationScreenState extends ConsumerState<FeatureModerationScreen> {
  String? _selectedStatus;
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Set<String> _selectedIds = {};
  bool _isBulkProcessing = false;

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
      } else {
        _selectedIds.add(id);
      }
    });
  }

  Future<void> _handleBulkStatusUpdate(String newStatus, List<ModeratedContent> items) async {
    final selectedItems = items.where((i) => _selectedIds.contains(i.id)).toList();
    if (selectedItems.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Bulk Status Update'),
        content: Text('Are you sure you want to update ${selectedItems.length} items to "$newStatus"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Confirm')),
        ],
      ),
    );

    if (confirmed != true) return;

    if (!mounted) return;
    
    setState(() => _isBulkProcessing = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final admin = ref.read(appUserProvider).valueOrNull;
      if (admin == null) throw Exception('Admin session not found');

      await ref.read(adminServiceProvider).bulkUpdateContentStatus(
        contentIds: selectedItems.map((i) => i.id).toList(),
        type: widget.contentType,
        newStatus: newStatus,
        adminId: admin.uid,
        adminName: admin.fullName,
      );
      
      if (mounted) {
        setState(() {
          _selectedIds.clear();
          _isBulkProcessing = false;
        });
        messenger.showSnackBar(const SnackBar(content: Text('Bulk update completed successfully')));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isBulkProcessing = false);
        messenger.showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialUserId != null) {
      _searchQuery = widget.initialUserId!.toLowerCase();
      _searchController.text = widget.initialUserId!;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contentAsync = ref.watch(moderatedContentProvider((type: widget.contentType, status: _selectedStatus)));

    return AdminLayout(
      title: '${widget.contentType.name[0].toUpperCase()}${widget.contentType.name.substring(1)} Moderation',
      actions: [
        if (widget.contentType == ContentType.marketplace)
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: AppColors.secondary),
            tooltip: 'Broadcast Marketplace Reminder',
            onPressed: () => _showBroadcastDialog(),
          ),
      ],
      child: Column(
        children: [
          _buildFilters(contentAsync.valueOrNull?.length ?? 0, contentAsync.valueOrNull ?? []),
          _buildSearchBar(),
          Expanded(
            child: contentAsync.when(
              data: (items) {
                final filtered = _applySearch(items);
                return _buildList(filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Error: $err')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(int count, List<ModeratedContent> items) {
    List<String> statuses = ['active', 'removed'];
    if (widget.contentType == ContentType.marketplace) {
      statuses = ['active', 'sold', 'paused', 'expired', 'archived', 'removed'];
    } else if (widget.contentType == ContentType.housing) {
      statuses = ['available', 'taken', 'pendingReview', 'reported', 'archived', 'removed'];
    } else if (widget.contentType == ContentType.events) {
      statuses = ['submitted', 'approved', 'scheduled', 'live', 'ended', 'archived', 'removed'];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).cardColor,
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                DropdownButton<String?>(
                  value: _selectedStatus,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All')),
                    ...statuses.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text(s[0].toUpperCase() + s.substring(1)),
                    )),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val),
                ),
                const SizedBox(width: 24),
                Text('$count Items Found', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (_selectedIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  Text('${_selectedIds.length} Selected', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  const SizedBox(width: 16),
                  if (_isBulkProcessing) 
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  else ...[
                    TextButton.icon(
                      onPressed: () => _handleBulkStatusUpdate('removed', items),
                      icon: const Icon(Icons.delete_outline, color: AppColors.error),
                      label: const Text('Remove Selected', style: TextStyle(color: AppColors.error)),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: () => setState(() => _selectedIds.clear()),
                      icon: const Icon(Icons.close),
                      tooltip: 'Clear Selection',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).cardColor,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Title, Author, or ID...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
          fillColor: Theme.of(context).colorScheme.surface,
        ),
        onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
      ),
    );
  }

  List<ModeratedContent> _applySearch(List<ModeratedContent> items) {
    if (_searchQuery.isEmpty) return items;
    return items.where((item) => 
      item.title.toLowerCase().contains(_searchQuery) ||
      item.authorName.toLowerCase().contains(_searchQuery) ||
      item.id.toLowerCase().contains(_searchQuery)
    ).toList();
  }

  Widget _buildList(List<ModeratedContent> items) {
    if (items.isEmpty) {
      return const Center(child: Text('No items found.'));
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final item = items[index];
        final isSelected = _selectedIds.contains(item.id);

        return Row(
          children: [
            Checkbox(
              value: isSelected,
              onChanged: (_) => _toggleSelection(item.id),
            ),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(12),
                  leading: _buildThumbnail(item),
                  title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('By ${item.authorName} • ${CampusConstants.getDisplayName(item.university)}'),
                      Text(DateFormat('MMM dd, yyyy').format(item.createdAt), 
                        style: TextStyle(
                          fontSize: 12, 
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  trailing: _buildStatusChip(item.status),
                  onTap: () => _showModerationOptions(item),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildThumbnail(ModeratedContent item) {
    if (item.imageUrls.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(item.imageUrls.first, width: 60, height: 60, fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholderIcon()),
      );
    }
    return _placeholderIcon();
  }

  Widget _placeholderIcon() {
    IconData icon;
    switch (widget.contentType) {
      case ContentType.marketplace: icon = Icons.shopping_bag; break;
      case ContentType.housing: icon = Icons.home; break;
      case ContentType.notes: icon = Icons.description; break;
      case ContentType.events: icon = Icons.event; break;
    }
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppColors.grey400),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.primary;
    if (status == 'removed' || status == 'suspended') color = AppColors.error;
    if (status == 'active' || status == 'available' || status == 'approved' || status == 'live') color = AppColors.success;
    if (status == 'submitted' || status == 'pendingReview') color = AppColors.warning;
    if (status == 'sold' || status == 'taken' || status == 'ended') color = AppColors.grey600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  void _showBroadcastDialog() async {
    final titleController = TextEditingController();
    final bodyController = TextEditingController();
    bool useCustomMessage = false;

    try {
      await showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Broadcast Marketplace Reminder'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'This will send a push notification to ALL UniHub users.',
                  style: TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 16),
                SwitchListTile(
                  title: const Text('Use Custom Message', style: TextStyle(fontSize: 14)),
                  value: useCustomMessage,
                  onChanged: (val) => setDialogState(() => useCustomMessage = val),
                ),
                if (useCustomMessage) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g., Fresh Deals Today! 🛍️',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bodyController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Notification Body',
                      hintText: 'e.g., Check out the latest items...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ] else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text(
                      'A random marketing message will be selected (e.g., "New Deals Alert!").',
                      style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final navigator = Navigator.of(context);
                  
                  try {
                    await ref.read(notificationServiceProvider).triggerMarketplaceReminder(
                      customTitle: useCustomMessage ? titleController.text.trim() : null,
                      customBody: useCustomMessage ? bodyController.text.trim() : null,
                    );
                    
                    navigator.pop();
                    messenger.showSnackBar(
                      const SnackBar(content: Text('✅ Marketplace broadcast triggered successfully')),
                    );
                  } catch (e) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('❌ Error: $e')),
                    );
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.secondary),
                child: const Text('Broadcast Now'),
              ),
            ],
          ),
        ),
      );
    } finally {
      titleController.dispose();
      bodyController.dispose();
    }
  }

  void _showModerationOptions(ModeratedContent item) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.visibility),
              title: const Text('View Full Details'),
              onTap: () {
                Navigator.pop(context);
                if (widget.contentType == ContentType.events) {
                  context.push('/events/${item.id}');
                } else if (widget.contentType == ContentType.marketplace) {
                  context.push('/listing-detail/${item.id}');
                } else if (widget.contentType == ContentType.housing) {
                  context.push('/housing-detail/${item.id}');
                } else if (widget.contentType == ContentType.notes) {
                  context.push('/note-detail/${item.id}');
                }
              },
            ),
            if (widget.contentType == ContentType.events && item.status == 'submitted')
              ListTile(
                leading: const Icon(Icons.check_circle_outline, color: AppColors.success),
                title: const Text('Approve Event', style: TextStyle(color: AppColors.success)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAction('approved', item);
                },
              ),
            if (item.status != 'removed')
              ListTile(
                leading: const Icon(Icons.delete, color: AppColors.error),
                title: const Text('Remove Content', style: TextStyle(color: AppColors.error)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAction('remove', item);
                },
              )
            else
              ListTile(
                leading: const Icon(Icons.restore, color: AppColors.success),
                title: const Text('Restore Content', style: TextStyle(color: AppColors.success)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmAction('active', item);
                },
              ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('View Author Profile'),
              onTap: () {
                Navigator.pop(context);
                // Navigate to user management or profile
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmAction(String newStatus, ModeratedContent item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(newStatus == 'remove' ? 'Remove Content?' : 'Restore Content?'),
        content: Text('Are you sure you want to change the status of "${item.title}" to $newStatus?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: newStatus == 'remove' ? AppColors.error : AppColors.success),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;

      try {
        final admin = ref.read(appUserProvider).valueOrNull;
        if (admin == null) throw Exception('Admin session not found');
        final messenger = ScaffoldMessenger.of(context);

        await ref.read(adminServiceProvider).updateContentStatus(
          widget.contentType,
          item.id,
          newStatus == 'remove' 
              ? 'removed' 
              : (newStatus == 'active' 
                  ? (widget.contentType == ContentType.housing ? 'available' : 'active')
                  : newStatus),
          adminId: admin.uid,
          adminName: admin.fullName,
        );
        if (mounted) {
          messenger.showSnackBar(SnackBar(content: Text('Status updated successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
