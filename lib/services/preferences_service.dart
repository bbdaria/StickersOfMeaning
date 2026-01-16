import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';

class PreferencesService extends ChangeNotifier {
  late SharedPreferences _prefs;

  // --- Keys ---
  static const _keyLanguage = 'app_language';
  static const _keyStickerSource = 'sticker_source';
  static const _keyStickerFilters = 'sticker_filters';

  static const _keyWidgetFontSize = 'widget_font_size';
  static const _keyWidgetShowImage = 'widget_show_image';

  // Legacy/Existing keys
  static const _keyDailyDate = 'daily_date';
  static const _keyDailyStickerId = 'daily_sticker_id';
  static const _keySeenStickers = 'seen_sticker_ids';

  // --- Defaults ---
  String _language = 'en';
  String _stickerSource = 'web';
  List<String> _stickerFilters = [];
  double _widgetFontSize = 16.0;
  bool _widgetShowImage = true;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _language = _prefs.getString(_keyLanguage) ?? 'en';
    _stickerSource = _prefs.getString(_keyStickerSource) ?? 'web';
    _stickerFilters = _prefs.getStringList(_keyStickerFilters) ?? [];
    _widgetFontSize = _prefs.getDouble(_keyWidgetFontSize) ?? 16.0;
    _widgetShowImage = _prefs.getBool(_keyWidgetShowImage) ?? true;
  }

  // --- Getters ---
  String get language => _language;
  String get stickerSource => _stickerSource;
  List<String> get stickerFilters => _stickerFilters;
  double get widgetFontSize => _widgetFontSize;
  bool get widgetShowImage => _widgetShowImage;
  String? get dailyDate => _prefs.getString(_keyDailyDate);
  int? get dailyStickerId => _prefs.getInt(_keyDailyStickerId);
  List<String> get seenStickerIds => _prefs.getStringList(_keySeenStickers) ?? [];

  // --- Setters ---

  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString(_keyLanguage, value);
    notifyListeners();

    // Ensure this line is present to update the widget immediately!
    await WidgetService().refreshWidgetSettings();
  }

  Future<void> setStickerSource(String value) async {
    _stickerSource = value;
    await _prefs.setString(_keyStickerSource, value);
    notifyListeners();
  }

  Future<void> setStickerFilters(List<String> value) async {
    _stickerFilters = value;
    await _prefs.setStringList(_keyStickerFilters, value);
    notifyListeners();
  }

  Future<void> setWidgetFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_font_size', size);
  }

  Future<double> getWidgetFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble('widget_font_size') ?? 16.0;
  }

  Future<bool> getWidgetShowImage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('widget_show_image') ?? true;
  }

  Future<void> setWidgetShowImage(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('widget_show_image', value);
  }

  // --- Legacy Methods ---
  Future<void> setDailySticker(int id, String date) async {
    await _prefs.setInt(_keyDailyStickerId, id);
    await _prefs.setString(_keyDailyDate, date);

    final history = seenStickerIds;
    if (!history.contains(id.toString())) {
      history.add(id.toString());
      await _prefs.setStringList(_keySeenStickers, history);
    }
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keySeenStickers);
  }
}