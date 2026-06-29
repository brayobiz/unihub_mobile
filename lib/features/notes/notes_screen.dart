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

class NotesScreen extends ConsumerStatefulWidget {
  const NotesScreen({super.key});

  @override
  ConsumerState<NotesScreen> createState() => _NotesScreenState();
}

class _NotesScreenState extends ConsumerState<NotesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FB),
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu_rounded, color: Colors.black),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
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
            Tab(text: 'Library'),
          ],
        ),
        actions: [
          const NotificationBadge(module: 'notes'),
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
        children: const [
          DiscoverTab(),
          LibraryTab(),
        ],
      ),
    );
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
    final selectedUni = ref.watch(notesUniversityFilterProvider);
    final user = ref.watch(appUserProvider).valueOrNull;

    final noteTypes = ['All', 'Lecture Note', 'Revision Kit', 'Assignment', 'Past Paper', 'Summary'];
    final years = ['All', '1', '2', '3', '4', '5', '6'];

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Advanced Filters', style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.bold)),
                TextButton(
                  onPressed: () {
                    ref.read(notesTypeFilterProvider.notifier).state = 'All';
                    ref.read(notesYearFilterProvider.notifier).state = 'All';
                    ref.read(notesUniversityFilterProvider.notifier).state = null;
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
                  const Text('Institution', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  _buildUniFilter(ref, selectedUni, user?.university),
                  
                  const SizedBox(height: 32),
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
                  
                  const SizedBox(height: 32),
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
                    backgroundColor: Colors.indigo,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUniFilter(WidgetRef ref, String? selected, String? userUni) {
    return Column(
      children: [
        RadioListTile<String?>(
          title: const Text('All Institutions'),
          value: null,
          groupValue: selected,
          onChanged: (val) => ref.read(notesUniversityFilterProvider.notifier).state = val,
          contentPadding: EdgeInsets.zero,
          dense: true,
        ),
        if (userUni != null)
          RadioListTile<String?>(
            title: Text('My University ($userUni)'),
            value: userUni,
            groupValue: selected,
            onChanged: (val) => ref.read(notesUniversityFilterProvider.notifier).state = val,
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
      ],
    );
  }
}
