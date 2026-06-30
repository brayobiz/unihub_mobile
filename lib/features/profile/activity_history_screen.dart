import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
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
    final history = ref.watch(recentHistoryProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Activity History',
          style: TextStyle(fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: Color(0xFF1E293B)),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (history.isNotEmpty)
            TextButton(
              onPressed: () => _showClearConfirm(context, ref),
              child: const Text('Clear', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
        ],
      ),
      body: Stack(
        children: [
          history.isEmpty
              ? _buildEmptyState()
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
            const Center(
              child: CircularProgressIndicator(color: Color(0xFF6366F1)),
            ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(BuildContext context, HistoryItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.all(12),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: _getCategoryColor(item.type).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_getCategoryIcon(item.type), color: _getCategoryColor(item.type)),
          ),
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
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
              style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
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
          context.push('/listing-detail', extra: listing);
        }
      } else if (item.type == 'housing') {
        final repo = ref.read(housingRepositoryProvider);
        final listing = await repo.getListingById(item.id);
        if (listing != null && mounted) {
          context.push('/housing-detail', extra: listing);
        }
      } else if (item.type == 'note') {
        final repo = ref.read(notesRepositoryProvider);
        final note = await repo.getNoteById(item.id);
        if (note != null && mounted) {
          context.push('/note-detail', extra: note);
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
      case 'listing': return const Color(0xFF6366F1);
      case 'housing': return const Color(0xFF10B981);
      case 'note': return const Color(0xFFF59E0B);
      case 'gig': return const Color(0xFF8B5CF6);
      default: return const Color(0xFF64748B);
    }
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.02),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                )
              ],
            ),
            child: const Icon(Icons.history_rounded, size: 64, color: Color(0xFFCBD5E1)),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Recent Activity',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
          ),
          const SizedBox(height: 8),
          const Text(
            'Items you view will appear here.',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ],
      ),
    );
  }

  void _showClearConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('Are you sure you want to clear your activity history?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(recentHistoryProvider.notifier).clear();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
