import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:unihub_mobile/app/theme/app_colors.dart';
import '../../../auth/shared/providers.dart';
import '../../domain/models/offer.dart';
import '../../domain/models/listing.dart';
import '../controllers/offer_controller.dart';
import '../../shared/providers.dart';
import '../../../../core/utils/date_formatter.dart';

class SellerOffersScreen extends ConsumerWidget {
  const SellerOffersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final user = ref.watch(appUserProvider).valueOrNull;
    
    if (user == null) {
      return const Scaffold(body: Center(child: Text('Please log in to view offers.')));
    }

    final offersAsync = ref.watch(receivedOffersProvider(user.uid));

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Offers Received'),
        backgroundColor: theme.colorScheme.surface,
        foregroundColor: theme.colorScheme.onSurface,
        elevation: 0,
      ),
      body: offersAsync.when(
        data: (offers) {
          if (offers.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.handshake_outlined, size: 80, color: theme.colorScheme.outlineVariant),
                  const SizedBox(height: 20),
                  Text('No offers received yet.', style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: offers.length,
            itemBuilder: (context, index) {
              return _OfferListItem(offer: offers[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}

class _OfferListItem extends ConsumerWidget {
  final Offer offer;

  const _OfferListItem({required this.offer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final listingAsync = ref.watch(listingProvider(offer.listingId));
    final buyerAsync = ref.watch(publicUserProvider(offer.buyerId));

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      elevation: 0,
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                listingAsync.when(
                  data: (listing) => Expanded(
                    child: Text(
                      listing?.title ?? 'Unknown Item',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  loading: () => const Expanded(child: SizedBox(height: 20)),
                  error: (_, __) => const Expanded(child: Text('Item not found')),
                ),
                _buildStatusChip(offer.status),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                buyerAsync.when(
                  data: (buyer) => Text(
                    'Offer from ${buyer.fullName}',
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const Spacer(),
                Text(
                  DateFormatter.formatRelative(offer.timestamp),
                  style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('OFFERED AMOUNT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${NumberFormat("#,###").format(offer.amount)}',
                      style: TextStyle(
                        fontSize: 20, 
                        fontWeight: FontWeight.w900, 
                        color: theme.colorScheme.primary
                      ),
                    ),
                  ],
                ),
                if (offer.status == OfferStatus.pending)
                  Row(
                    children: [
                      IconButton.filledTonal(
                        onPressed: () => _respond(context, ref, OfferStatus.rejected),
                        icon: const Icon(Icons.close, color: Colors.red),
                        tooltip: 'Reject',
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: () => _respond(context, ref, OfferStatus.accepted),
                        icon: const Icon(Icons.check),
                        style: IconButton.styleFrom(backgroundColor: Colors.green),
                        tooltip: 'Accept',
                      ),
                    ],
                  ),
              ],
            ),
            if (offer.message != null && offer.message!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                width: double.infinity,
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  offer.message!,
                  style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(OfferStatus status) {
    Color color = Colors.grey;
    switch (status) {
      case OfferStatus.pending: color = Colors.orange; break;
      case OfferStatus.accepted: color = Colors.green; break;
      case OfferStatus.rejected: color = Colors.red; break;
      case OfferStatus.withdrawn: color = Colors.grey; break;
      case OfferStatus.countered: color = Colors.blue; break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        status.name.toUpperCase(),
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _respond(BuildContext context, WidgetRef ref, OfferStatus status) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${status == OfferStatus.accepted ? "Accept" : "Reject"} Offer?'),
        content: Text('Are you sure you want to ${status.name} this offer?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            child: Text(status.name.toUpperCase(), style: TextStyle(color: status == OfferStatus.accepted ? Colors.green : Colors.red))
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await ref.read(offerControllerProvider.notifier).respondToOffer(offer.id, status);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Offer ${status.name} successfully')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }
}
