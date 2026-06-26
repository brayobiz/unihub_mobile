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
    final opportunitiesAsync = ref.watch(vacancyOpportunitiesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('New Opportunities', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: opportunitiesAsync.when(
        data: (opportunities) => opportunities.isEmpty
            ? _buildEmptyState()
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

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_awesome_motion_rounded, size: 64, color: Colors.blueGrey.shade200),
          const SizedBox(height: 16),
          const Text('No new opportunities', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const Text('Check back later for new vacancy leads.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildOpportunityCard(BuildContext context, VacancyRequest opp, WidgetRef ref) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  color: const Color(0xFF1677F2).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  opp.type.name.toUpperCase(),
                  style: const TextStyle(color: Color(0xFF1677F2), fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              Text(
                DateFormat.yMMMd().format(opp.createdAt),
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${opp.type.name} at ${opp.location}',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
          Text(opp.description, style: const TextStyle(color: Colors.blueGrey, height: 1.4)),
          const SizedBox(height: 20),
          const Divider(),
          const SizedBox(height: 16),
          Row(
            children: [
              const CircleAvatar(radius: 12, child: Icon(Icons.person, size: 14)),
              const SizedBox(width: 8),
              Text('Lead from ${opp.providerName}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
              const Spacer(),
              FilledButton(
                onPressed: () => _showClaimDialog(context, opp, ref),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF1677F2),
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
