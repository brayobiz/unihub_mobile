import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import 'note_card.dart';
import '../../../../core/utils/debouncer.dart';
import '../../domain/models/note.dart';
import '../../../campus_filter/shared/providers.dart';
import '../../../campus_filter/domain/models/browsing_scope.dart';
import 'package:unihub_mobile/features/ads/ads_module.dart';

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
    final theme = Theme.of(context);
    final notesAsync = ref.watch(notesListingsProvider(50));
    
    final user = ref.watch(appUserProvider).valueOrNull;
    final selectedCategory = ref.watch(notesCategoryFilterProvider);
    final searchQuery = ref.watch(notesSearchQueryProvider);

    final isSearching = searchQuery.isNotEmpty || selectedCategory != 'All';
    const int adInterval = AdConfig.notesAdInterval;

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(notesListingsProvider);
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Column(
              children: [
                _buildSearchBar(context),
                _buildCategoryList(context, selectedCategory),
              ],
            ),
          ),
          
          // Main List
          notesAsync.when(
            data: (notes) {
              if (notes.isEmpty) return SliverToBoxAdapter(child: _buildEmptyState(context));
              
              return SliverMainAxisGroup(
                slivers: [
                  if (!isSearching)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Row(
                          children: [
                            Text(
                              'All Resources',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontSize: 18, 
                                fontWeight: FontWeight.bold,
                                letterSpacing: -0.5,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            const Spacer(),
                            if (user?.university != null)
                              Text(
                                'at ${user?.university}',
                                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                          ],
                        ),
                      ),
                    ),
                  if (isSearching)
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                      sliver: SliverToBoxAdapter(
                        child: Text(
                          'Search Results',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 18, 
                            fontWeight: FontWeight.bold,
                            letterSpacing: -0.5,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          // Check if we should show a banner at the very end
                          final bool isLast = index == (notes.length + (notes.length ~/ adInterval));
                          if (isLast && notes.length >= 3) {
                            return const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: BannerAdWidget(),
                            );
                          }

                          // If it's an ad position within the list
                          if ((index + 1) % (adInterval + 1) == 0) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20),
                              child: const BannerAdWidget(),
                            );
                          }

                          // Calculate the actual note index by subtracting the number of ads before it
                          final int itemIndex = index - (index ~/ (adInterval + 1));
                          
                          if (itemIndex >= notes.length) return null;

                          return NoteCard(
                            index: itemIndex,
                            note: notes[itemIndex],
                            userUniversity: user?.university,
                            onTap: () => _handleNoteTap(notes[itemIndex]),
                          );
                        },
                        // Increase child count to include injected ads + potential bottom ad
                        childCount: notes.length + (notes.length ~/ adInterval) + (notes.length >= 3 ? 1 : 0),
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
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

  bool _isNavigating = false;

  void _handleNoteTap(NoteListing note) {
    if (_isNavigating) return;
    _isNavigating = true;

    // Trigger in background to avoid UI delay
    ref.read(studyControllerProvider).markAsOpened(note.id).catchError((_) => null);
    
    if (note.price == 0) {
      context.push('/note-reader', extra: {
        'note': note,
        'filePath': null,
        'initialPage': 0,
      });
    } else {
      context.push('/note-detail/${note.id}', extra: note);
    }

    // Guard against rapid multi-taps during navigation transition
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) _isNavigating = false;
    });
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
      child: TextField(
        controller: _searchController,
        style: TextStyle(color: theme.colorScheme.onSurface),
        onChanged: (val) {
          _searchDebouncer.run(() {
            ref.read(notesSearchQueryProvider.notifier).state = val;
          });
          setState(() {}); 
        },
        decoration: InputDecoration(
          hintText: 'Search courses, units, topics...',
          hintStyle: TextStyle(color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          prefixIcon: Icon(Icons.search, color: theme.colorScheme.primary),
          suffixIcon: _searchController.text.isNotEmpty 
            ? IconButton(
                icon: Icon(Icons.clear, color: theme.colorScheme.onSurfaceVariant), 
                onPressed: () {
                  _searchController.clear();
                  ref.read(notesSearchQueryProvider.notifier).state = '';
                },
              )
            : null,
          filled: true,
          fillColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 0),
        ),
      ),
    );
  }

  Widget _buildCategoryList(BuildContext context, String selected) {
    final theme = Theme.of(context);
    return Container(
      height: 50,
      color: theme.colorScheme.surface,
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
              selectedColor: theme.colorScheme.primary,
              checkmarkColor: Colors.white,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              backgroundColor: theme.colorScheme.surfaceVariant.withOpacity(0.3),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final query = ref.read(notesSearchQueryProvider);
    final category = ref.read(notesCategoryFilterProvider);
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: theme.colorScheme.primary.withOpacity(0.2)),
          const SizedBox(height: 24),
          Text(
            category == 'All' 
              ? 'No resources found' 
              : 'No $category notes yet',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: 18, 
              fontWeight: FontWeight.bold, 
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            query.isNotEmpty
              ? 'We couldn\'t find anything matching "$query". Try a different keyword.'
              : 'Be the first to share resources for this category and help your fellow students!',
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.6),
          ),
          const SizedBox(height: 32),
          if (query.isNotEmpty || category != 'All' || ref.read(browsingScopeProvider).type != BrowsingScopeType.all)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: _resetFilters,
                  icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                  label: Text('Clear Filters', style: TextStyle(color: theme.colorScheme.primary)),
                ),
                const SizedBox(width: 12),
                FilledButton.icon(
                  onPressed: () {
                    _resetFilters();
                    ref.read(browsingScopeProvider.notifier).reset();
                  },
                  icon: const Icon(Icons.public, size: 18),
                  label: const Text('Explore All'),
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
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
