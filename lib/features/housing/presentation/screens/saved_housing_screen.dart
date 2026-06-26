import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../shared/providers.dart';
import '../widgets/housing_card.dart';

class SavedHousingScreen extends ConsumerWidget {
  const SavedHousingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final savedListingsAsync = ref.watch(savedHousingProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text('Saved Housing', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
      ),
      body: savedListingsAsync.when(
        data: (listings) => listings.isEmpty
            ? _buildEmptyState(context)
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: listings.length,
                itemBuilder: (context, index) => HousingCard(
                  listing: listings[index],
                  onTap: () => context.push('/housing-detail', extra: listings[index]),
                ),
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: const BoxDecoration(color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.favorite_rounded, size: 64, color: Color(0xFF94A3B8)),
          ),
          const SizedBox(height: 24),
          const Text('Your wishlist is empty', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 20, color: Color(0xFF1A1C1E))),
          const SizedBox(height: 8),
          const Text('Save properties to keep track of them here', style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: () => context.pop(),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF1677F2),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            child: const Text('Start Browsing', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
