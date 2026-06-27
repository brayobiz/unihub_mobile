import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/features/dashboard/controllers/smart_feed_controller.dart';
import 'package:unihub_mobile/widgets/feed/feed_type.dart';
import 'package:go_router/go_router.dart';

class GlobalSearchScreen extends ConsumerStatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  ConsumerState<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends ConsumerState<GlobalSearchScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final allFeedAsync = ref.watch(smartFeedProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        titleSpacing: 0,
        title: Container(
          height: 44,
          margin: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Search marketplace, housing, notes...',
              hintStyle: GoogleFonts.plusJakartaSans(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
              ),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF64748B), size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
            onChanged: (value) {
              setState(() => _query = value.trim().toLowerCase());
            },
          ),
        ),
        actions: [
          if (_query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear_rounded, size: 20),
              onPressed: () {
                _searchController.clear();
                setState(() => _query = '');
              },
            ),
        ],
      ),
      body: _query.isEmpty 
          ? _buildSearchSuggestions()
          : allFeedAsync.when(
              data: (items) {
                final filtered = items.where((item) {
                  return item.model.title.toLowerCase().contains(_query) ||
                         item.model.subtitle.toLowerCase().contains(_query);
                }).toList();

                if (filtered.isEmpty) {
                  return _buildNoResults();
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    return _SearchItemCard(
                      item: item,
                      onTap: () => _handleItemTap(context, item),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
    );
  }

  Widget _buildSearchSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try searching for',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF64748B),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SuggestionChip(label: 'Calculus Notes', icon: Icons.description_rounded, color: Colors.green, onTap: () => _setQuery('Calculus')),
              _SuggestionChip(label: 'iPhone 13', icon: Icons.smartphone_rounded, color: Colors.orange, onTap: () => _setQuery('iPhone')),
              _SuggestionChip(label: 'Single Rooms', icon: Icons.home_rounded, color: Colors.blue, onTap: () => _setQuery('Single')),
              _SuggestionChip(label: 'Graphic Design', icon: Icons.palette_rounded, color: Colors.purple, onTap: () => _setQuery('Design')),
            ],
          ),
          const SizedBox(height: 40),
          _SearchCategoryRow(
            title: 'Marketplace',
            subtitle: 'Find gadgets, books, and more',
            icon: Icons.shopping_bag_outlined,
            color: Colors.orange,
          ),
          _SearchCategoryRow(
            title: 'Campus Housing',
            subtitle: 'Rentals, roommates and hostels',
            icon: Icons.home_work_outlined,
            color: Colors.blue,
          ),
          _SearchCategoryRow(
            title: 'Study Materials',
            subtitle: 'Notes, past papers and guides',
            icon: Icons.menu_book_rounded,
            color: Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.search_off_rounded, size: 48, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          Text(
            'No results for "$_query"',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF1A1C1E),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try checking for typos or searching \nfor something else.',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF94A3B8),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  void _setQuery(String q) {
    _searchController.text = q;
    setState(() => _query = q.toLowerCase());
  }

  void _handleItemTap(BuildContext context, SmartFeedItem item) {
    if (item.model.type == FeedType.housing) {
      context.push('/housing-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.notes) {
      context.push('/note-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.marketplace) {
      context.push('/marketplace-detail', extra: item.originalData);
    } else if (item.model.type == FeedType.gig) {
      context.push('/gig-detail', extra: item.originalData);
    }
  }
}

class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 8),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCategoryRow extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _SearchCategoryRow({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF1A1C1E),
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
        ],
      ),
    );
  }
}

class _SearchItemCard extends StatelessWidget {
  final SmartFeedItem item;
  final VoidCallback onTap;

  const _SearchItemCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _getCategoryColor(item.model.type).withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getCategoryIcon(item.model.type),
            color: _getCategoryColor(item.model.type),
          ),
        ),
        title: Text(
          item.model.title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          item.model.subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 12,
            color: const Color(0xFF64748B),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: const Icon(Icons.chevron_right_rounded, color: Color(0xFFCBD5E1)),
      ),
    );
  }

  IconData _getCategoryIcon(FeedType type) {
    switch (type) {
      case FeedType.marketplace: return Icons.shopping_bag_outlined;
      case FeedType.housing: return Icons.home_work_outlined;
      case FeedType.notes: return Icons.description_outlined;
      case FeedType.gig: return Icons.work_outline;
      default: return Icons.star_outline;
    }
  }

  Color _getCategoryColor(FeedType type) {
    switch (type) {
      case FeedType.marketplace: return Colors.orange;
      case FeedType.housing: return Colors.blue;
      case FeedType.notes: return Colors.green;
      case FeedType.gig: return Colors.purple;
      default: return Colors.grey;
    }
  }
}
