import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../app/theme/app_colors.dart';
import '../layout/admin_layout.dart';
import '../../domain/models/moderation_content.dart';
import '../../shared/providers.dart';

class FeatureModerationScreen extends ConsumerStatefulWidget {
  final ContentType contentType;

  const FeatureModerationScreen({super.key, required this.contentType});

  @override
  ConsumerState<FeatureModerationScreen> createState() => _FeatureModerationScreenState();
}

class _FeatureModerationScreenState extends ConsumerState<FeatureModerationScreen> {
  String? _selectedStatus;
  final _searchController = TextEditingController();
  String _searchQuery = '';

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
      child: Column(
        children: [
          _buildFilters(contentAsync.valueOrNull?.length ?? 0),
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

  Widget _buildFilters(int count) {
    List<String> statuses = ['active', 'removed'];
    if (widget.contentType == ContentType.marketplace) {
      statuses = ['active', 'sold', 'paused', 'expired', 'archived', 'removed'];
    } else if (widget.contentType == ContentType.housing) {
      statuses = ['available', 'taken', 'pendingReview', 'reported', 'archived', 'removed'];
    }

    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: SingleChildScrollView(
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
            Text('$count Items Found', style: const TextStyle(color: AppColors.grey600)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search by Title, Author, or ID...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
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
        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.grey200),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: _buildThumbnail(item),
            title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('By ${item.authorName} • ${item.university ?? "Unknown"}'),
                Text(DateFormat('MMM dd, yyyy').format(item.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.grey600)),
              ],
            ),
            trailing: _buildStatusChip(item.status),
            onTap: () => _showModerationOptions(item),
          ),
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
    }
    return Container(
      width: 60, height: 60,
      decoration: BoxDecoration(color: AppColors.grey100, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: AppColors.grey400),
    );
  }

  Widget _buildStatusChip(String status) {
    Color color = AppColors.primary;
    if (status == 'removed') color = AppColors.error;
    if (status == 'active' || status == 'available') color = AppColors.success;
    if (status == 'sold' || status == 'taken') color = AppColors.grey600;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
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
                // TODO: Navigate to the actual detail screen of the feature
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Detail view navigation coming in future update')));
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
      try {
        await ref.read(adminRepositoryProvider).updateContentStatus(
          widget.contentType,
          item.id,
          newStatus == 'remove' ? 'removed' : (widget.contentType == ContentType.housing ? 'available' : 'active'),
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Status updated successfully')));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }
}
