import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/auth/shared/providers.dart';

class HistoryItem {
  final String id;
  final String type; // 'listing', 'housing', 'note', 'gig'
  final String title;
  final String? imageUrl;
  final DateTime timestamp;

  HistoryItem({
    required this.id,
    required this.type,
    required this.title,
    this.imageUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'type': type,
    'title': title,
    'imageUrl': imageUrl,
    'timestamp': timestamp.toIso8601String(),
  };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
    id: json['id'],
    type: json['type'],
    title: json['title'],
    imageUrl: json['imageUrl'],
    timestamp: DateTime.parse(json['timestamp']),
  );
}

final historyServiceProvider = Provider((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return HistoryService(prefs);
});

final recentHistoryProvider = StateNotifierProvider<HistoryNotifier, List<HistoryItem>>((ref) {
  final service = ref.watch(historyServiceProvider);
  return HistoryNotifier(service);
});

final lastVisitProvider = StateProvider<DateTime?>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final lastVisit = prefs.getString('last_visit_timestamp');
  if (lastVisit == null) return null;
  return DateTime.parse(lastVisit);
});

class HistoryService {
  final SharedPreferences _prefs;
  static const _key = 'user_view_history';

  HistoryService(this._prefs);

  List<HistoryItem> getHistory() {
    final data = _prefs.getStringList(_key) ?? [];
    return data
        .map((e) => HistoryItem.fromJson(jsonDecode(e)))
        .toList()
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  }

  Future<void> addToHistory(HistoryItem item) async {
    var history = getHistory();
    // Remove if already exists to move to top
    history.removeWhere((e) => e.id == item.id && e.type == item.type);
    history.insert(0, item);
    
    // Keep only last 20 items
    if (history.length > 20) {
      history = history.sublist(0, 20);
    }

    final data = history.map((e) => jsonEncode(e.toJson())).toList();
    await _prefs.setStringList(_key, data);
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_key);
  }

  Future<void> updateLastVisit() async {
    await _prefs.setString('last_visit_timestamp', DateTime.now().toIso8601String());
  }
}

class HistoryNotifier extends StateNotifier<List<HistoryItem>> {
  final HistoryService _service;

  HistoryNotifier(this._service) : super(_service.getHistory());

  Future<void> addItem(HistoryItem item) async {
    await _service.addToHistory(item);
    state = _service.getHistory();
  }

  Future<void> clear() async {
    await _service.clearHistory();
    state = [];
  }
}
