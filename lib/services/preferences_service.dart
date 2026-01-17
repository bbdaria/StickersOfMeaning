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

  String _appPath = '';

  // --- Keys ---
  static const _keyLanguage = 'app_language';
  static const _keyStickerSource = 'sticker_source';
  static const _keyStickerFilters = 'sticker_filters';
  static const _keyDailyFilters = 'daily_sticker_filters';
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
  List<int> _dailyFilterCategories = [];
  double _widgetFontSize = 16.0;
  bool _widgetShowImage = true;

  List<Sticker> _cachedPool = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    final dir = await getApplicationDocumentsDirectory();
    _appPath = dir.path;

    _language = _prefs.getString(_keyLanguage) ?? 'en';
    _stickerSource = _prefs.getString(_keyStickerSource) ?? 'web';
    _stickerFilters = _prefs.getStringList(_keyStickerFilters) ?? [];

    // Load Daily Filters
    final dailyFilterList = _prefs.getStringList(_keyDailyFilters) ?? [];
    _dailyFilterCategories = dailyFilterList.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toList();

    _widgetFontSize = _prefs.getDouble(_keyWidgetFontSize) ?? 16.0;
    _widgetShowImage = _prefs.getBool(_keyWidgetShowImage) ?? true;

    _loadPoolToMemory();
  }

  // --- Robust Loader ---
  void _loadPoolToMemory() {
    final String? jsonString = _prefs.getString(_poolKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _cachedPool = decoded.map((e) {

          // RECONSTRUCTION LOGIC
          if (e['localImagePath'] != null && _appPath.isNotEmpty) {
            final String rawPath = e['localImagePath'].toString();

            // 1. Extract Filename safely (handles / and \)
            final String fileName = rawPath.split(RegExp(r'[/\\]')).last;

            // 2. Rebuild valid path for CURRENT device
            e['localImagePath'] = '$_appPath${Platform.pathSeparator}$fileName';

            // Debug check (Optional)
            // print('Restored path: ${e['localImagePath']}');
          }

          return Sticker.fromJson(e);
        }).toList();
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
  List<int> get dailyFilterCategories => _dailyFilterCategories;
  List<String> get seenStickerIds => _prefs.getStringList(_keySeenStickers) ?? [];

  // --- Setters ---
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

  Future<void> setDailyFilterCategories(List<int> ids) async {
    _dailyFilterCategories = ids;
    await _prefs.setStringList(_keyDailyFilters, ids.map((e) => e.toString()).toList());
    notifyListeners();
  }

  Future<void> clearHistory() async {
    await _prefs.remove(_keySeenStickers);
  }

  // ---------------------------------------------------------
  // POOL MANAGEMENT
  // ---------------------------------------------------------

  List<Sticker> getStickerPool() {
    return List.unmodifiable(_cachedPool);
  }

  bool isStickerInPool(int id) {
    return _cachedPool.any((s) => s.id == id);
  }

  Future<void> addToPool(Sticker sticker) async {
    if (isStickerInPool(sticker.id)) return;

    // 1. Add to Memory (Optimistic UI)
    Sticker stickerToSave = sticker;
    _cachedPool.add(stickerToSave);
    notifyListeners();

    // 2. Background: Download & Save
    try {
      if (sticker.imageUrl.isNotEmpty) {
        // Returns the FULL valid path
        final localPath = await _downloadAndSaveImage(sticker.imageUrl, sticker.id);

        final index = _cachedPool.indexWhere((s) => s.id == sticker.id);
        if (index != -1) {
          _cachedPool[index] = sticker.copyWith(localImagePath: localPath);
        }
      }

      await _savePoolToDisk();
      notifyListeners();
    } catch (e) {
      debugPrint('Background save error: $e');
    }
  }

  Future<void> removeFromPool(int id) async {
    final index = _cachedPool.indexWhere((s) => s.id == id);
    if (index == -1) return;

    final stickerToRemove = _cachedPool[index];

    _cachedPool.removeAt(index);
    notifyListeners();

    if (stickerToRemove.localImagePath != null) {
      final file = File(stickerToRemove.localImagePath!);
      if (await file.exists()) {
        await file.delete().catchError((e) => debugPrint(e.toString()));
      }
    }

    await _savePoolToDisk();
  }

  Future<void> _savePoolToDisk() async {
    final jsonList = _cachedPool.map((s) {
      final json = s.toJson();

      // STRIPPING LOGIC
      if (json['localImagePath'] != null) {
        final String fullPath = json['localImagePath'].toString();
        // Extract just the filename to save
        final String fileName = fullPath.split(RegExp(r'[/\\]')).last;
        json['localImagePath'] = fileName;
      }

      return json;
    }).toList();

    await _prefs.setString(_poolKey, jsonEncode(jsonList));
  }

  Future<String> _downloadAndSaveImage(String url, int id) async {
    final directory = await getApplicationDocumentsDirectory();

    // Clean extension logic
    final uri = Uri.parse(url);
    String extension = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
    if (extension.length > 4) extension = 'jpg'; // safety fallback

    final fileName = 'pool_$id.$extension';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      // FIX: Add flush:true to ensure data is written to disk immediately
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return filePath;
    } else {
      throw Exception('Failed to download image');
    }
  }
}