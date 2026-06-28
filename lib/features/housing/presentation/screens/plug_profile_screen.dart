import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../widgets/housing_card.dart';

class PlugProfileScreen extends ConsumerWidget {
  final String plugId;
  const PlugProfileScreen({super.key, required this.plugId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugAsync = ref.watch(userByIdProvider(plugId));
    final listingsAsync = ref.watch(plugListingsProvider(plugId));

    return plugAsync.when(
      data: (plug) {
        if (plug == null) return const Scaffold(body: Center(child: Text('Plug not found')));
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          body: CustomScrollView(
            slivers: [
              _buildSliverAppBar(plug, context),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildPlugHeader(plug),
                      const SizedBox(height: 24),
                      _buildBioSection(plug),
                      const SizedBox(height: 32),
                      _buildStatsRow(plug, listingsAsync),
                      const SizedBox(height: 32),
                      Text('Active Listings', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 16),
                      _buildListingsGrid(listingsAsync),
                    ],
                  ),
                ),
              ),
            ],
          ),
          bottomNavigationBar: _buildBottomContactBar(plug),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildSliverAppBar(dynamic plug, BuildContext context) {
    return SliverAppBar(
      expandedHeight: 200,
      pinned: true,
      backgroundColor: const Color(0xFF1677F2),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (plug.coverPhotoUrl != null)
              OptimizedImage(imageUrl: plug.coverPhotoUrl!, fit: BoxFit.cover)
            else
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Color(0xFF1677F2), Color(0xFF19D3C5)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            Container(color: Colors.black.withOpacity(0.2)),
          ],
        ),
      ),
      actions: [
        IconButton(icon: const Icon(Icons.share, color: Colors.white), onPressed: () {}),
      ],
    );
  }

  Widget _buildPlugHeader(dynamic plug) {
    final bool isVerified = plug.isVerified;
    final int trustScore = plug.trustScore.toInt();

    return Transform.translate(
      offset: const Offset(0, -60),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 50,
              backgroundImage: plug.photoUrl != null ? NetworkImage(plug.photoUrl!) : null,
              child: plug.photoUrl == null ? Text(plug.fullName[0], style: const TextStyle(fontSize: 40)) : null,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(plug.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
              if (isVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(Icons.verified_user_rounded, color: Color(0xFF10B981), size: 24),
                ),
            ],
          ),
          const SizedBox(height: 4),
          if (isVerified)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF10B981).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'PLATFORM TRUSTED • $trustScore%',
                style: const TextStyle(
                  color: Color(0xFF059669),
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          const SizedBox(height: 12),
          Text(
            'VERIFIED HOUSING PLUG',
            style: GoogleFonts.plusJakartaSans(
              color: const Color(0xFF1677F2), 
              fontWeight: FontWeight.w800,
              fontSize: 14,
              letterSpacing: 1.0,
            )
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_on, size: 14, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text('${plug.university} • ${plug.campus}', style: const TextStyle(color: Colors.blueGrey)),
            ],
          ),
          const SizedBox(height: 4),
          Text('Member since ${DateFormat.yMMM().format(plug.createdAt ?? DateTime.now())}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildBioSection(dynamic plug) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Professional Introduction', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(plug.bio ?? 'No professional introduction shared yet.', style: const TextStyle(color: Colors.blueGrey, height: 1.5)),
      ],
    );
  }

  Widget _buildStatsRow(dynamic plug, AsyncValue listingsAsync) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildStatItem('Reputation', plug.averageRating.toStringAsFixed(1), Icons.star_rounded, Colors.amber),
            _buildStatItem('Active Listings', plug.housingListingsCount.toString(), Icons.home_work_rounded, Colors.blue),
            _buildStatItem('Platform Trust', '${plug.trustScore.toInt()}%', Icons.shield_rounded, Colors.green),
          ],
        ),
        const SizedBox(height: 16),
        const Divider(),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08), 
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.1)),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 10),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF1A1C1E))),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w800, letterSpacing: 0.2)),
      ],
    );
  }

  Widget _buildListingsGrid(AsyncValue listingsAsync) {
    return listingsAsync.when(
      data: (listings) => listings.isEmpty
          ? const Center(child: Text('No active listings'))
          : ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: listings.length,
              itemBuilder: (context, index) => HousingCard(
                listing: listings[index],
                onTap: () => context.push('/housing-detail', extra: listings[index]),
              ),
            ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildBottomContactBar(dynamic plug) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('Chat'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final url = Uri.parse('tel:${plug.phoneNumber ?? ""}');
                if (await canLaunchUrl(url)) await launchUrl(url);
              },
              icon: const Icon(Icons.phone),
              label: const Text('Call Plug'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF1677F2),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
