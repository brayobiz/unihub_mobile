import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../shared/providers.dart';
import 'package:go_router/go_router.dart';
import '../widgets/marketplace_card.dart';
import '../../../auth/shared/providers.dart';

class SavedListingsScreen extends ConsumerStatefulWidget {
  const SavedListingsScreen({super.key});

  @override
  ConsumerState<SavedListingsScreen> createState() => _SavedListingsScreenState();
}

class _SavedListingsScreenState extends ConsumerState<SavedListingsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _createNewCollection() {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New Collection'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(hintText: 'e.g., Semester Shopping'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              if (nameController.text.isNotEmpty) {
                ref.read(marketplaceRepositoryProvider).createCollection(user.uid, nameController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final collectionNamesAsync = ref.watch(collectionNamesProvider);

    return collectionNamesAsync.when(
      data: (names) {
        final totalTabs = 1 + names.length;
        if (_tabController.length != totalTabs) {
          _tabController = TabController(length: totalTabs, vsync: this);
        }

        return Scaffold(
          backgroundColor: theme.scaffoldBackgroundColor,
          appBar: AppBar(
            backgroundColor: theme.colorScheme.surface,
            elevation: 0,
            title: Text(
              'Wishlist & Collections',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.bold, 
                color: theme.colorScheme.onSurface,
              ),
            ),
            leading: IconButton(
              icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                onPressed: _createNewCollection,
                icon: const Icon(Icons.create_new_folder_outlined, color: AppColors.secondary),
              ),
            ],
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              labelColor: AppColors.secondary,
              unselectedLabelColor: AppColors.grey,
              indicatorColor: AppColors.secondary,
              tabs: [
                const Tab(text: 'All Saved'),
                ...names.map((name) => Tab(text: name)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildAllSavedTab(),
              ...names.map((name) => _buildCollectionTab(name)),
            ],
          ),
        );
      },
      loading: () => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(child: Text('Error: $e', style: TextStyle(color: theme.colorScheme.onSurface))),
      ),
    );
  }

  Widget _buildAllSavedTab() {
    final savedAsync = ref.watch(savedListingsProvider);
    return savedAsync.when(
      data: (listings) => _buildListingsGrid(listings, prefix: 'all_saved'),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildCollectionTab(String name) {
    final listingsAsync = ref.watch(collectionListingsProvider(name));
    return listingsAsync.when(
      data: (listings) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.folder_open_rounded, color: Colors.grey),
                const SizedBox(width: 8),
                Text(
                  '$name (${listings.length} items)',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => _deleteCollection(name),
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                ),
              ],
            ),
          ),
          Expanded(child: _buildListingsGrid(listings, prefix: 'coll_${name.replaceAll(' ', '_').toLowerCase()}')),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
    );
  }

  Widget _buildListingsGrid(List<dynamic> listings, {String prefix = 'saved'}) {
    if (listings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 80, color: Colors.grey.shade300),
            const SizedBox(height: 16),
            const Text('No items yet.'),
          ],
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.72,
      ),
      itemCount: listings.length,
      itemBuilder: (context, index) {
        return MarketplaceCard(
          listing: listings[index], 
          index: index,
          heroTag: 'hero_${prefix}_${listings[index].id}',
        );
      },
    );
  }

  void _deleteCollection(String name) {
    final user = ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Collection?'),
        content: Text('Are you sure you want to delete "$name"? The items will stay in your "All Saved" list.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(marketplaceRepositoryProvider).deleteCollection(user.uid, name);
              Navigator.pop(context);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
