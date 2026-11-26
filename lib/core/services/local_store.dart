import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 本机轻量持久化的统一入口。
/// 各 feature 的仓库通过它读写 JSON/字符串，页面不得直接调用。
abstract interface class LocalStore {
  Future<String?> getString(String key);
  Future<void> setString(String key, String value);

  Future<Map<String, dynamic>?> getJson(String key);
  Future<void> setJson(String key, Map<String, dynamic> value);

  Future<List<dynamic>?> getJsonList(String key);
  Future<void> setJsonList(String key, List<dynamic> value);
}

/// 基于 shared_preferences 的实现。
final class SharedPreferencesLocalStore implements LocalStore {
  SharedPreferencesLocalStore(this._prefs);

  final SharedPreferences _prefs;

  @override
  Future<String?> getString(String key) async => _prefs.getString(key);

  @override
  Future<void> setString(String key, String value) async {
    await _prefs.setString(key, value);
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }

  @override
  Future<List<dynamic>?> getJsonList(String key) async {
    final String? raw = _prefs.getString(key);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as List<dynamic>;
  }

  @override
  Future<void> setJsonList(String key, List<dynamic> value) async {
    await _prefs.setString(key, jsonEncode(value));
  }
}

/// 内存实现：供测试与"未初始化兜底"使用。
final class InMemoryLocalStore implements LocalStore {
  final Map<String, String> _values = <String, String>{};

  @override
  Future<String?> getString(String key) async => _values[key];

  @override
  Future<void> setString(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<Map<String, dynamic>?> getJson(String key) async {
    final String? raw = _values[key];
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> setJson(String key, Map<String, dynamic> value) async {
    _values[key] = jsonEncode(value);
  }

  @override
  Future<List<dynamic>?> getJsonList(String key) async {
    final String? raw = _values[key];
    if (raw == null) {
      return null;
    }
    return jsonDecode(raw) as List<dynamic>;
  }

  @override
  Future<void> setJsonList(String key, List<dynamic> value) async {
    _values[key] = jsonEncode(value);
  }
}

/// shared_preferences 加载完成后由 app 层覆盖覆盖（ProviderScope overrides）。
final localStoreProvider = Provider<LocalStore>((ref) {
  // 默认内存实现，保证未注入时 App 仍可运行（演示数据不落盘）。
  return InMemoryLocalStore();
});
