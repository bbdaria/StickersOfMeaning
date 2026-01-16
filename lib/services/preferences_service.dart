import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';
import '../models/sticker.dart';

class PreferencesService extends ChangeNotifier {
  static const _poolKey = 'sticker_pool';
  late SharedPreferences _prefs;

  // --- Keys ---
  static const _keyLanguage = 'app_language';
  static const _keyStickerSource = 'sticker_source';
  static const _keyStickerFilters = 'sticker_filters';
  static const _keyWidgetFontSize = 'widget_font_size';
  static const _keyWidgetShowImage = 'widget_show_image';

  // Legacy keys
  static const _keyDailyDate = 'daily_date';
  static const _keyDailyStickerId = 'daily_sticker_id';
  static const _keySeenStickers = 'seen_sticker_ids';

  // --- Defaults ---
  String _language = 'en';
  String _stickerSource = 'web';
  List<String> _stickerFilters = [];
  double _widgetFontSize = 16.0;
  bool _widgetShowImage = true;

  // --- NEW: In-Memory Cache for Instant UI ---
  List<Sticker> _cachedPool = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    _language = _prefs.getString(_keyLanguage) ?? 'en';
    _stickerSource = _prefs.getString(_keyStickerSource) ?? 'web';
    _stickerFilters = _prefs.getStringList(_keyStickerFilters) ?? [];
    _widgetFontSize = _prefs.getDouble(_keyWidgetFontSize) ?? 16.0;
    _widgetShowImage = _prefs.getBool(_keyWidgetShowImage) ?? true;

    // --- NEW: Load pool into memory once at startup ---
    _loadPoolToMemory();
  }

  // --- NEW: Internal loader ---
  void _loadPoolToMemory() {
    final String? jsonString = _prefs.getString(_poolKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _cachedPool = decoded.map((e) => Sticker.fromJson(e)).toList();
      } catch (e) {
        debugPrint('Error parsing pool: $e');
        _cachedPool = [];
      }
    }
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

  // --- Setters (Existing) ---
  Future<void> setLanguage(String value) async {
    _language = value;
    await _prefs.setString(_keyLanguage, value);
    notifyListeners();
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
    _widgetFontSize = size;
    await _prefs.setDouble(_keyWidgetFontSize, size);
    notifyListeners();
  }

  Future<void> setWidgetShowImage(bool value) async {
    _widgetShowImage = value;
    await _prefs.setBool(_keyWidgetShowImage, value);
    notifyListeners();
  }

  Future<double> getWidgetFontSize() async => _widgetFontSize;
  Future<bool> getWidgetShowImage() async => _widgetShowImage;

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
  // POOL MANAGEMENT (OPTIMIZED)
  // ---------------------------------------------------------

  // 1. Return the in-memory list (Instant)
  List<Sticker> getStickerPool() {
    return List.unmodifiable(_cachedPool); // Return copy/view
  }

  bool isStickerInPool(int id) {
    return _cachedPool.any((s) => s.id == id);
  }

  Future<void> addToPool(Sticker sticker) async {
    if (isStickerInPool(sticker.id)) return;

    // A. Start image download in background (don't await it for the UI update yet)
    // We create a temporary sticker with the URL, add it to UI immediately
    Sticker stickerToSave = sticker;

    // Update Memory
    _cachedPool.add(stickerToSave);

    // B. INSTANT UPDATE: Tell UI to paint the "filled" ribbon
    notifyListeners();

    // C. Perform heavy lifting in background
    try {
      if (sticker.imageUrl.isNotEmpty) {
        final localPath = await _downloadAndSaveImage(sticker.imageUrl, sticker.id);
        // Update the sticker in the list with the local path
        final index = _cachedPool.indexWhere((s) => s.id == sticker.id);
        if (index != -1) {
          _cachedPool[index] = sticker.copyWith(localImagePath: localPath);
        }
      }

      // Persist to Disk
      await _savePoolToDisk();

      // Notify again to ensure the local path is available to UI if needed
      notifyListeners();
    } catch (e) {
      print('Background save error: $e');
    }
  }

  Future<void> removeFromPool(int id) async {
    final index = _cachedPool.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final stickerToRemove = _cachedPool[index];

    // A. Update Memory
    _cachedPool.removeAt(index);

    // B. INSTANT UPDATE: Tell UI to paint the "empty" ribbon
    notifyListeners();

    // C. Cleanup in background
    if (stickerToRemove.localImagePath != null) {
      final file = File(stickerToRemove.localImagePath!);
      if (await file.exists()) {
        await file.delete().catchError((e) => print(e));
      }
    }

    await _savePoolToDisk();
  }

  Future<void> _savePoolToDisk() async {
    // Encode the in-memory list
    final jsonList = _cachedPool.map((s) => s.toJson()).toList();
    await _prefs.setString(_poolKey, jsonEncode(jsonList));
  }

  // Helper: Download Image
  Future<String> _downloadAndSaveImage(String url, int id) async {
    final directory = await getApplicationDocumentsDirectory();
    final extension = url.split('.').last;
    // Basic sanitization of extension
    final safeExt = extension.length > 4 ? 'jpg' : extension;

    final filePath = '${directory.path}/pool_$id.$safeExt';
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