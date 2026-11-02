import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService {
  static const String _kTheme = 'theme';
  static const String _kTabOrder = 'tabOrder';
  static const String _kConfirmDelete = 'confirmDelete';
  static const String _kPendingImports = 'pendingImports';

  // New canonical order - Storage Items, Home Inventory, Places of Interest
  static const List<String> defaultTabOrder = [
    'Storage Items',
    'Home Inventory',
    'Places of Interest',
  ];

  // Legacy mapping for backward compat
  static const Map<String, String> legacyToCanonical = {
    'Storage': 'Storage Items',
    'Inventory': 'Home Inventory',
    'POI': 'Places of Interest',
    'Storage Items': 'Storage Items',
    'Home Inventory': 'Home Inventory',
    'Places of Interest': 'Places of Interest',
  };

  // Keep old allOrders for reference only, not used in new UI
  static const List<List<String>> allOrders = [
    ['Storage','Inventory','POI'],
    ['Storage','POI','Inventory'],
    ['Inventory','Storage','POI'],
    ['Inventory','POI','Storage'],
    ['POI','Storage','Inventory'],
    ['POI','Inventory','Storage'],
  ];

  Future<SharedPreferences> get _prefs async => await SharedPreferences.getInstance();

  Future<String> getTheme() async {
    final p = await _prefs;
    return p.getString(_kTheme) ?? 'system';
  }
  Future<void> setTheme(String v) async {
    final p = await _prefs;
    await p.setString(_kTheme, v);
  }

  Future<List<String>> getTabOrder() async {
    final p = await _prefs;
    final stored = p.getStringList(_kTabOrder);
    if (stored != null && stored.length == 3) {
      // translate legacy if needed
      final translated = stored.map((e) => legacyToCanonical[e.trim()] ?? e).toList();
      final valid = defaultTabOrder.toSet();
      if (translated.every((e) => valid.contains(e)) && translated.toSet().length == 3) {
        return translated;
      }
    }
    return List<String>.from(defaultTabOrder);
  }

  Future<void> setTabOrder(List<String> order) async {
    final p = await _prefs;
    // ensure we store canonical names
    final canonical = order.map((e) => legacyToCanonical[e.trim()] ?? e).toList();
    await p.setStringList(_kTabOrder, canonical);
  }

  Future<bool> getConfirmDelete() async {
    final p = await _prefs;
    return p.getBool(_kConfirmDelete) ?? true;
  }
  Future<void> setConfirmDelete(bool v) async {
    final p = await _prefs;
    await p.setBool(_kConfirmDelete, v);
  }

  Future<List<Map<String, dynamic>>> getPendingImports() async {
    final pref = await _prefs;
    final jsonStr = pref.getString(_kPendingImports);
    if (jsonStr == null || jsonStr.isEmpty) return [];
    try {
      final List decoded = jsonDecode(jsonStr) as List;
      return decoded.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) { return []; }
  }

  Future<void> setPendingImports(List<Map<String, dynamic>> list) async {
    final pref = await _prefs;
    await pref.setString(_kPendingImports, jsonEncode(list));
  }

  Future<void> clearPendingImports() async {
    final pref = await _prefs;
    await pref.remove(_kPendingImports);
  }
}
