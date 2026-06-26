import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';

import '../../../../services/download_service.dart';
import 'package:path/path.dart' as p;
import 'package:open_filex/open_filex.dart';

class NoteDetailScreen extends ConsumerWidget {
  final NoteListing note;
  const NoteDetailScreen({super.key, required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progressAsync = ref.watch(noteProgressProvider(note.id));

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context, ref, progressAsync.valueOrNull?.isBookmarked ?? false),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeaderCard(progressAsync.valueOrNull?.progress ?? 0.0),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Academic Details'),
                  const SizedBox(height: 16),
                  _buildInfoRow('University', note.university, Icons.school_outlined),
                  _buildInfoRow('Category', note.subjectCategory, Icons.category_outlined),
                  _buildInfoRow('Type', note.noteType, Icons.label_outline),
                  _buildInfoRow('Year', 'Year ${note.yearOfStudy}', Icons.calendar_today_outlined),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Contributor Info'),
                  const SizedBox(height: 16),
                  _buildInfoRow('Shared by', note.authorName, Icons.person_outline),
                  _buildInfoRow('Date', DateFormat('MMM dd, yyyy').format(note.createdAt), Icons.event_available_outlined),
                  _buildInfoRow('Price', note.price == 0 ? 'FREE' : 'KES ${note.price}', Icons.payments_outlined),
                  
                  const SizedBox(height: 32),
                  _buildSectionTitle('Topics covered'),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: note.tags.map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FB),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade100),
                      ),
                      child: Text(
                        '#$tag', 
                        style: TextStyle(fontSize: 13, color: Colors.indigo.shade700, fontWeight: FontWeight.bold)
                      ),
                    )).toList(),
                  ),

                  const SizedBox(height: 32),
                  _buildSectionTitle('Description'),
                  const SizedBox(height: 12),
                  Text(
                    note.description.isEmpty ? 'No additional description provided.' : note.description,
                    style: const TextStyle(fontSize: 15, height: 1.6, color: Colors.black54),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomBar(context, ref, progressAsync.valueOrNull?.progress ?? 0.0),
    );
  }

  Widget _buildSliverAppBar(BuildContext context, WidgetRef ref, bool isBookmarked) {
    final currentUser = ref.watch(firebaseAuthProvider).currentUser;
    final isAuthor = currentUser?.uid == note.authorId;

    return SliverAppBar(
      expandedHeight: 120,
      floating: false,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black,
      title: Text(
        'Study Resource',
        style: GoogleFonts.plusJakartaSans(
          fontWeight: FontWeight.bold,
          color: Colors.black,
          fontSize: 16,
        ),
      ),
      centerTitle: true,
      actions: [
        if (isAuthor) ...[
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Colors.indigo),
            onPressed: () => context.push('/add-note', extra: note),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: () => _confirmDeletion(context, ref),
          ),
        ],
        IconButton(
          icon: Icon(
            isBookmarked ? Icons.bookmark : Icons.bookmark_border,
            color: isBookmarked ? Colors.indigo : Colors.black87,
          ),
          onPressed: () => ref.read(studyControllerProvider).toggleBookmark(note.id),
        ),
      ],
    );
  }

  void _confirmDeletion(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Resource?'),
        content: const Text('This will permanently remove this study resource from UniHub. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog
              await ref.read(notesRepositoryProvider).deleteNote(note.id);
              if (context.mounted) {
                context.pop(); // Go back to list
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Resource deleted successfully')),
                );
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(double progress) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.indigo.shade600, Colors.indigo.shade800],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.indigo.withOpacity(0.3),
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
                      style: GoogleFonts.plusJakartaSans(
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

  Widget _buildSectionTitle(String title) {
    return Text(
      title, 
      style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.5)
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.indigo.shade50,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: Colors.indigo),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.w500)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(BuildContext context, WidgetRef ref, double progress) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, -5))],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 60,
          child: FilledButton.icon(
            onPressed: () => _openFile(context, ref),
            icon: Icon(progress > 0 ? Icons.play_arrow_rounded : Icons.menu_book_rounded),
            label: Text(
              progress > 0 ? 'Resume Studying' : (note.price == 0 ? 'Start Studying' : 'Buy & Study'), 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
            ),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.indigo,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              elevation: 0,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, WidgetRef ref) async {
    if (note.fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('File not available')));
      return;
    }

    // Mark as opened in history
    await ref.read(studyControllerProvider).markAsOpened(note.id);

    // If it's a new note, set some initial progress
    final currentProgress = await ref.read(noteProgressProvider(note.id).future);
    if (currentProgress == null || currentProgress.progress == 0) {
      await ref.read(studyControllerProvider).updateProgress(note.id, progress: 0.1, page: 0);
    }

    try {
      final fileName = '${note.title.replaceAll(RegExp(r'[^\w\s]+'), '_')}${p.extension(note.fileUrl).isEmpty ? '.pdf' : p.extension(note.fileUrl)}';
      
      final downloadService = ref.read(downloadServiceProvider);
      final isDownloaded = await downloadService.isFileDownloaded(fileName);
      final savePath = await downloadService.getSavePath(fileName);

      if (isDownloaded) {
        final progress = await ref.read(noteProgressProvider(note.id).future);

        if (context.mounted) {
          context.push('/note-reader', extra: {
            'note': note,
            'filePath': savePath,
            'initialPage': progress?.lastPage ?? 0,
          });
        }
        return;
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Starting download... check notifications')),
        );
      }

      await downloadService.downloadFile(
        url: note.fileUrl,
        fileName: fileName,
        noteId: note.id,
      );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }
}
