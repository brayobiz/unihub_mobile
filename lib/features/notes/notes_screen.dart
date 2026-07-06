import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../auth/shared/providers.dart';
import 'shared/providers.dart';
import 'presentation/widgets/discover_tab.dart';
import 'presentation/widgets/library_tab.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/notification_badge.dart';
import 'package:unihub_mobile/features/announcements/presentation/widgets/announcement_display.dart';
import 'package:unihub_mobile/features/campus_filter/presentation/widgets/campus_filter_selector.dart';

class NotesScreen extends ConsumerStatefulWidget {
  final int initialTabIndex;
  const NotesScreen({super.key, this.initialTabIndex = 0});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2, 
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: AppDrawer(),
      appBar: AppBar(
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: theme.colorScheme.onSurface),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          'UniHub Study',
          style: theme.textTheme.titleLarge?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          labelColor: theme.colorScheme.primary,
          unselectedLabelColor: theme.colorScheme.onSurfaceVariant,
          indicatorColor: theme.colorScheme.primary,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: const [
            Tab(text: 'Discover'),
            Tab(text: 'Library'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.search_rounded),
            tooltip: 'Search Notes',
            onPressed: () => showSearch(
              context: context,
              delegate: NotesSearchDelegate(ref: ref),
            ),
          ),
          Semantics(
            label: 'Notifications',
            button: true,
            child: const NotificationBadge(module: 'notes'),
          ),
          IconButton(
            icon: Icon(Icons.tune, color: theme.colorScheme.onSurface),
            tooltip: 'Filter Notes',
            onPressed: () => _showFilterSheet(),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Semantics(
              label: 'View Profile',
              button: true,
              child: Consumer(
                builder: (context, ref, _) {
                  final user = ref.watch(appUserProvider).valueOrNull;
                  return CircleAvatar(
                    radius: 16,
                    backgroundColor: theme.colorScheme.surfaceVariant,
                    backgroundImage: user?.photoUrl != null ? NetworkImage(user!.photoUrl!) : null,
                    child: user?.photoUrl == null 
                        ? Text(
                            user?.fullName.isNotEmpty == true ? user!.fullName[0].toUpperCase() : 'U',
                            style: TextStyle(color: theme.colorScheme.primary, fontSize: 12, fontWeight: FontWeight.bold),
                          )
                        : null,
                  );
                }
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'notes_fab',
        onPressed: () => context.push('/add-note'),
        backgroundColor: theme.colorScheme.primary,
        label: const Text('Upload Notes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
      body: Column(
        children: [
          const RelevantAnnouncementsWidget(feature: 'notes'),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: CampusFilterSelector(),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                DiscoverTab(),
                LibraryTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => const NoteFilterSheet(),
    );
  }
}

class NoteFilterSheet extends ConsumerWidget {
  const NoteFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedType = ref.watch(notesTypeFilterProvider);
    final selectedYear = ref.watch(notesYearFilterProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    final noteTypes = ['All', 'Lecture Note', 'Revision Kit', 'Assignment', 'Past Paper', 'Summary'];
    final years = ['All', '1', '2', '3', '4', '5', '6'];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(color: theme.colorScheme.surface, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Advanced Filters', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    ref.read(notesTypeFilterProvider.notifier).state = 'All';
                    ref.read(notesYearFilterProvider.notifier).state = 'All';
                  },
                  child: const Text('Reset All'),
                ),
              ],
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(vertical: 24),
                children: [
                  Text('Note Type', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: noteTypes.map((t) => ChoiceChip(
                      label: Text(t),
                      selected: selectedType == t,
                      onSelected: (val) => ref.read(notesTypeFilterProvider.notifier).state = t,
                      selectedColor: theme.colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: selectedType == t ? Colors.white : theme.colorScheme.onSurface),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 32),
                  Text('Year of Study', style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: years.map((y) => ChoiceChip(
                      label: Text(y == 'All' ? 'All Years' : 'Year $y'),
                      selected: selectedYear == y,
                      onSelected: (val) => ref.read(notesYearFilterProvider.notifier).state = y,
                      selectedColor: theme.colorScheme.primary,
                      checkmarkColor: Colors.white,
                      labelStyle: TextStyle(color: selectedYear == y ? Colors.white : theme.colorScheme.onSurface),
                    )).toList(),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class NotesSearchDelegate extends SearchDelegate<String?> {
  final WidgetRef ref;

  NotesSearchDelegate({required this.ref});

  @override
  List<Widget>? buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          onPressed: () => query = '',
          icon: const Icon(Icons.clear_rounded, semanticLabel: 'Clear search'),
        ),
    ];
  }

  @override
  Widget? buildLeading(BuildContext context) {
    return IconButton(
      onPressed: () => close(context, null),
      icon: const Icon(Icons.arrow_back_rounded, semanticLabel: 'Back'),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    // Implement results display or filtering logic here
    // For now, let's just close and use the query if needed
    close(context, query);
    return const SizedBox.shrink();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    // Add logic for note-specific suggestions if available
    return const Center(child: Text('Search by unit code or course name'));
  }
}
