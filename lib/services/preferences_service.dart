import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage { hebrew, english }

extension AppLanguageStorage on AppLanguage {
  String get storageKey => this == AppLanguage.hebrew ? 'he' : 'en';

  static AppLanguage fromStorage(String? value) {
    switch (value) {
      case 'en':
        return AppLanguage.english;
      case 'he':
      default:
        return AppLanguage.hebrew;
    }
  }
}

class PreferencesService extends ChangeNotifier {
  static const _keyWidgetStyle = 'widget_style';
  static const _keyWidgetSize = 'widget_size';
  static const _keyLanguage = 'app_language';
  static const _keySelectedCategories = 'selected_category_ids';

  late SharedPreferences _prefs;

  String _widgetStyle = 'classic';
  String _widgetSize = 'medium';

  AppLanguage _language = AppLanguage.hebrew;
  Set<int> _selectedCategoryIds = <int>{};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _widgetStyle = _prefs.getString(_keyWidgetStyle) ?? _widgetStyle;
    _widgetSize = _prefs.getString(_keyWidgetSize) ?? _widgetSize;

    _language = AppLanguageStorage.fromStorage(_prefs.getString(_keyLanguage));

    final rawCategories = _prefs.getStringList(_keySelectedCategories);
    if (rawCategories != null) {
      _selectedCategoryIds = rawCategories
          .map((e) => int.tryParse(e))
          .whereType<int>()
          .toSet();
    }
  }

  String get widgetStyle => _widgetStyle;
  String get widgetSize => _widgetSize;

  AppLanguage get language => _language;
  bool get isHebrew => _language == AppLanguage.hebrew;

  Set<int> get selectedCategoryIds => _selectedCategoryIds;

  Future<void> setWidgetStyle(String value) async {
    _widgetStyle = value;
    await _prefs.setString(_keyWidgetStyle, value);
    notifyListeners();
  }

  Future<void> setWidgetSize(String value) async {
    _widgetSize = value;
    await _prefs.setString(_keyWidgetSize, value);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage value) async {
    if (value == _language) return;
    _language = value;
    await _prefs.setString(_keyLanguage, value.storageKey);
    notifyListeners();
  }

  Future<void> setSelectedCategoryIds(Set<int> ids) async {
    _selectedCategoryIds = ids;
    await _prefs.setStringList(
      _keySelectedCategories,
      ids.map((e) => e.toString()).toList(),
    );
    notifyListeners();
  }

  /// Helper to toggle a single category id.
  Future<void> toggleCategory(int id) async {
    final newIds = {..._selectedCategoryIds};
    if (newIds.contains(id)) {
      newIds.remove(id);
    } else {
      newIds.add(id);
    }
    await setSelectedCategoryIds(newIds);
  }
}
