import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

final cacheServiceProvider = Provider((ref) => CacheService());

class CacheService {
  static const String _listingsBox = 'listings_cache';
  static const String _notesBox = 'notes_cache';
  static const String _gigsBox = 'gigs_cache';
  static const String _profileBox = 'profile_cache';
  static const String _studyProgressBox = 'study_progress_cache';

  Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_listingsBox);
    await Hive.openBox(_notesBox);
    await Hive.openBox(_gigsBox);
    await Hive.openBox(_profileBox);
    await Hive.openBox(_studyProgressBox);
  }

  // Generic methods
  void _save(String boxName, String key, dynamic value) {
    final box = Hive.box(boxName);
    box.put(key, jsonEncode(value));
  }

  dynamic _get(String boxName, String key) {
    final box = Hive.box(boxName);
    final data = box.get(key);
    if (data == null) return null;
    return jsonDecode(data);
  }

  // Profile
  void saveProfile(Map<String, dynamic> profile) => _save(_profileBox, 'current_user', profile);
  Map<String, dynamic>? getProfile() => _get(_profileBox, 'current_user');

  // Listings
  void saveListings(List<Map<String, dynamic>> listings) => _save(_listingsBox, 'top_listings', listings);
  List<dynamic>? getListings() => _get(_listingsBox, 'top_listings');

  // Notes
  void saveNotes(List<Map<String, dynamic>> notes) => _save(_notesBox, 'top_notes', notes);
  List<dynamic>? getNotes() => _get(_notesBox, 'top_notes');

  // Gigs
  void saveGigs(List<Map<String, dynamic>> gigs) => _save(_gigsBox, 'top_gigs', gigs);
  List<dynamic>? getGigs() => _get(_gigsBox, 'top_gigs');

  // Study Progress
  void saveStudyProgress(String noteId, Map<String, dynamic> progress) => _save(_studyProgressBox, noteId, progress);
  Map<String, dynamic>? getStudyProgress(String noteId) => _get(_studyProgressBox, noteId);
  
  Future<void> clearAll() async {
    await Hive.deleteFromDisk();
  }
}
