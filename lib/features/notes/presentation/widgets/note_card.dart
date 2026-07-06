import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
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
    final theme = Theme.of(context);
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
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: isSameUni ? theme.colorScheme.primary.withOpacity(0.1) : theme.colorScheme.outlineVariant.withOpacity(0.5),
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
                          _buildBadge(note.noteType, theme.colorScheme.primary.withOpacity(0.1), theme.colorScheme.primary),
                          const SizedBox(width: 8),
                          if (isSameUni)
                            _buildBadge('Your Campus', AppColors.success.withOpacity(0.1), AppColors.success, icon: Icons.verified_user_outlined),
                          if (isPopular)
                            _buildBadge('Popular', AppColors.warning.withOpacity(0.1), AppColors.warning, icon: Icons.trending_up),
                          if (isRecent)
                            _buildBadge('New', theme.colorScheme.secondary.withOpacity(0.1), theme.colorScheme.secondary),
                        ],
                      ),
                    ),
                  ),
                  if (isAuthor)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildActionIcon(
                          context,
                          icon: Icons.edit_outlined,
                          color: theme.colorScheme.primary,
                          onTap: () => context.push('/add-note', extra: note),
                        ),
                        const SizedBox(width: 6),
                        _buildActionIcon(
                          context,
                          icon: Icons.delete_outline,
                          color: AppColors.error,
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
                        color: progressAsync.valueOrNull?.isBookmarked == true ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
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
                        color: theme.colorScheme.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.description_rounded, color: theme.colorScheme.primary, size: 28),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                            height: 1.2,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            note.unitCode,
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: theme.colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          note.unitName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface, fontWeight: FontWeight.w500),
                        ),
                        Text(
                          note.course,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                        ),
                        if (note.description.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            note.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant, height: 1.3),
                          ),
                        ],
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
                          backgroundColor: theme.colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                          minHeight: 4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${(progressAsync.valueOrNull!.progress * 100).toInt()}%',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
              const SizedBox(height: 14),
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    child: Text(
                      note.authorName.isNotEmpty ? note.authorName[0].toUpperCase() : 'U',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.primary),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          note.authorName,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                        ),
                        Text(
                          note.university,
                          style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
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
                        Text('KES ${note.price.toInt()}', style: TextStyle(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface))
                      else
                        const Text('FREE', style: TextStyle(fontWeight: FontWeight.w900, color: AppColors.success)),
                      Text('${note.downloadsCount} readers', style: TextStyle(fontSize: 10, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7))),
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

  Widget _buildActionIcon(BuildContext context, {required IconData icon, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.2)),
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
