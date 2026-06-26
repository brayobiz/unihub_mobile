import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/shared/providers.dart';
import 'shared/providers.dart';
import 'presentation/widgets/note_card.dart';
import 'domain/models/study_progress.dart';
import 'domain/models/note.dart';
import '../../services/download_service.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path/path.dart' as p;
import '../../core/utils/debouncer.dart';

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> with SingleTickerProviderStateMixin {
  final _searchController = TextEditingController();
  late TabController _tabController;
  final _searchDebouncer = Debouncer(milliseconds: 500);

  final List<String> _categories = [
    'All', 'Computer Science', 'Business', 'Law', 'Medicine', 
    'Engineering', 'Social Sciences', 'Arts', 'Natural Sciences'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Text(
          'UniHub Study',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.indigo,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.indigo,
          labelStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'My Library'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.tune, color: Colors.black87),
            onPressed: () => _showFilterSheet(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add-note'),
        backgroundColor: Colors.indigo,
        label: const Text('Share Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.add),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDiscoverTab(),
          _buildMyLibraryTab(),
        ],
      ),
    );
  }

  Widget _buildDiscoverTab() {
    final notesAsync = ref.watch(notesListingsProvider(50));
    final user = ref.watch(appUserProvider).valueOrNull;
    final selectedCategory = ref.watch(notesCategoryFilterProvider);

    return Column(
      children: [
        _buildSearchBar(),
        _buildCategoryList(selectedCategory),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            child: notesAsync.when(
              data: (notes) => notes.isEmpty 
                ? _buildEmptyState()
                : ListView.builder(
                    key: ValueKey('notes_list_${notes.length}'),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: notes.length,
                    itemBuilder: (context, index) {
                      return NoteCard(
                        index: index,
                        note: notes[index],
                        userUniversity: user?.university,
                        onTap: () async {
                          await ref.read(studyControllerProvider).markAsOpened(notes[index].id);
                          if (mounted) context.push('/note-detail', extra: notes[index]);
                        },
                      );
                    },
                  ),
              loading: () => const Center(
                key: ValueKey('loading'),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Colors.indigo),
                    SizedBox(height: 16),
                    Text('Searching resources...', style: TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              error: (err, stack) {
                debugPrint('❌ Notes Error: $err');
                debugPrint('Stack: $stack');
                return Center(
                  key: const ValueKey('error'),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: Colors.red),
                        const SizedBox(height: 16),
                        Text('Error loading notes: $err'),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => ref.invalidate(notesListingsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMyLibraryTab() {
    final history = ref.watch(studyHistoryProvider);
    final uploads = ref.watch(userNotesProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        // Continue Studying (History)
        history.when(
          data: (data) => data.isEmpty 
            ? const SizedBox.shrink()
            : _buildHorizontalSection('Continue Studying', data, isHistory: true),
          loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => const SizedBox.shrink(),
        ),

        // My Uploads
        uploads.when(
          data: (data) => data.isEmpty
            ? const SizedBox.shrink()
            : _buildHorizontalSection('My Uploads', data, isUploads: true),
          loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator())),
          error: (e, _) => const SizedBox.shrink(),
        ),

        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: _buildSectionHeader('Bookmarks', Icons.bookmark_border),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: bookmarks.when(
            data: (data) => data.isEmpty 
              ? _buildLibraryEmpty('No bookmarks yet. Tap the bookmark icon on any note to save it.')
              : Column(children: data.map((p) => _buildProgressTile(p)).toList()),
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Error: $e'),
          ),
        ),
      ],
    );
  }

  Widget _buildHorizontalSection(String title, List<dynamic> items, {bool isHistory = false, bool isUploads = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isHistory)
                TextButton(
                  onPressed: () => _showClearHistoryDialog(),
                  child: Text('Clear All', style: TextStyle(color: Colors.indigo.shade400, fontSize: 12)),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 140,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              
              if (isHistory) {
                final progress = item as StudyProgress;
                final noteAsync = ref.watch(noteByIdProvider(progress.noteId));
                return noteAsync.when(
                  data: (note) => note != null ? _buildContinueCard(note, progress) : const SizedBox.shrink(),
                  loading: () => const SizedBox(width: 200),
                  error: (e, _) => const SizedBox.shrink(),
                );
              } else {
                final note = item as NoteListing;
                // Reuse a similar style card for uploads but maybe without progress
                return _buildSimpleNoteCard(note);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSimpleNoteCard(NoteListing note) {
    return GestureDetector(
      onTap: () => context.push('/note-detail', extra: note),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.description_rounded, color: Colors.indigo, size: 18),
                ),
                const Spacer(),
                _buildActionIcon(
                  icon: Icons.edit_outlined,
                  color: Colors.indigo,
                  onTap: () => context.push('/add-note', extra: note),
                ),
                const SizedBox(width: 4),
                _buildActionIcon(
                  icon: Icons.delete_outline,
                  color: Colors.red,
                  onTap: () => _confirmDelete(context, ref, note),
                ),
              ],
            ),
            const Spacer(),
            Text(
              note.title,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text(
                  note.unitCode,
                  style: TextStyle(color: Colors.indigo.shade400, fontSize: 10, fontWeight: FontWeight.w900),
                ),
                const SizedBox(width: 6),
                const CircleAvatar(radius: 1.5, backgroundColor: Colors.grey),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    note.authorName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, NoteListing note) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource?'),
        content: const Text('This will permanently remove this study resource from UniHub.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(notesRepositoryProvider).deleteNote(note.id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Colors.indigo),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildProgressTile(StudyProgress progress) {
    final noteAsync = ref.watch(noteByIdProvider(progress.noteId));

    return noteAsync.when(
      data: (note) {
        if (note == null) return const SizedBox.shrink();
        return NoteCard(
          note: note,
          onTap: () => _resumeNote(note),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildLibraryEmpty(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
    );
  }

  void _showClearHistoryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History?'),
        content: const Text('This will remove all recently studied documents from your library. Your bookmarks will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(studyControllerProvider).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showRemoveFromHistoryDialog(dynamic note) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              note.title,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold, fontSize: 16),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text('Remove from Library', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
              subtitle: const Text('This will clear your study progress for this document.'),
              onTap: () {
                ref.read(studyControllerProvider).removeFromHistory(note.id);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed "${note.title}" from your library')),
                );
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeNote(dynamic note) async {
    try {
      final fileName = '${note.title.replaceAll(RegExp(r'[^\w\s]+'), '_')}${p.extension(note.fileUrl).isEmpty ? '.pdf' : p.extension(note.fileUrl)}';
      final downloadService = ref.read(downloadServiceProvider);
      final isDownloaded = await downloadService.isFileDownloaded(fileName);
      final savePath = await downloadService.getSavePath(fileName);

      if (isDownloaded) {
        final progress = await ref.read(noteProgressProvider(note.id).future);
        if (mounted) {
          context.push('/note-reader', extra: {
            'note': note,
            'filePath': savePath,
            'initialPage': progress?.lastPage ?? 0,
          });
        }
      } else {
        // If not downloaded, take them to detail page where they can initiate download
        if (mounted) context.push('/note-detail', extra: note);
      }
    } catch (e) {
      if (mounted) context.push('/note-detail', extra: note);
    }
  }

  Widget _buildContinueCard(dynamic note, StudyProgress progress) {
    return GestureDetector(
      onTap: () => _resumeNote(note),
      onLongPress: () => _showRemoveFromHistoryDialog(note),
      child: Container(
        width: 240,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.indigo.shade600,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.indigo.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    note.title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.more_vert, color: Colors.white.withOpacity(0.5), size: 16),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Page ${progress.lastPage + 1}',
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 12),
            ),
            const Spacer(),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Colors.white.withOpacity(0.2),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${(progress.progress * 100).toInt()}% complete',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.white),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          _searchDebouncer.run(() {
            ref.read(notesSearchQueryProvider.notifier).state = val;
          });
          setState(() {}); // For suffix icon visibility
        },
        decoration: InputDecoration(
          hintText: 'Search subjects, topics, or units...',
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
    
    return Center(
      child: SingleChildScrollView(
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
      ),
    );
  }

  void _resetFilters() {
    _searchController.clear();
    ref.read(notesSearchQueryProvider.notifier).state = '';
    ref.read(notesCategoryFilterProvider.notifier).state = 'All';
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
      builder: (context) => const NoteFilterSheet(),
    );
  }
}

class NoteFilterSheet extends ConsumerWidget {
  const NoteFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = ref.watch(notesTypeFilterProvider);
    final selectedYear = ref.watch(notesYearFilterProvider);

    final noteTypes = ['All', 'Lecture Note', 'Revision Kit', 'Assignment', 'Past Paper', 'Summary'];
    final years = ['All', '1', '2', '3', '4', '5', '6'];

    return Padding(
      padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Filters', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () {
                  ref.read(notesTypeFilterProvider.notifier).state = 'All';
                  ref.read(notesYearFilterProvider.notifier).state = 'All';
                },
                child: const Text('Reset All'),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Note Type', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: noteTypes.map((t) => ChoiceChip(
              label: Text(t),
              selected: selectedType == t,
              onSelected: (val) => ref.read(notesTypeFilterProvider.notifier).state = t,
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(color: selectedType == t ? Colors.white : Colors.black87),
            )).toList(),
          ),
          const SizedBox(height: 24),
          const Text('Year of Study', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: years.map((y) => ChoiceChip(
              label: Text(y == 'All' ? 'All Years' : 'Year $y'),
              selected: selectedYear == y,
              onSelected: (val) => ref.read(notesYearFilterProvider.notifier).state = y,
              selectedColor: Colors.indigo,
              labelStyle: TextStyle(color: selectedYear == y ? Colors.white : Colors.black87),
            )).toList(),
          ),
          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.indigo,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}
