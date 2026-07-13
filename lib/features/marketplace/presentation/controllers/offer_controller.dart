import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/models/offer.dart';

class OfferController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  OfferController(this._ref) : super(const AsyncValue.data(null));

  Future<void> makeOffer(Offer offer) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketplaceRepositoryProvider).makeOffer(offer);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> respondToOffer(String offerId, OfferStatus status, {double? counterAmount}) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketplaceRepositoryProvider).respondToOffer(offerId, status, counterAmount: counterAmount);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final offerControllerProvider = StateNotifierProvider<OfferController, AsyncValue<void>>((ref) {
  return OfferController(ref);
});

final listingOffersProvider = StreamProvider.family<List<Offer>, String>((ref, listingId) {
  return ref.watch(marketplaceRepositoryProvider).watchListingOffers(listingId);
});

final userOffersProvider = StreamProvider.family<List<Offer>, String>((ref, userId) {
  return ref.watch(marketplaceRepositoryProvider).watchUserOffers(userId);
});

final receivedOffersProvider = StreamProvider.family<List<Offer>, String>((ref, sellerId) {
  return ref.watch(marketplaceRepositoryProvider).watchReceivedOffers(sellerId);
});
