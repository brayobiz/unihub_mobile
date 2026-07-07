import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';
import '../../../../services/history_service.dart';
import '../../../../services/download_service.dart';
import 'package:path/path.dart' as p;
import 'package:unihub_mobile/features/chat/domain/models/chat_context.dart';
import 'package:unihub_mobile/features/chat/shared/providers.dart';
import 'package:open_filex/open_filex.dart';

class NoteDetailScreen extends ConsumerStatefulWidget {
  final NoteListing? note;
  final String noteId;

  const NoteDetailScreen({
    super.key, 
    this.note, 
    required this.noteId,
  });

  @override
  ConsumerState<NoteDetailScreen> createState() => _NoteDetailScreenState();
}

class _NoteDetailScreenState extends ConsumerState<NoteDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.note != null) {
        _recordHistory(widget.note!);
      }
    });
  }

  void _recordHistory(NoteListing note) {
    ref.read(recentHistoryProvider.notifier).addItem(HistoryItem(
      id: note.id,
      type: 'note',
      title: note.title,
      timestamp: DateTime.now(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final noteAsync = ref.watch(noteByIdProvider(widget.noteId));

    return noteAsync.when(
      data: (note) {
        final currentNote = note ?? widget.note;
        if (currentNote == null) {
          return const Scaffold(body: Center(child: Text('Study resource no longer available.')));
        }

        if (note != null) {
           WidgetsBinding.instance.addPostFrameCallback((_) => _recordHistory(note));
        }

        final progressAsync = ref.watch(noteProgressProvider(currentNote.id));

        return Scaffold(
          backgroundColor: theme.colorScheme.surface,
          body: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildSliverAppBar(context, ref, currentNote, progressAsync.valueOrNull?.isBookmarked ?? false),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeaderCard(context, currentNote, progressAsync.valueOrNull?.progress ?? 0.0),
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Academic Details'),
                      const SizedBox(height: 16),
                      _buildInfoRow(context, 'University', currentNote.university, Icons.school_outlined),
                      _buildInfoRow(context, 'Category', currentNote.subjectCategory, Icons.category_outlined),
                      _buildInfoRow(context, 'Type', currentNote.noteType, Icons.label_outline),
                      _buildInfoRow(context, 'Year', 'Year ${currentNote.yearOfStudy}', Icons.calendar_today_outlined),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Contributor Info'),
                      const SizedBox(height: 16),
                      _buildContributorInfo(context, theme, currentNote),
                      _buildInfoRow(context, 'Date', DateFormat('MMM dd, yyyy').format(currentNote.createdAt), Icons.event_available_outlined),
                      _buildInfoRow(context, 'Price', currentNote.price == 0 ? 'FREE' : 'KES ${currentNote.price}', Icons.payments_outlined),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Topics covered'),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: currentNote.tags.map((tag) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                          ),
                          child: Text(
                            '#$tag', 
                            style: TextStyle(fontSize: 13, color: theme.colorScheme.primary, fontWeight: FontWeight.bold)
                          ),
                        )).toList(),
                      ),

                      const SizedBox(height: 32),
                      _buildSectionTitle(context, 'Description'),
                      const SizedBox(height: 12),
                      Text(
                        currentNote.description.isEmpty ? 'No additional description provided.' : currentNote.description,
                        style: TextStyle(fontSize: 15, height: 1.6, color: theme.colorScheme.onSurfaceVariant),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomBar(context, ref, currentNote, progressAsync.valueOrNull?.progress ?? 0.0),
        );
      },
      loading: () => widget.note != null 
          ? _buildInitialState(widget.note!)
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  Widget _buildInitialState(NoteListing note) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(pinned: true, title: Text(note.title)),
          const SliverFillRemaining(child: Center(child: CircularProgressIndicator())),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, NoteListing note, bool isBookmarked) {
    final theme = Theme.of(context);
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final isAuthor = currentUser?.uid == note.authorId;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: theme.colorScheme.surface,
      foregroundColor: theme.colorScheme.onSurface,
      title: Text(
        'Note Details',
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.onSurface,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      actions: [
        if (isAuthor) ...[
          IconButton(
            icon: Icon(Icons.edit_outlined, color: theme.colorScheme.primary),
            onPressed: () => context.push('/add-note', extra: note),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            onPressed: () => _confirmDeletion(context, ref, note),
          ),
        ],
        IconButton(
          icon: const Icon(Icons.share_outlined),
          onPressed: () => _shareNote(context, note),
        ),
        IconButton(
          icon: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? theme.colorScheme.primary : theme.colorScheme.onSurface,
          ),
          onPressed: () => ref.read(studyControllerProvider).toggleBookmark(note.id),
        ),
      ],
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref, NoteListing note) {
    // ... existing code ...
  }

  void _shareNote(BuildContext context, NoteListing note) {
    final chatContext = ChatContext(
      type: 'notes',
      id: note.id,
      title: note.title,
      metadata: {
        'unitCode': note.unitCode,
        'authorName': note.authorName,
      },
    );
    context.push('/share-to-chat', extra: chatContext);
    ref.read(notesRepositoryProvider).incrementShareCount(note.id);
  }

  Widget _buildHeaderCard(BuildContext context, NoteListing note, double progress) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.primary.withOpacity(0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Hero(
                tag: 'note_icon_${note.id}',
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.description_rounded, size: 40, color: Colors.white),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      note.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${note.unitCode} - ${note.unitName}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (progress > 0) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      valueColor: const AlwaysStoppedAnimation(Colors.white),
                      minHeight: 8,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    final theme = Theme.of(context);
    return Text(
      title, 
      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5, color: theme.colorScheme.onSurface)
    );
  }

  Widget _buildContributorInfo(BuildContext context, ThemeData theme, NoteListing note) {
    return Consumer(
      builder: (context, ref, child) {
        final contributorAsync = ref.watch(userByIdProvider(note.authorId));

        return contributorAsync.when(
          data: (user) {
            if (user == null) {
              return const SizedBox.shrink();
            }
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    backgroundImage: user.photoUrl != null ? NetworkImage(user.photoUrl!) : null,
                    child: user.photoUrl == null
                      ? Text(user.fullName[0].toUpperCase(), style: TextStyle(color: theme.colorScheme.primary, fontWeight: FontWeight.bold))
                      : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                user.fullName,
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (user.isVerified) ...[
                              const SizedBox(width: 4),
                              Icon(Icons.verified, color: theme.colorScheme.primary, size: 14),
                            ],
                          ],
                        ),
                        Row(
                          children: [
                            Icon(Icons.shield_rounded, size: 10, color: user.trustScore > 80 ? AppColors.success : AppColors.warning),
                            const SizedBox(width: 4),
                            Text(
                              'Trust ${user.trustScore.toInt()}% • Contributor',
                              style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (ref.watch(authStateProvider).valueOrNull?.uid != user.uid)
                    TextButton.icon(
                      onPressed: () => _handleChat(context, ref, note, user),
                      icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                      label: const Text('Chat'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ],
                ),
              );
            },
          loading: () => const SizedBox(height: 50, child: Center(child: LinearProgressIndicator())),
          error: (_, __) => _buildBasicContributorRow(context, theme, note),
        );
      },
    );
  }

  Widget _buildBasicContributorRow(BuildContext context, ThemeData theme, NoteListing note) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.person_outline, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Shared by', style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
                Text(note.authorName, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleChat(BuildContext context, WidgetRef ref, NoteListing note, dynamic user) async {
    final currentUser = ref.read(authStateProvider).valueOrNull;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to chat')));
      return;
    }

    final chatContext = ChatContext(
      type: 'notes',
      id: note.id,
      title: note.title,
    );

    final conversationId = await ref.read(chatRepositoryProvider).getOrCreateConversation(
      participantIds: [currentUser.uid, note.authorId],
      context: chatContext,
    );

    if (context.mounted) {
      context.push('/chat', extra: {
        'conversationId': conversationId,
        'otherUserName': user.fullName,
        'context': chatContext,
      });
    }
  }

  Widget _buildInfoRow(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: theme.colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: theme.colorScheme.onSurface)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, NoteListing note, double progress) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: () => _openFile(context, ref, note),
            icon: Icon(progress > 0 ? Icons.play_arrow_rounded : Icons.menu_book_rounded),
            label: Text(
              progress > 0 ? 'Resume Studying' : (note.price == 0 ? 'Start Studying' : 'Buy & Study'), 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  bool _isNavigating = false;

  Future<void> _openFile(BuildContext context, WidgetRef ref, NoteListing note) async {
    if (_isNavigating) return;
    if (note.fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not available')));
      return;
    }

    setState(() => _isNavigating = true);

    // Trigger in background to avoid blocking navigation
    ref.read(studyControllerProvider).markAsOpened(note.id).catchError((_) => null);

    try {
      String ext = p.extension(note.fileUrl).toLowerCase();
      if (ext.isEmpty || ext.length > 5) {
        if (note.fileUrl.contains('.pdf')) ext = '.pdf';
        else if (note.fileUrl.contains('.docx')) ext = '.docx';
        else if (note.fileUrl.contains('.doc')) ext = '.doc';
        else if (note.fileUrl.contains('.pptx')) ext = '.pptx';
        else if (note.fileUrl.contains('.ppt')) ext = '.ppt';
        else ext = '.pdf'; // Default
      }
      
      final safeTitle = note.title.replaceAll(RegExp(r'[^\w\s]+'), '_');
      final fileName = '$safeTitle$ext';
      
      final downloadService = ref.read(downloadServiceProvider);
      final isDownloaded = await downloadService.isFileDownloaded(fileName);
      final savePath = isDownloaded ? await downloadService.getSavePath(fileName) : null;

      if (context.mounted) {
        context.push('/note-reader', extra: {
          'note': note,
          'filePath': savePath,
          'initialPage': 0,
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
        if (mounted) setState(() => _isNavigating = false);
      });
    }
  }
}
