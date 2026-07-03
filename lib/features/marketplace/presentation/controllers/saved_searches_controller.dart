import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/saved_search.dart';
import '../../domain/models/listing_filter.dart';
import '../../shared/providers.dart';
import '../../../auth/shared/providers.dart';

class SavedSearchesController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  SavedSearchesController(this._ref) : super(const AsyncValue.data(null));

  Future<void> saveCurrentSearch({
    required String name,
    required ListingFilter filter,
    String? campusId,
  }) async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    state = const AsyncValue.loading();
    try {
      final search = SavedSearch(
        id: const Uuid().v4(),
        userId: user.uid,
        name: name,
        filter: filter,
        campusId: campusId,
        createdAt: DateTime.now(),
      );

      await _ref.read(marketplaceRepositoryProvider).saveSearch(search);
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteSearch(String searchId) async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    try {
      await _ref.read(marketplaceRepositoryProvider).deleteSavedSearch(user.uid, searchId);
    } catch (e) {
      // Handle error
    }
  }

  Future<void> toggleNotifications(String searchId, bool enabled) async {
    final user = _ref.read(appUserProvider).valueOrNull;
    if (user == null) return;

    try {
      await _ref.read(marketplaceRepositoryProvider).updateSavedSearchNotification(user.uid, searchId, enabled);
    } catch (e) {
      // Handle error
    }
  }
}

final savedSearchesControllerProvider = StateNotifierProvider<SavedSearchesController, AsyncValue<void>>((ref) {
  return SavedSearchesController(ref);
});

final savedSearchesProvider = StreamProvider<List<SavedSearch>>((ref) {
  final user = ref.watch(appUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);
  return ref.watch(marketplaceRepositoryProvider).watchSavedSearches(user.uid);
});
