import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../domain/models/note.dart';
import '../../shared/providers.dart';

class NoteCard extends ConsumerWidget {
  final NoteListing note;
  final String? userUniversity;
  final VoidCallback onTap;
  final int index;

  const NoteCard({
    super.key,
    required this.note,
    this.userUniversity,
    required this.onTap,
    this.index = 0,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserId = ref.watch(firebaseAuthProvider).currentUser?.uid;
    final isAuthor = currentUserId == note.authorId;
    
    final isSameUni = userUniversity != null && note.university == userUniversity;
    final isRecent = DateTime.now().difference(note.createdAt).inDays < 3;
    final isPopular = note.downloadsCount > 50;
    
    final progressAsync = ref.watch(noteProgressProvider(note.id));

    return TweenAnimationBuilder<double>(
      duration: Duration(milliseconds: 400 + (index * 50).clamp(0, 400)),
      tween: Tween(begin: 0.0, end: 1.0),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSameUni ? Colors.indigo.withOpacity(0.1) : Colors.grey.shade100,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildBadge(note.noteType, Colors.indigo.shade50, Colors.indigo),
                          const SizedBox(width: 8),
                          if (isSameUni)
                            _buildBadge('Your Campus', Colors.green.shade50, Colors.green.shade700, icon: Icons.verified_user_outlined),
                          if (isPopular)
                            _buildBadge('Popular', Colors.orange.shade50, Colors.orange.shade700, icon: Icons.trending_up),
                          if (isRecent)
                            _buildBadge('New', Colors.blue.shade50, Colors.blue.shade700),
                        ],
                      ),
                    ),
                  ),
                  if (isAuthor)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionIcon(
                          icon: Icons.edit_outlined,
                          color: Colors.indigo,
                          onTap: () => context.push('/add-note', extra: note),
                        ),
                        const SizedBox(width: 6),
                        _buildActionIcon(
                          icon: Icons.delete_outline,
                          color: Colors.red,
                          onTap: () => _confirmDelete(context, ref),
                        ),
                      ],
                    )
                  else
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        progressAsync.valueOrNull?.isBookmarked == true ? Icons.bookmark : Icons.bookmark_border,
                        size: 18,
                        color: progressAsync.valueOrNull?.isBookmarked == true ? Colors.indigo : Colors.grey,
                      ),
                      onPressed: () => ref.read(studyControllerProvider).toggleBookmark(note.id),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Hero(
                    tag: 'note_icon_${note.id}',
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.indigo.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.description_rounded, color: Colors.indigo, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.unitCode,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.indigo.shade700),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.unitName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          note.course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (progressAsync.valueOrNull != null && progressAsync.valueOrNull!.progress > 0) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progressAsync.valueOrNull!.progress,
                          backgroundColor: Colors.indigo.shade50,
                          valueColor: const AlwaysStoppedAnimation(Colors.indigo),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progressAsync.valueOrNull!.progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.indigo.shade300),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: Colors.indigo.shade50,
                    child: Text(
                      note.authorName.isNotEmpty ? note.authorName[0].toUpperCase() : 'U',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.authorName,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          note.university,
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (note.price > 0)
                        Text('KES ${note.price.toInt()}', style: const TextStyle(fontWeight: FontWeight.w900, color: Colors.black87))
                      else
                        const Text('FREE', style: TextStyle(fontWeight: FontWeight.w900, color: Colors.green)),
                      Text('${note.downloadsCount} downloads', style: TextStyle(fontSize: 10, color: Colors.grey.shade400)),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionIcon({required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.2)),
            ),
            child: Icon(icon, color: color, size: 16),
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
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

  Widget _buildBadge(String text, Color bgColor, Color textColor, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: textColor),
            const SizedBox(width: 4),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: textColor, letterSpacing: 0.8),
          ),
        ],
      ),
    );
  }
}
