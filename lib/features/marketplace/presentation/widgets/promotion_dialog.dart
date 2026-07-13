import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../shared/providers.dart';
import '../../../monetization/shared/providers.dart';
import '../../../monetization/domain/models/payment_record.dart';

class PromotionDialog extends ConsumerStatefulWidget {
  final Listing listing;

  const PromotionDialog({super.key, required this.listing});

  @override
  ConsumerState<PromotionDialog> createState() => _PromotionDialogState();
}

class _PromotionDialogState extends ConsumerState<PromotionDialog> {
  bool _isLoading = false;

  Future<void> _activateFeature(PaymentType type, {int days = 7}) async {
    setState(() => _isLoading = true);
    try {
      final user = ref.read(appUserProvider).valueOrNull;
      if (user == null) return;

      final monetizationRepo = ref.read(monetizationRepositoryProvider);
      
      await monetizationRepo.activateFreePremiumFeature(
        userId: user.uid,
        itemId: widget.listing.id,
        type: type,
        metadata: {'durationDays': days},
      );

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${type.name.toUpperCase()} activated successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerified = user?.isIdentityVerified == true || 
                       user?.isStudentVerified == true || 
                       user?.accountType == 'business';

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      surfaceTintColor: Colors.transparent,
      title: Column(
        children: [
          const Icon(Icons.auto_awesome, color: Colors.orange, size: 48),
          const SizedBox(height: 16),
          Text(
            'Promote Your Listing',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isVerified)
            InkWell(
              onTap: () {
                Navigator.pop(context);
                context.push('/trust-center');
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, color: Colors.orange, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Verification Required',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Verify identity to unlock free promotions.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Colors.orange.shade900, size: 20),
                  ],
                ),
              ),
            )
          else
            const Text(
              'Verified Early Bird Benefit: Premium visibility is currently FREE!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.green, fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 16),
          _PromotionOption(
            title: 'Boost to Top',
            description: 'Instantly move your item to the very top of the marketplace feed.',
            icon: Icons.bolt,
            color: Colors.orange,
            enabled: isVerified && !_isLoading,
            onTap: () => _activateFeature(PaymentType.boost),
          ),
          const SizedBox(height: 12),
          _PromotionOption(
            title: 'Feature Listing',
            description: 'Stay highlighted in the "Featured" section for 7 days.',
            icon: Icons.star,
            color: Colors.blue,
            enabled: isVerified && !widget.listing.isFeatured && !_isLoading,
            onTap: () => _activateFeature(PaymentType.feature, days: 7),
            isActive: widget.listing.isFeatured,
          ),
          const SizedBox(height: 12),
          _PromotionOption(
            title: 'Sponsored Search',
            description: 'Appear in top search results even if the query isn\'t an exact match.',
            icon: Icons.ads_click,
            color: Colors.purple,
            enabled: isVerified && !widget.listing.isSponsored && !_isLoading,
            onTap: () => _activateFeature(PaymentType.sponsoredSearch, days: 3),
            isActive: widget.listing.isSponsored,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Maybe Later', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

class _PromotionOption extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;
  final bool isActive;

  const _PromotionOption({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: enabled 
              ? color.withValues(alpha: 0.05) 
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive 
                ? color 
                : enabled ? color.withValues(alpha: 0.2) : theme.colorScheme.outlineVariant,
            width: isActive ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: enabled ? theme.colorScheme.onSurface : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isActive ? 'ALREADY ACTIVE' : description,
                    style: TextStyle(
                      fontSize: 11,
                      color: isActive ? color : theme.colorScheme.onSurfaceVariant,
                      fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ],
              ),
            ),
            if (isActive)
              Icon(Icons.check_circle, color: color, size: 20)
            else if (enabled)
              const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
          ],
        ),
      ),
    );
  }
}
