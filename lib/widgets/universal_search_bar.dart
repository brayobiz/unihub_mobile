import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

class UniversalSearchBar extends StatelessWidget {
  final VoidCallback? onTap;
  final String? hintText;

  const UniversalSearchBar({
    super.key, 
    this.onTap,
    this.hintText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: onTap ?? () => context.push('/global-search'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: theme.colorScheme.onSurfaceVariant, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                hintText ?? 'Search marketplace, housing, notes...',
                style: GoogleFonts.plusJakartaSans(
                  color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.tune_rounded, color: theme.colorScheme.onSurfaceVariant, size: 16),
            ),
          ],
        ),
      ),
    );
  }
}
