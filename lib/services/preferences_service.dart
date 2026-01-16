import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sticker.dart';


class PreferencesService extends ChangeNotifier {
  static const _poolKey = 'sticker_pool';
  late SharedPreferences _prefs;
  // PreferencesService(this._prefs);


  // --- Keys ---
  static const _keyLanguage = 'app_language'; // 'en' or 'he'
  static const _keyStickerSource = 'sticker_source'; // 'web' or 'pool'
  static const _keyStickerFilters = 'sticker_filters'; // List of Category IDs

  static const _keyWidgetFontSize = 'widget_font_size'; // 'small', 'medium', 'large'
  static const _keyWidgetShowImage = 'widget_show_image'; // bool

  // Legacy/Existing keys (keeping them if needed)
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

  // Future<void> setWidgetShowImage(bool value) async {
  //   _widgetShowImage = value;
  //   await _prefs.setBool(_keyWidgetShowImage, value);
  //   notifyListeners();
  // }

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

  // ---------------------------------------------------------
  // POOL MANAGEMENT
  // ---------------------------------------------------------

  List<Sticker> getStickerPool() {
    final String? jsonString = _prefs.getString(_poolKey);
    if (jsonString == null) return [];

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => Sticker.fromJson(e)).toList();
    } catch (e) {
      return [];
    }
  }

  bool isStickerInPool(int id) {
    final pool = getStickerPool();
    return pool.any((s) => s.id == id);
  }

  Future<void> addToPool(Sticker sticker) async {
    final pool = getStickerPool();
    if (pool.any((s) => s.id == sticker.id)) return; // Already in pool

    // 1. Download and Save Image Locally
    String? localPath;
    if (sticker.imageUrl.isNotEmpty) {
      try {
        localPath = await _downloadAndSaveImage(sticker.imageUrl, sticker.id);
      } catch (e) {
        // If download fails, we still save the sticker, just without local image
        print('Failed to download image for pool: $e');
      }
    }

    // 2. Update Sticker object
    final newSticker = sticker.copyWith(localImagePath: localPath);

    // 3. Save to List
    pool.add(newSticker);
    await _savePoolList(pool);
  }

  Future<void> removeFromPool(int id) async {
    final pool = getStickerPool();
    final stickerToRemove = pool.firstWhere((s) => s.id == id, orElse: () => pool.first);

    // 1. Remove local file if exists
    if (stickerToRemove.localImagePath != null) {
      final file = File(stickerToRemove.localImagePath!);
      if (await file.exists()) {
        await file.delete();
      }
    }

    // 2. Remove from list
    pool.removeWhere((s) => s.id == id);
    await _savePoolList(pool);
  }

  Future<void> _savePoolList(List<Sticker> pool) async {
    final jsonList = pool.map((s) => s.toJson()).toList();
    await _prefs.setString(_poolKey, jsonEncode(jsonList));
  }

  // Helper: Download Image
  Future<String> _downloadAndSaveImage(String url, int id) async {
    final directory = await getApplicationDocumentsDirectory();
    final extension = url.split('.').last;
    final filePath = '${directory.path}/pool_$id.$extension';
    final file = File(filePath);

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes);
      return filePath;
    } else {
      throw Exception('Failed to download image');
    }
  }
}