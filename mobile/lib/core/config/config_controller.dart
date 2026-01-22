import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_config.dart';

class ConfigController extends ChangeNotifier {
  static const _baseUrlKey = 'ai_service_base_url';

  String _baseUrl = AppConfig.defaultBaseUrl;
  bool _initialized = false;

  String get baseUrl => _baseUrl;
  bool get isInitialized => _initialized;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_baseUrlKey);
    if (stored != null && stored.isNotEmpty) {
      _baseUrl = stored;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> updateBaseUrl(String value) async {
    final normalized = value.trim();
    if (normalized.isEmpty || normalized == _baseUrl) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, normalized);
    _baseUrl = normalized;
    notifyListeners();
  }

  Future<void> resetBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_baseUrlKey);
    _baseUrl = AppConfig.defaultBaseUrl;
    notifyListeners();
  }
}
