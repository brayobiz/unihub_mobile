import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/models/browsing_scope.dart';
import '../../domain/repositories/campus_filter_repository.dart';

class CampusFilterRepositoryImpl implements CampusFilterRepository {
  final SharedPreferences _prefs;
  static const _key = 'browsing_scope';

  CampusFilterRepositoryImpl(this._prefs);

  @override
  Future<void> saveBrowsingScope(BrowsingScope scope) async {
    final json = jsonEncode(scope.toJson());
    await _prefs.setString(_key, json);
  }

  @override
  Future<BrowsingScope?> getBrowsingScope() async {
    final json = _prefs.getString(_key);
    if (json == null) return null;
    try {
      return BrowsingScope.fromJson(jsonDecode(json));
    } catch (_) {
      return null;
    }
  }
}
