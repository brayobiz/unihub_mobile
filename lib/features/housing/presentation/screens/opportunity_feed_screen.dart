import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/vacancy_request.dart';
import '../../shared/providers.dart';
import 'package:intl/intl.dart';

class OpportunityFeedScreen extends ConsumerWidget {
  const OpportunityFeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    final isVerifiedPlug = user?.verifiedRoles.contains('housePlug') ?? false;

    if (!isVerifiedPlug) {
      return Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Text('New Opportunities', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          backgroundColor: theme.colorScheme.surface,
          foregroundColor: theme.colorScheme.onSurface,
          elevation: 0,
        ),
        body: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_person_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
              const SizedBox(height: 24),
              Text(
                'Exclusive Professional Access',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900, color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'The Opportunity Feed is reserved for verified Housing Plugs. Verify your role in the Trust Center to view and claim leads.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.5),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.push('/verify-professional/housePlug'),
                style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.primary),
                child: const Text('Apply for Access'),
              ),
            ],
          ),
        ),
      );
    }

    final opportunitiesAsync = ref.watch(vacancyOpportunitiesProvider);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text('New Opportunities', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        backgroundColor: theme.colorScheme.surface,
        elevation: 0,
        foregroundColor: theme.colorScheme.onSurface,
      ),
      body: opportunitiesAsync.when(
        data: (opportunities) => opportunities.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: opportunities.length,
                itemBuilder: (context, index) => _buildOpportunityCard(context, opportunities[index], ref),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 64, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text('No new opportunities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.onSurface)),
          Text('Check back later for new vacancy leads.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(BuildContext context, VacancyRequest opp, WidgetRef ref) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opp.type.name.toUpperCase(),
                  style: TextStyle(color: theme.colorScheme.primary, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                DateFormat.yMMMd().format(opp.createdAt),
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${opp.type.name} at ${opp.location}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 16, color: Colors.green),
              const SizedBox(width: 8),
              Text('Expected Rent: KES ${opp.expectedRent.toInt()}', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 12),
          Text(opp.description, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, height: 1.4)),
          const SizedBox(height: 20),
          Divider(color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
          const SizedBox(height: 16),
          Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: theme.colorScheme.surfaceVariant, child: Icon(Icons.person, size: 14, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              Text('Lead from ${opp.providerName}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: theme.colorScheme.onSurface)),
              const Spacer(),
              FilledButton(
                onPressed: () => _showClaimDialog(context, opp, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Claim Lead'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showClaimDialog(BuildContext context, VacancyRequest opp, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Claim this opportunity?'),
        content: Text('By claiming this, you agree to contact the provider (${opp.providerPhone}), verify the property, and list it professionally on UniHub.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              final user = ref.read(appUserProvider).valueOrNull!;
              await ref.read(housingRepositoryProvider).claimVacancyRequest(opp.id, user.uid, user.fullName);
              if (context.mounted) {
                Navigator.pop(context);
                context.push('/add-housing', extra: opp);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lead claimed! Verify and complete the listing.')));
              }
            }, 
            child: const Text('Claim Now')
          ),
        ],
      ),
    );
  }
}
