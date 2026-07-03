import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/models/listing.dart';
import '../../domain/models/seller_stats.dart';

class SellerDashboardController extends StateNotifier<AsyncValue<SellerStats>> {
  final Ref _ref;
  final String _userId;

  SellerDashboardController(this._ref, this._userId) : super(const AsyncValue.loading()) {
    fetchStats();
  }

  Future<void> fetchStats() async {
    // Only show loading if we don't have data already to avoid flickering on refresh
    if (!state.hasValue) {
      state = const AsyncValue.loading();
    }
    
    try {
      final stats = await _ref.read(marketplaceRepositoryProvider).getSellerStats(_userId);
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() => fetchStats();
}

final sellerStatsProvider = StateNotifierProvider.family<SellerDashboardController, AsyncValue<SellerStats>, String>((ref, userId) {
  return SellerDashboardController(ref, userId);
});

final sellerListingsByStatusProvider = StreamProvider.family<List<Listing>, ({String sellerId, ListingStatus status})>((ref, arg) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListingsByStatus(arg.sellerId, arg.status);
});
