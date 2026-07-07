import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import 'package:unihub_mobile/features/auth/shared/providers.dart';
import '../../domain/models/roommate_profile.dart';
import '../../../../core/constants/campus_constants.dart';
import 'package:intl/intl.dart';

class RoommateCard extends ConsumerWidget {
  final RoommateProfile profile;
  final VoidCallback onTap;

  const RoommateCard({super.key, required this.profile, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final userAsync = ref.watch(publicUserProvider(profile.userId));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: theme.colorScheme.primary.withValues(alpha: 0.1),
                  backgroundImage: profile.profileImage.isNotEmpty 
                    ? NetworkImage(profile.profileImage) 
                    : null,
                  child: profile.profileImage.isEmpty 
                    ? Icon(Icons.person, color: theme.colorScheme.primary, size: 30) 
                    : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    profile.name,
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                userAsync.when(
                                  data: (user) => (user != null && user.isVerified)
                                    ? Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Icon(Icons.verified, color: theme.colorScheme.primary, size: 14),
                                      )
                                    : const SizedBox.shrink(),
                                  loading: () => const SizedBox.shrink(),
                                  error: (_, __) => const SizedBox.shrink(),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              profile.gender,
                              style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      userAsync.when(
                        data: (user) => user != null
                          ? Row(
                              children: [
                                Icon(Icons.shield_rounded, size: 10, color: user.trustScore > 80 ? AppColors.success : AppColors.warning),
                                const SizedBox(width: 4),
                                Text(
                                  'Trust ${user.trustScore.toInt()}%',
                                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                              ],
                            )
                          : const SizedBox.shrink(),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${profile.course} • Year ${profile.yearOfStudy}',
                        style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Divider(height: 1, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoColumn(context, 'Budget', currencyFormat.format(profile.budget)),
                _buildInfoColumn(context, 'Location', profile.preferredLocation),
                _buildInfoColumn(context, 'Campus', CampusConstants.getDisplayName(profile.campus)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: profile.lifestyle.take(3).map((item) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.3)),
                ),
                child: Text(
                  item,
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, fontWeight: FontWeight.w500),
                ),
              )).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoColumn(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 10)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: theme.colorScheme.onSurface)),
      ],
    );
  }
}
