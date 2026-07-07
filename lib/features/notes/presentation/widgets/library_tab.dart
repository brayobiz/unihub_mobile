import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path/path.dart' as p;
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../shared/providers.dart';
import '../../domain/models/study_progress.dart';
import '../../domain/models/note.dart';
import '../../../../services/download_service.dart';
import '../widgets/note_card.dart';

class LibraryTab extends ConsumerStatefulWidget {
  const LibraryTab({super.key});

  @override
  ConsumerState<LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<LibraryTab> {
  bool _isNavigating = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final continueReading = ref.watch(continueReadingProvider);
    final recentlyOpened = ref.watch(recentlyOpenedProvider);
    final uploads = ref.watch(userNotesProvider);
    final bookmarks = ref.watch(bookmarksProvider);

    final isEmpty = (continueReading.valueOrNull?.isEmpty ?? true) &&
                    (recentlyOpened.valueOrNull?.isEmpty ?? true) &&
                    (uploads.valueOrNull?.isEmpty ?? true) &&
                    (bookmarks.valueOrNull?.isEmpty ?? true);

    if (isEmpty && !continueReading.isLoading && !recentlyOpened.isLoading) {
      return _buildFullEmptyState(context);
    }

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 20),
      children: [
        continueReading.when(
          data: (data) => data.isEmpty 
            ? const SizedBox.shrink()
            : _buildContinueReadingSection(context, ref, data),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),

        recentlyOpened.when(
          data: (data) => data.isEmpty
            ? const SizedBox.shrink()
            : _buildHorizontalSection(context, ref, 'Recently Opened', data, isRecentlyOpened: true),
          loading: () => const SizedBox.shrink(),
          error: (e, _) => const SizedBox.shrink(),
        ),

        uploads.when(
          data: (data) => data.isEmpty
            ? const SizedBox.shrink()
            : _buildHorizontalSection(context, ref, 'My Uploads', data, isUploads: true),
          loading: () => SizedBox(height: 140, child: Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))),
          error: (e, _) => const SizedBox.shrink(),
        ),

        bookmarks.when(
          data: (data) => data.isEmpty 
            ? const SizedBox.shrink()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildSectionHeader(context, 'Saved for Later', Icons.bookmark_border),
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(children: data.map((p) => _buildProgressTile(context, ref, p)).toList()),
                  ),
                ],
              ),
          loading: () => Center(child: CircularProgressIndicator(color: theme.colorScheme.primary)),
          error: (e, _) => const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildContinueReadingSection(BuildContext context, WidgetRef ref, List<StudyProgress> items) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Text(
            'Continue Reading',
            style: theme.textTheme.titleLarge?.copyWith(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: -0.5),
          ),
        ),
        SizedBox(
          height: 170,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final progress = items[index];
              final noteAsync = ref.watch(noteByIdProvider(progress.noteId));
              return noteAsync.when(
                data: (note) => note != null ? _buildProminentContinueCard(context, ref, note, progress) : const SizedBox.shrink(),
                loading: () => const SizedBox(width: 280),
                error: (e, _) => const SizedBox.shrink(),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildHorizontalSection(BuildContext context, WidgetRef ref, String title, List<dynamic> items, {bool isRecentlyOpened = false, bool isUploads = false}) {
    final theme = Theme.of(context);
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
                style: theme.textTheme.titleMedium?.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              if (isRecentlyOpened)
                TextButton(
                  onPressed: () => _showClearHistoryDialog(context, ref),
                  child: Text('Clear', style: TextStyle(color: theme.colorScheme.primary, fontSize: 12)),
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
              
              if (isRecentlyOpened) {
                final progress = item as StudyProgress;
                final noteAsync = ref.watch(noteByIdProvider(progress.noteId));
                return noteAsync.when(
                  data: (note) => note != null ? _buildRecentCard(context, ref, note, progress) : const SizedBox.shrink(),
                  loading: () => const SizedBox(width: 200),
                  error: (e, _) => const SizedBox.shrink(),
                );
              } else {
                final note = item as NoteListing;
                return _buildSimpleNoteCard(context, ref, note);
              }
            },
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildProminentContinueCard(BuildContext context, WidgetRef ref, NoteListing note, StudyProgress progress) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _resumeNote(context, ref, note),
      onLongPress: () => _showRemoveFromHistoryDialog(context, ref, note),
      child: Container(
        width: 280,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [theme.colorScheme.primary, theme.colorScheme.primary.withValues(alpha: 0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: theme.colorScheme.primary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.menu_book_rounded, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        note.unitCode,
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Page ${progress.lastPage + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  '${(progress.progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress.progress,
                backgroundColor: Colors.white.withValues(alpha: 0.1),
                valueColor: const AlwaysStoppedAnimation(Colors.white),
                minHeight: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentCard(BuildContext context, WidgetRef ref, NoteListing note, StudyProgress progress) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _resumeNote(context, ref, note),
      child: Container(
        width: 200,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 8),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 8, offset: const Offset(0, 4))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 14, color: theme.colorScheme.primary.withValues(alpha: 0.7)),
                const SizedBox(width: 4),
                Text(
                  _formatTimeAgo(progress.lastAccessed),
                  style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            Text(
              note.title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2, color: theme.colorScheme.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              note.unitCode,
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  String _formatTimeAgo(DateTime date) {
    final diff = DateTime.now().difference(date);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildSimpleNoteCard(BuildContext context, WidgetRef ref, NoteListing note) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => _resumeNote(context, ref, note),
      child: Container(
        width: 220,
        margin: const EdgeInsets.only(left: 4, right: 12, bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))
          ],
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.description_rounded, color: theme.colorScheme.primary, size: 18),
                ),
                const Spacer(),
                _buildActionIcon(
                  context,
                  icon: Icons.edit_outlined,
                  color: theme.colorScheme.primary,
                  onTap: () => context.push('/add-note', extra: note),
                ),
                const SizedBox(width: 4),
                _buildActionIcon(
                  context,
                  icon: Icons.delete_outline,
                  color: AppColors.error,
                  onTap: () => _confirmDelete(context, ref, note),
                ),
              ],
            ),
            const Spacer(),
            Text(
              note.title,
              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 13, height: 1.2, color: theme.colorScheme.onSurface),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              note.unitCode,
              style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon(BuildContext context, {required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 14),
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
            child: const Text('Delete', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
        ),
      ],
    );
  }

  Widget _buildProgressTile(BuildContext context, WidgetRef ref, StudyProgress progress) {
    final noteAsync = ref.watch(noteByIdProvider(progress.noteId));

    return noteAsync.when(
      data: (note) {
        if (note == null) return const SizedBox.shrink();
        return NoteCard(
          note: note,
          onTap: () => _resumeNote(context, ref, note),
        );
      },
      loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
      error: (e, _) => const SizedBox.shrink(),
    );
  }

  Widget _buildFullEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_stories_outlined, size: 80, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
            ),
            const SizedBox(height: 32),
            Text(
              'Your Library is empty',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
            ),
            const SizedBox(height: 12),
            Text(
              'Start reading notes from the Discover tab and they will automatically appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.6, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('This will remove all recently opened documents. Your bookmarks and uploads will be kept.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              ref.read(studyControllerProvider).clearHistory();
              Navigator.pop(context);
            },
            child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _showRemoveFromHistoryDialog(BuildContext context, WidgetRef ref, dynamic note) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: theme.colorScheme.outlineVariant, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 20),
            Text(
              note.title,
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),
            Divider(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.error),
              title: const Text('Remove from Library', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.w600)),
              subtitle: Text('This will clear your study progress for this document.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
              onTap: () {
                ref.read(studyControllerProvider).removeFromHistory(note.id);
                Navigator.pop(context);
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _resumeNote(BuildContext context, WidgetRef ref, dynamic note) async {
    if (_isNavigating) return;
    _isNavigating = true;

    try {
      String ext = p.extension(note.fileUrl).toLowerCase();
      if (ext.isEmpty || ext.length > 5) {
        if (note.fileUrl.contains('.pdf')) ext = '.pdf';
        else if (note.fileUrl.contains('.docx')) ext = '.docx';
        else if (note.fileUrl.contains('.doc')) ext = '.doc';
        else if (note.fileUrl.contains('.pptx')) ext = '.pptx';
        else if (note.fileUrl.contains('.ppt')) ext = '.ppt';
        else ext = '.pdf';
      }

      final safeTitle = note.title.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final fileName = '$safeTitle$ext';

      final downloadService = ref.read(downloadServiceProvider);
      final isDownloaded = await downloadService.isFileDownloaded(fileName);
      final savePath = isDownloaded ? await downloadService.getSavePath(fileName) : null;

      final progress = await ref.read(noteProgressProvider(note.id).future);
      if (context.mounted) {
        context.push('/note-reader', extra: {
          'note': note,
          'filePath': savePath,
          'initialPage': progress?.lastPage ?? 0,
        });
      }
    } catch (e) {
      if (context.mounted) {
        context.push('/note-reader', extra: {
          'note': note,
          'filePath': null,
          'initialPage': 0,
        });
      }
    } finally {
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _isNavigating = false;
          });
        }
      });
    }
  }
}
