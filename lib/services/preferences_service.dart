import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService extends ChangeNotifier {
  static const _keyWidgetStyle = 'widget_style';
  static const _keyWidgetSize = 'widget_size';

  late SharedPreferences _prefs;

  String _widgetStyle = 'classic'; // for example
  String _widgetSize = 'medium';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _widgetStyle = _prefs.getString(_keyWidgetStyle) ?? _widgetStyle;
    _widgetSize = _prefs.getString(_keyWidgetSize) ?? _widgetSize;
  }

  String get widgetStyle => _widgetStyle;
  String get widgetSize => _widgetSize;

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
}
