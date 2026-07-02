import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/shared/providers.dart';
import '../data/repositories/campus_filter_repository_impl.dart';
import '../domain/models/browsing_scope.dart';
import '../domain/repositories/campus_filter_repository.dart';
import '../../../../core/constants/campus_constants.dart';

final campusFilterRepositoryProvider = Provider<CampusFilterRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return CampusFilterRepositoryImpl(prefs);
});

final browsingScopeProvider = StateNotifierProvider<BrowsingScopeNotifier, BrowsingScope>((ref) {
  final repository = ref.watch(campusFilterRepositoryProvider);
  return BrowsingScopeNotifier(repository);
});

/// Resolves the current [BrowsingScope] into a concrete campus ID filter.
/// Returns null if 'All Campuses' is selected.
final effectiveCampusFilterProvider = Provider<String?>((ref) {
  final scope = ref.watch(browsingScopeProvider);
  final user = ref.watch(appUserProvider).valueOrNull;
  
  return switch (scope.type) {
    BrowsingScopeType.all => null,
    BrowsingScopeType.myCampus => CampusConstants.resolveToId(user?.university),
    BrowsingScopeType.specific => scope.campusId,
  };
});

class BrowsingScopeNotifier extends StateNotifier<BrowsingScope> {
  final CampusFilterRepository _repository;

  BrowsingScopeNotifier(this._repository) : super(BrowsingScope.all()) {
    _init();
  }

  Future<void> _init() async {
    final savedScope = await _repository.getBrowsingScope();
    if (savedScope != null) {
      state = savedScope;
    }
  }

  Future<void> setScope(BrowsingScope scope) async {
    state = scope;
    await _repository.saveBrowsingScope(scope);
  }

  void reset() {
    state = BrowsingScope.all();
    _repository.saveBrowsingScope(state);
  }
}
