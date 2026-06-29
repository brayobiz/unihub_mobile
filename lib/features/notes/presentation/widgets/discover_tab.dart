import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import 'note_card.dart';
import '../../../../core/utils/debouncer.dart';
import '../../domain/models/note.dart';

class DiscoverTab extends ConsumerStatefulWidget {
  const DiscoverTab({super.key});

  @override
  ConsumerState<DiscoverTab> createState() => _DiscoverTabState();
}

class _DiscoverTabState extends ConsumerState<DiscoverTab> {
  final _searchController = TextEditingController();
  final _searchDebouncer = Debouncer(milliseconds: 500);

  final List<String> _categories = [
    'All', 'Computer Science', 'Business', 'Law', 'Medicine', 
    'Engineering', 'Social Sciences', 'Arts', 'Natural Sciences'
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final notesAsync = ref.watch(notesListingsProvider(50));
    final trendingAsync = ref.watch(trendingNotesProvider);
    final recentAsync = ref.watch(recentNotesProvider);
    
    final user = ref.watch(appUserProvider).valueOrNull;
    final selectedCategory = ref.watch(notesCategoryFilterProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);

    final isSearching = searchQuery.isNotEmpty || selectedCategory != 'All';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notesListingsProvider);
        ref.invalidate(trendingNotesProvider);
        ref.invalidate(recentNotesProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildSearchBar(),
                _buildCategoryList(selectedCategory),
              ],
            ),
          ),
          
          if (!isSearching) ...[
            // Trending Section
            SliverToBoxAdapter(
              child: _buildHorizontalSection(
                context, 
                ref, 
                'Trending Resources', 
                trendingAsync,
                Icons.trending_up,
                Colors.orange,
              ),
            ),
            
            // Recently Uploaded Section
            SliverToBoxAdapter(
              child: _buildHorizontalSection(
                context, 
                ref, 
                'Recently Uploaded', 
                recentAsync,
                Icons.history,
                Colors.blue,
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Row(
                  children: [
                    Text(
                      'All Resources',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18, 
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const Spacer(),
                    if (user?.university != null)
                      Text(
                        'at ${user?.university}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                  ],
                ),
              ),
            ),
          ],

          if (isSearching)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              sliver: SliverToBoxAdapter(
                child: Text(
                  'Search Results',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
            ),

          // Main List
          notesAsync.when(
            data: (notes) => notes.isEmpty 
              ? SliverToBoxAdapter(child: _buildEmptyState())
              : SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => NoteCard(
                        index: index,
                        note: notes[index],
                        userUniversity: user?.university,
                        onTap: () => _handleNoteTap(notes[index]),
                      ),
                      childCount: notes.length,
                    ),
                  ),
                ),
            loading: () => const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: Colors.indigo)),
            ),
            error: (err, stack) => SliverFillRemaining(
              child: Center(child: Text('Error: $err')),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  void _handleNoteTap(NoteListing note) async {
    await ref.read(studyControllerProvider).markAsOpened(note.id);
    if (!mounted) return;
    
    if (note.price == 0) {
      context.push('/note-reader', extra: {
        'note': note,
        'filePath': null,
        'initialPage': 0,
      });
    } else {
      context.push('/note-detail', extra: note);
    }
  }

  Widget _buildHorizontalSection(
    BuildContext context, 
    WidgetRef ref, 
    String title, 
    AsyncValue<List<NoteListing>> notesAsync,
    IconData icon,
    Color iconColor,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: iconColor),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 160,
          child: notesAsync.when(
            data: (notes) => notes.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: notes.length,
                  itemBuilder: (context, index) => _buildCompactNoteCard(notes[index]),
                ),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }

  Widget _buildCompactNoteCard(NoteListing note) {
    return GestureDetector(
      onTap: () => _handleNoteTap(note),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: Border.all(color: Colors.grey.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.indigo, size: 16),
                ),
                const Spacer(),
                if (note.price == 0)
                  const Text('FREE', style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.w900))
                else
                  Text('KES ${note.price.toInt()}', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w900)),
              ],
            ),
            const Spacer(),
            Text(
              note.title,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 12, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              note.unitCode,
              style: TextStyle(color: Colors.indigo.shade400, fontSize: 9, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          _searchDebouncer.run(() {
            ref.read(notesSearchQueryProvider.notifier).state = val;
          });
          setState(() {}); 
        },
        decoration: InputDecoration(
          hintText: 'Search courses, units, topics...',
          prefixIcon: const Icon(Icons.search, color: Colors.indigo),
          suffixIcon: _searchController.text.isNotEmpty 
            ? IconButton(
                icon: const Icon(Icons.clear), 
                onPressed: () {
                  _searchController.clear();
                  ref.read(notesSearchQueryProvider.notifier).state = '';
                },
              )
            : null,
          filled: true,
          fillColor: const Color(0xFFF8F9FB),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCategoryList(String selected) {
    return Container(
      height: 50,
      color: Colors.white,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final cat = _categories[index];
          final isSelected = cat == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8, bottom: 10),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              onSelected: (val) {
                if (val) ref.read(notesCategoryFilterProvider.notifier).state = cat;
              },
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : Colors.black87,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: const Color(0xFFF8F9FB),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final query = ref.read(notesSearchQueryProvider);
    final category = ref.read(notesCategoryFilterProvider);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.indigo.shade100),
          const SizedBox(height: 24),
          Text(
            category == 'All' 
              ? 'No resources found' 
              : 'No $category notes yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: Colors.black87
            ),
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
              ? 'We couldn\'t find anything matching "$query". Try a different keyword.'
              : 'Be the first to share resources for this category and help your fellow students!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade600, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (query.isNotEmpty || category != 'All')
            TextButton.icon(
              onPressed: _resetFilters,
              icon: const Icon(Icons.refresh),
              label: const Text('Clear all filters'),
            ),
        ],
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    ref.read(notesSearchQueryProvider.notifier).state = '';
    ref.read(notesCategoryFilterProvider.notifier).state = 'All';
  }
}
