import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:go_router/go_router.dart';
import '../../../auth/shared/providers.dart';
import '../../../auth/domain/models/app_user.dart';
import '../../shared/providers.dart';
import '../../domain/models/housing_listing.dart';

class PlugProfileScreen extends ConsumerWidget {
  final String plugId;

  const PlugProfileScreen({super.key, required this.plugId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plugAsync = ref.watch(userByIdProvider(plugId));
    final listingsAsync = ref.watch(plugListingsProvider(plugId));

    return plugAsync.when(
      data: (plug) {
        if (plug == null) {
          return const Scaffold(
            body: Center(child: Text('Plug not found')),
          );
        }

        return Scaffold(
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  height: 180,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFF1E88E5), Color(0xFF26C6DA)],
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.arrow_back, color: Colors.white),
                            onPressed: () => context.pop(),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Profile Section
                Transform.translate(
                  offset: const Offset(0, -60),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            CircleAvatar(
                              radius: 55,
                              backgroundColor: Colors.white,
                              child: CircleAvatar(
                                radius: 52,
                                backgroundImage: plug.photoUrl != null
                                    ? CachedNetworkImageProvider(plug.photoUrl!)
                                    : const NetworkImage('https://ui-avatars.com/api/?name=Plug&background=random') as ImageProvider,
                              ),
                            ),
                            if (plug.isVerifiedPlug)
                              const CircleAvatar(
                                radius: 18,
                                backgroundColor: Colors.white,
                                child: Icon(Icons.verified, color: Colors.green, size: 28),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(plug.fullName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                            if (plug.isVerifiedPlug) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.verified, color: Colors.blue, size: 24),
                            ],
                          ],
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (plug.isVerifiedPlug)
                              const Text('Verified by UniHub', style: TextStyle(color: Colors.grey)),
                            if (plug.isVerifiedPlug) const SizedBox(width: 16),
                            const Row(children: [Icon(Icons.home, size: 18), SizedBox(width: 4), Text('Housing Plug')]),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              decoration: BoxDecoration(color: Colors.green.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [Icon(Icons.circle, color: Colors.green, size: 12), SizedBox(width: 6), Text('Accepting New Inquiries', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w500))],
                              ),
                            ),
                            if (plug.university != null) ...[
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20)),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.school, size: 16), const SizedBox(width: 6), Text(plug.university!)]),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Stats
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(Icons.home, plug.housingListingsCount.toString(), 'Active Listings'),
                      _buildStatItem(Icons.people, plug.completedSalesCount.toString(), 'Students Helped'),
                      _buildStatItem(Icons.calendar_today, plug.createdAt != null ? DateFormat('yyyy').format(plug.createdAt!) : '2024', 'Member Since'),
                      _buildStatItem(Icons.timer, '', 'Responds\n${plug.responseRate}'),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('About ${plug.fullName.split(' ')[0]}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(plug.bio ?? 'This plug has not provided a bio yet.'),
                      if (plug.bio != null && plug.bio!.length > 100)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: InkWell(
                            onTap: () => _showBioDialog(context, plug.fullName, plug.bio!),
                            child: const Text('Read more', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w500)),
                          ),
                        ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildAreasServed(plug)),
                      const SizedBox(width: 24),
                      Expanded(child: _buildSpecialties(plug)),
                    ],
                  ),
                ),

                const Divider(height: 1),

                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Active Listings', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      listingsAsync.when(
                        data: (listings) => InkWell(
                          onTap: () => _showAllListings(context, ref, plug.fullName, listings),
                          child: Text('View all (${listings.length})', style: const TextStyle(color: Colors.blue)),
                        ),
                        loading: () => const SizedBox.shrink(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),

                SizedBox(
                  height: 280,
                  child: listingsAsync.when(
                    data: (listings) {
                      if (listings.isEmpty) {
                        return const Center(child: Text('No active listings'));
                      }
                      return ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: listings.length,
                        itemBuilder: (context, index) {
                          final listing = listings[index];
                          return Padding(
                            padding: const EdgeInsets.only(right: 16),
                            child: _buildListingCard(context, ref, listing),
                          );
                        },
                      );
                    },
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (err, _) => Center(child: Text('Error: $err')),
                  ),
                ),

                const SizedBox(height: 24),

                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.chat_bubble_outline),
                          label: const Text('In-App Chat'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: Colors.blue),
                          ),
                          onPressed: () {
                            final currentUser = ref.read(authStateProvider).valueOrNull;
                            if (currentUser == null) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Please login to chat'))
                              );
                              return;
                            }
                            
                            // Simple ID generation for the conversation
                            final conversationId = currentUser.uid.compareTo(plug.uid) < 0 
                                ? '${currentUser.uid}_${plug.uid}' 
                                : '${plug.uid}_${currentUser.uid}';
                            
                            context.push('/chat', extra: {
                              'conversationId': conversationId,
                              'otherUserName': plug.fullName,
                              'listing': null,
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.message),
                          label: const Text('WhatsApp'),
                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 16)),
                          onPressed: () => _launchWhatsApp(context, plug.whatsappNumber ?? plug.phoneNumber, plug.fullName),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => Scaffold(body: Center(child: Text('Error: $err'))),
    );
  }

  void _launchWhatsApp(BuildContext context, String? number, String name) async {
    if (number == null || number.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No WhatsApp number provided for this plug'))
      );
      return;
    }
    
    // Clean number: remove all non-digits
    String cleanNumber = number.replaceAll(RegExp(r'[^0-9]'), '');
    
    // Format for Kenyan numbers if local format is used (e.g., 0712345678 -> 254712345678)
    if (cleanNumber.startsWith('0')) {
      cleanNumber = '254${cleanNumber.substring(1)}';
    } else if (cleanNumber.length == 9 && (cleanNumber.startsWith('7') || cleanNumber.startsWith('1'))) {
      // Handles 712345678 -> 254712345678
      cleanNumber = '254$cleanNumber';
    }
    
    final whatsappUrl = Uri.parse("https://wa.me/$cleanNumber?text=Hi $name, I'm interested in one of your listings on UniHub.");
    
    try {
      // In many cases on modern Android, canLaunchUrl returns false even if it can launch
      // So we attempt to launch and catch the error if it fails
      bool launched = await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      if (!launched) {
        throw 'Could not launch WhatsApp';
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open WhatsApp. Please ensure it is installed. $e'))
        );
      }
    }
  }

  void _showBioDialog(BuildContext context, String name, String bio) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('About $name'),
        content: SingleChildScrollView(child: Text(bio)),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
      ),
    );
  }

  void _showAllListings(BuildContext context, WidgetRef ref, String name, List<HousingListing> listings) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('All Listings by $name', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ),
            const Divider(),
            Expanded(
              child: GridView.builder(
                controller: scrollController,
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.68,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: listings.length,
                itemBuilder: (context, index) => _buildListingCard(context, ref, listings[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: Colors.grey[600]),
        if (value.isNotEmpty) Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        Text(label, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildAreasServed(AppUser plug) {
    // We'll use skills or interests as proxy for areas served if not explicitly there, 
    // but typically we might want to derive this from active listings or campus.
    final areas = plug.campus != null ? [plug.campus!] : ['N/A'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Icon(Icons.location_on, size: 20), SizedBox(width: 8), Text('Areas Served', style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: areas.map(_buildTag).toList()),
      ],
    );
  }

  Widget _buildSpecialties(AppUser plug) {
    // Use skills or a default list
    final specialties = plug.skills.isNotEmpty 
        ? plug.skills 
        : ['Hostels', 'Bedsitters', 'One Bedroom', 'Short Stay'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(children: [Icon(Icons.star, size: 20), SizedBox(width: 8), Text('Accommodation Specialties', style: TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: specialties.map(_buildTag).toList()),
      ],
    );
  }

  Widget _buildTag(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(20)),
      child: Text(text, style: const TextStyle(fontSize: 13)),
    );
  }

  Widget _buildListingCard(BuildContext context, WidgetRef ref, HousingListing listing) {
    final currencyFormatter = NumberFormat.currency(symbol: 'KES ', decimalDigits: 0);
    final savedHousing = ref.watch(savedHousingProvider).valueOrNull ?? [];
    final isSaved = savedHousing.any((l) => l.id == listing.id);

    return GestureDetector(
      onTap: () {
        context.push('/housing-detail', extra: listing);
      },
      child: Container(
        width: 240,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16), 
          color: Colors.white, 
          boxShadow: [BoxShadow(color: Colors.grey.withOpacity(0.1), blurRadius: 10)]
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: CachedNetworkImage(
                    imageUrl: listing.images.isNotEmpty ? listing.images.first : 'https://picsum.photos/400/250',
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.grey[200]),
                    errorWidget: (context, url, error) => const Icon(Icons.error),
                  ),
                ),
                Positioned(
                  top: 8, 
                  right: 8, 
                  child: GestureDetector(
                    onTap: () {
                      final user = ref.read(authStateProvider).valueOrNull;
                      if (user == null) return;
                      
                      if (isSaved) {
                        ref.read(housingRepositoryProvider).unsaveListing(user.uid, listing.id);
                      } else {
                        ref.read(housingRepositoryProvider).saveListing(user.uid, listing.id);
                      }
                    },
                    child: CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white.withOpacity(0.8),
                      child: Icon(
                        isSaved ? Icons.favorite : Icons.favorite_border, 
                        color: isSaved ? Colors.red : Colors.grey, 
                        size: 20
                      ),
                    ),
                  )
                ),
                Positioned(
                  bottom: 12, 
                  left: 12, 
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                    decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)), 
                    child: Text(
                      listing.type.name.toUpperCase(), 
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)
                    )
                  )
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(listing.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${listing.university} • ${listing.location}', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    '${currencyFormatter.format(listing.rent)} /month', 
                    style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
