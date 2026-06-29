import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';
import '../../domain/models/listing.dart';

class SellerDashboardController extends StateNotifier<AsyncValue<Map<String, dynamic>>> {
  final Ref _ref;
  final String _userId;

  SellerDashboardController(this._ref, this._userId) : super(const AsyncValue.loading()) {
    fetchStats();
  }

  Future<void> fetchStats() async {
    state = const AsyncValue.loading();
    try {
      final stats = await _ref.read(marketplaceRepositoryProvider).getSellerStats(_userId);
      state = AsyncValue.data(stats);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final sellerStatsProvider = StateNotifierProvider.family<SellerDashboardController, AsyncValue<Map<String, dynamic>>, String>((ref, userId) {
  return SellerDashboardController(ref, userId);
});

final sellerListingsByStatusProvider = StreamProvider.family<List<Listing>, (String, ListingStatus)>((ref, arg) {
  return ref.watch(marketplaceRepositoryProvider).watchSellerListingsByStatus(arg.$1, arg.$2);
});
