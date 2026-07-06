import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../services/history_service.dart';
import '../marketplace/shared/providers.dart';
import '../housing/shared/providers.dart';
import '../notes/shared/providers.dart';

class ActivityHistoryScreen extends ConsumerStatefulWidget {
  const ActivityHistoryScreen({super.key});

  @override
  ConsumerState<ActivityHistoryScreen> createState() => _ActivityHistoryScreenState();
}

class _ActivityHistoryScreenState extends ConsumerState<ActivityHistoryScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(recentHistoryProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          'Activity History',
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
        ),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () => _showClearConfirm(context, ref),
              child: const Text('Clear', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          history.isEmpty
              ? _buildEmptyState(context)
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: history.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    return _buildHistoryCard(context, item);
                  },
                ),
          if (_isLoading)
            Center(
              child: CircularProgressIndicator(color: theme.colorScheme.primary),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryItem item) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Material(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getCategoryColor(item.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCategoryIcon(item.type), color: _getCategoryColor(item.type)),
          ),
        title: Text(
          item.title,
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: theme.colorScheme.onSurface),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              item.type.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: _getCategoryColor(item.type),
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              DateFormat('MMM d, h:mm a').format(item.timestamp),
              style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5)),
        onTap: () => _navigateToDetail(item),
      ),
    ),
  );
}

  Future<void> _navigateToDetail(HistoryItem item) async {
    setState(() => _isLoading = true);
    try {
      if (item.type == 'listing') {
        final repo = ref.read(marketplaceRepositoryProvider);
        final listing = await repo.getListingById(item.id);
        if (listing != null && mounted) {
          context.push('/listing-detail/${listing.id}', extra: listing);
        } else if (mounted) {
          context.push('/listing-detail/${item.id}');
        }
      } else if (item.type == 'housing') {
        final repo = ref.read(housingRepositoryProvider);
        final listing = await repo.getListingById(item.id);
        if (listing != null && mounted) {
          context.push('/housing-detail/${listing.id}', extra: listing);
        } else if (mounted) {
          context.push('/housing-detail/${item.id}');
        }
      } else if (item.type == 'note') {
        final repo = ref.read(notesRepositoryProvider);
        final note = await repo.getNoteById(item.id);
        if (note != null && mounted) {
          context.push('/note-detail/${note.id}', extra: note);
        } else if (mounted) {
          context.push('/note-detail/${item.id}');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open item: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  IconData _getCategoryIcon(String type) {
    switch (type) {
      case 'listing': return Icons.shopping_bag_outlined;
      case 'housing': return Icons.home_work_outlined;
      case 'note': return Icons.menu_book_outlined;
      case 'gig': return Icons.work_outline_rounded;
      default: return Icons.history_rounded;
    }
  }

  Color _getCategoryColor(String type) {
    switch (type) {
      case 'listing': return AppColors.marketplace;
      case 'housing': return AppColors.housing;
      case 'note': return AppColors.notes;
      case 'gig': return AppColors.gigs;
      default: return AppColors.grey;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: Icon(Icons.history_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
          ),
          const SizedBox(height: 24),
          Text(
            'No Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Text(
            'Items you view will appear here.',
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to clear your activity history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(recentHistoryProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}
