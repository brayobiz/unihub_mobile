import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:unihub_mobile/core/widgets/optimized_image.dart';
import 'package:unihub_mobile/features/trust/domain/models/professional_role.dart';
import 'package:unihub_mobile/features/trust/domain/models/verification_application.dart';
import 'package:unihub_mobile/features/trust/presentation/providers/trust_providers.dart';
import 'package:unihub_mobile/features/housing/domain/models/housing_listing.dart';
import '../../../auth/shared/providers.dart';
import '../../shared/providers.dart';
import '../widgets/housing_card.dart';

class PlugProfileScreen extends ConsumerWidget {
  final String plugId;
  const PlugProfileScreen({super.key, required this.plugId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugAsync = ref.watch(userByIdProvider(plugId));
    final applicationAsync = ref.watch(userApplicationByRoleProvider((userId: plugId, role: ProfessionalRole.housePlug)));
    final listingsAsync = ref.watch(plugListingsProvider(plugId));

    return plugAsync.when(
      data: (plug) {
        if (plug == null) return const Scaffold(body: Center(child: Text('Plug not found')));
        
        return applicationAsync.when(
          data: (app) {
            final metadata = app?.metadata ?? {};
            
            return Scaffold(
              backgroundColor: const Color(0xFFF8FAFC),
              body: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  _buildSliverAppBar(plug),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          _buildProfileHeader(plug, metadata),
                          const SizedBox(height: 32),
                          
                          _buildQuickInfo(metadata),
                          const SizedBox(height: 32),

                          _buildSectionTitle('Professional Introduction'),
                          const SizedBox(height: 12),
                          _buildIntroText(metadata['professionalIntro'] ?? plug.bio),
                          const SizedBox(height: 32),
                          
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle('Active Listings'),
                              listingsAsync.when(
                                data: (l) => Text('${l.length} available', 
                                  style: TextStyle(color: Colors.blueGrey.shade400, fontWeight: FontWeight.bold, fontSize: 12)),
                                loading: () => const SizedBox.shrink(),
                                error: (_, __) => const SizedBox.shrink(),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildListings(listingsAsync),
                          
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              bottomNavigationBar: _buildBottomContactBar(plug, metadata),
            );
          },
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (e, _) => Scaffold(body: Center(child: Text('Error loading professional profile: $e'))),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Scaffold(body: Center(child: Text('Error: $e'))),
    );
  }

  Widget _buildSliverAppBar(dynamic plug) {
    return SliverAppBar(
      expandedHeight: 140,
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
            Container(color: Colors.black.withValues(alpha: 0.05)),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader(dynamic plug, Map<String, dynamic> metadata) {
    final bool isAvailable = metadata['availabilityStatus'] == 'Available';
    final String campus = metadata['primaryCampus'] ?? plug.university ?? 'N/A';
    final bool isVerified = plug.isVerified;

    return Transform.translate(
      offset: const Offset(0, -50),
      child: Column(
        children: [
          // 1. Profile photo focal point
          Container(
            padding: const EdgeInsets.all(4),
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: CircleAvatar(
              radius: 54,
              backgroundColor: const Color(0xFFF1F5F9),
              backgroundImage: plug.photoUrl != null ? NetworkImage(plug.photoUrl!) : null,
              child: plug.photoUrl == null 
                ? Text(plug.fullName[0], style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold)) 
                : null,
            ),
          ),
          const SizedBox(height: 16),
          
          // 2. Full Name & Verification
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                plug.fullName,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 28, 
                  fontWeight: FontWeight.w900, 
                  letterSpacing: -0.5,
                  color: const Color(0xFF1E293B),
                ),
              ),
              if (isVerified)
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.verified_rounded, color: Color(0xFF1677F2), size: 24),
                ),
            ],
          ),
          const SizedBox(height: 4),

          // 3. Role & Trust Statement
          Text(
            isVerified ? 'VERIFIED HOUSING PLUG • TRUSTED BY UNIHUB' : 'HOUSING PLUG',
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 11,
              fontWeight: FontWeight.w900,
              color: isVerified ? const Color(0xFF1677F2) : const Color(0xFF64748B),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 16),

          // 4. Availability & 5. Primary Campus
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildAvailabilityBadge(isAvailable),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.school_rounded, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Text(
                      campus,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        color: const Color(0xFF475569),
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvailabilityBadge(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isAvailable ? const Color(0xFF10B981).withValues(alpha: 0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: isAvailable ? const Color(0xFF10B981).withValues(alpha: 0.2) : Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isAvailable ? const Color(0xFF10B981) : Colors.grey.shade400,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            isAvailable ? 'ACCEPTING INQUIRIES' : 'UNAVAILABLE',
            style: GoogleFonts.plusJakartaSans(
              color: isAvailable ? const Color(0xFF059669) : Colors.grey.shade600,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickInfo(Map<String, dynamic> metadata) {
    final List<dynamic> areas = metadata['serviceAreas'] ?? [];
    final List<dynamic> specialties = metadata['accommodationSpecialties'] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (areas.isNotEmpty) ...[
          _buildSectionTitle('Primary Areas'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: areas.map((area) => _buildQuickChip(area.toString(), Icons.location_on_rounded)).toList(),
          ),
          const SizedBox(height: 20),
        ],
        if (specialties.isNotEmpty) ...[
          _buildSectionTitle('Specialties'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: specialties.map((s) => _buildQuickChip(s.toString(), Icons.star_rounded, isSpecialty: true)).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildQuickChip(String label, IconData icon, {bool isSpecialty = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isSpecialty ? const Color(0xFF1677F2).withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSpecialty ? const Color(0xFF1677F2).withValues(alpha: 0.1) : const Color(0xFFE2E8F0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: isSpecialty ? const Color(0xFF1677F2) : const Color(0xFF94A3B8)),
          const SizedBox(width: 6),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12, 
              fontWeight: FontWeight.w700, 
              color: isSpecialty ? const Color(0xFF1677F2) : const Color(0xFF475569),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11, 
        fontWeight: FontWeight.w900, 
        color: const Color(0xFF94A3B8),
        letterSpacing: 1.0,
      ),
    );
  }

  Widget _buildListings(AsyncValue<List<HousingListing>> listingsAsync) {
    return listingsAsync.when(
      data: (listings) {
        final activeListings = listings.where((l) => l.status == HousingStatus.available).toList();
        if (activeListings.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 32),
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1F5F9)),
            ),
            child: Column(
              children: [
                Icon(Icons.house_siding_rounded, size: 40, color: Colors.grey.shade300),
                const SizedBox(height: 12),
                const Text('No available houses right now.', style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          padding: EdgeInsets.zero,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: activeListings.length,
          itemBuilder: (context, index) => HousingCard(
            listing: activeListings[index],
            onTap: () => context.push('/housing-detail', extra: activeListings[index]),
          ),
        );
      },
      loading: () => const Center(child: Padding(
        padding: EdgeInsets.all(40),
        child: CircularProgressIndicator(),
      )),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildIntroText(String? intro) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFF1F5F9)),
      ),
      child: Text(
        intro ?? 'This Housing Plug hasn\'t shared their professional background yet.',
        style: GoogleFonts.plusJakartaSans(
          fontSize: 14,
          color: const Color(0xFF475569),
          height: 1.6,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildBottomContactBar(dynamic plug, Map<String, dynamic> metadata) {
    final String preferredMethod = metadata['preferredContactMethod'] ?? 'In-App Chat';
    
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05), 
            blurRadius: 10, 
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () {
                  // TODO: Chat
                },
                icon: const Icon(Icons.chat_bubble_rounded),
                label: const Text('In-App Chat'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  side: BorderSide(
                    color: preferredMethod == 'In-App Chat' ? const Color(0xFF1677F2) : const Color(0xFFE2E8F0),
                    width: 2,
                  ),
                  foregroundColor: const Color(0xFF1E293B),
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: () async {
                  final String phone = plug.whatsappNumber ?? plug.phoneNumber ?? "";
                  if (phone.isEmpty) return;
                  
                  final url = Uri.parse("https://wa.me/$phone?text=Hi ${plug.fullName}, I'm interested in your housing listings on UniHub.");
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.phone_android_rounded),
                label: const Text('WhatsApp'),
                style: FilledButton.styleFrom(
                  backgroundColor: preferredMethod == 'WhatsApp' ? const Color(0xFF25D366) : const Color(0xFF1677F2),
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                  textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
