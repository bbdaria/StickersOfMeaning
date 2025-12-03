import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static const _keyWidgetStyle = 'widget_style';
  static const _keyWidgetSize = 'widget_size';

  late SharedPreferences _prefs;

  String _widgetStyle = 'classic'; // for example
  String _widgetSize = 'medium';

  static const _keyDailyDate = 'daily_date';
  static const _keyDailyStickerId = 'daily_sticker_id';
  static const _keySeenStickers = 'seen_sticker_ids';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _widgetStyle = _prefs.getString(_keyWidgetStyle) ?? _widgetStyle;
    _widgetSize = _prefs.getString(_keyWidgetSize) ?? _widgetSize;
  }

  String get widgetStyle => _widgetStyle;
  String get widgetSize => _widgetSize;

  String? get dailyDate => _prefs.getString(_keyDailyDate);
  int? get dailyStickerId => _prefs.getInt(_keyDailyStickerId);
  List<String> get seenStickerIds => _prefs.getStringList(_keySeenStickers) ?? [];

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
