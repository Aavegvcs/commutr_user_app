import 'package:flutter/foundation.dart';
import 'api_log_entry.dart';

class ApiLoggerService extends ChangeNotifier {
  ApiLoggerService._();
  static final ApiLoggerService instance = ApiLoggerService._();

  static const int _maxEntries = 100;

  final List<ApiLogEntry> _entries = [];

  List<ApiLogEntry> get entries => List.unmodifiable(_entries);

  void addEntry(ApiLogEntry entry) {
    if (_entries.length >= _maxEntries) {
      _entries.removeLast();
    }
    _entries.insert(0, entry);
    notifyListeners();
  }

  void updateEntry(String id, ApiLogEntry updated) {
    final index = _entries.indexWhere((e) => e.id == id);
    if (index != -1) {
      _entries[index] = updated;
      notifyListeners();
    }
  }

  void clearAll() {
    _entries.clear();
    notifyListeners();
  }
}
