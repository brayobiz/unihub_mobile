import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/providers.dart';

class ReviewController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  ReviewController(this._ref) : super(const AsyncValue.data(null));

  Future<void> submitReview({
    required String sellerId,
    required String buyerId,
    required String listingId,
    required double rating,
    required String comment,
  }) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(marketplaceRepositoryProvider).submitReview(
        sellerId: sellerId,
        buyerId: buyerId,
        listingId: listingId,
        rating: rating,
        comment: comment,
      );
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final reviewControllerProvider = StateNotifierProvider<ReviewController, AsyncValue<void>>((ref) {
  return ReviewController(ref);
});
