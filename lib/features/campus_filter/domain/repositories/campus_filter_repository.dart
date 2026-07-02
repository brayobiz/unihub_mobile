import '../models/browsing_scope.dart';

abstract class CampusFilterRepository {
  Future<void> saveBrowsingScope(BrowsingScope scope);
  Future<BrowsingScope?> getBrowsingScope();
}
