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
    
    final user = ref.watch(appUserProvider).valueOrNull;
    final selectedCategory = ref.watch(notesCategoryFilterProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);

    final isSearching = searchQuery.isNotEmpty || selectedCategory != 'All';

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notesListingsProvider);
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
