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

  // --- Legacy keys ---
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
    // sets up the service and loads all persistent data into memory at start
    _prefs = await SharedPreferences.getInstance();
    final dir = await getApplicationDocumentsDirectory();
    _appPath = dir.path;
    _language = _prefs.getString(_keyLanguage) ?? 'en';
    _stickerSource = _prefs.getString(_keyStickerSource) ?? 'web';
    _stickerFilters = _prefs.getStringList(_keyStickerFilters) ?? [];
    final dailyFilterList = _prefs.getStringList(_keyDailyFilters) ?? [];
    _dailyFilterCategories = dailyFilterList.map((e) => int.tryParse(e) ?? 0).where((e) => e != 0).toList();

    _widgetFontSize = _prefs.getDouble(_keyWidgetFontSize) ?? 16.0;
    _widgetShowImage = _prefs.getBool(_keyWidgetShowImage) ?? true;

    _loadPoolToMemory();
  }

  // --- Language Dictionary ---
  static const Map<String, Map<String, String>> _labels = {
    'en': {
      'app_title': 'Stickers of meaning',
      'todays_sticker': "Today's Sticker",
      'your_collection': "Your collection",
      'explore_collection': "Explore and add to the collection",
      'customize_widget': "Customize your widget",
      'settings_customization': "Settings and customization",
      'content_preferences': "Content preferences",
      'what_to_see': "What would you like to see?",
      'visit_site': "Visit our site",
      'sticker_of_meaning': "Sticker Of Meaning",
      'see_info': "See Info",
      'send_to_widget': "Send to Widget",
      'sticker_in_widget': "In Widget",
      'could_not_open_site': "Could not open site",
      'preferences': "Preferences",
      'language': "Language",
      'english': "English",
      'hebrew': "עברית",
      'sticker_preferences': "Sticker Preferences",
      'source_filters': "Source & Filters",
      'widget_customization': "Widget Customization",
      'font_size_image': "Font size & Image settings",
      'show_image_widget': "Show Image in Widget",
      'show_image_desc': "If disabled, only the sticker text will be shown.",
      'widget_font_size': "Widget Font Size",
      'preview_text_size': "Preview Text Size",
      'sticker_search': "Sticker Search",
      'search_hint': "Search...",
      'type_to_search': "Type to search...",
      'filters': "Filters (Topics & Options)",
      'loading_topics': "Loading topics...",
      'start_search_instruction': "Type or select a category to start searching.",
      'no_stickers_found': "No stickers found.",
      'add_to_collection': "Add to Collection",
      'already_in_collection': "In collection",
      'set_as_widget': "Set as Widget",
      'no_sticker_available': "No sticker available",
      'open_full_post': "Open full post on site",
      'error_loading': "Error loading sticker",
      'no_link_available': "No link available for this sticker",
      'widget_source': "Widget Source",
      'widget_source_desc': "Where should the home screen widget get its sticker from?",
      'from_web': "From Web",
      'from_collection': "My Collection",
      'empty_collection_warning': "Your collection is empty! The sticker will be taken from the Web until you add some stickers.",
      'filter_stickers_title': "Filter Stickers by Meaning",
      'clear_all': "Clear All",
      'no_categorized_stickers': "No categorized stickers in your collection.",
      'no_categories_available': "No categories available.",
      'refresh_widget': "Refresh widget",
      'update_failed': "Update failed",
      'search_collection_hint': "Search your stickers...",
      'empty_collection_message': "Your collection is empty.\nTap the + button to add stickers!",
      'remove': "Remove",
      'tooltip_save_collection': "Save to collection",
      'tooltip_remove_collection': "Remove from collection",
      'collection_empty': "Collection empty. Switched widget to Web source."
    },
    'he': {
      'app_title': 'מדבקות עם משמעות',
      'todays_sticker': "המדבקה היומית",
      'your_collection': "אוסף המדבקות שלך",
      'explore_collection': "חפש והוסף לאוסף",
      'customize_widget': "הגדרות הווידג'ט",
      'settings_customization': "הגדרות היישומון",
      'content_preferences': "העדפות תוכן",
      'what_to_see': "אילו מדבקות תרצה לראות?",
      'visit_site': "בקר באתר שלנו",
      'sticker_of_meaning': "מדבקות עם משמעות",
      'see_info': "למידע נוסף",
      'send_to_widget': "הגדר כווידג'ט",
      'sticker_in_widget': "בווידג'ט",
      'could_not_open_site': "לא ניתן לפתוח את האתר",
      'preferences': "הגדרות",
      'language': "שפה",
      'english': "English",
      'hebrew': "עברית",
      'sticker_preferences': "הגדרות המדבקות",
      'source_filters': "מקור המדבקות ומסננים",
      'widget_customization': "התאמת וידג'ט",
      'font_size_image': "גודל גופן והגדרות תמונה",
      'show_image_widget': "הצג את תמונת הנופל בווידג'ט",
      'show_image_desc': "כאשר כבוי, יוצג רק טקסט המדבקה.",
      'widget_font_size': "גודל גופן בווידג'ט",
      'preview_text_size': "תצוגה מקדימה של גודל הטקסט",
      'sticker_search': "חיפוש מדבקות",
      'search_hint': "חיפוש...",
      'type_to_search': "הקלד לחיפוש...",
      'filters': "מסננים (נושאים ואפשרויות)",
      'loading_topics': "טוען נושאים...",
      'start_search_instruction': "הקלד או בחר קטגוריה כדי להתחיל לחפש.",
      'no_stickers_found': "לא נמצאו מדבקות.",
      'add_to_collection': "הוסף לאוסף",
      'already_in_collection': "המדבקה באוסף",
      'set_as_widget': "הגדר כווידג'ט",
      'no_sticker_available': "אין מדבקה זמינה",
      'open_full_post': "ראה את הפוסט המלא באתר",
      'error_loading': "שגיאה בטעינת המדבקה",
      'no_link_available': "אין קישור זמין עבור המדבקה הזו",
      'widget_source': "מקור הווידג'ט",
      'widget_source_desc': "מאיפה הווידג'ט במסך הבית צריך לקחת את המדבקה?",
      'from_web': "מהאתר",
      'from_collection': "מהאוסף שלי",
      'empty_collection_warning': "האוסף שלך ריק! המדבקות תלקחנה מאתר עד שתוסיף מדבקות לאוסף.",
      'filter_stickers_title': "סינון סטיקרים לפי משמעות",
      'clear_all': "נקה הכל",
      'no_categorized_stickers': "אין מדבקות מקוטלגות באוסף שלך.",
      'no_categories_available': "אין קטגוריות זמינות.",
      'refresh_widget': "רענן וידג'ט",
      'update_failed': "העדכון נכשל",
      'search_collection_hint': "חפש באוסף שלך...",
      'empty_collection_message': "האוסף שלך ריק.\nלחץ על כפתור ה-+ כדי להוסיף מדבקות!",
      'remove': "הסר",
      'tooltip_save_collection': "הוסף לאוסף",
      'tooltip_remove_collection': "הסר מהאוסף",
      'collection_empty': "האוסף שלך ריק. המדבקות תלקחנה מהאתר."
    }
  };

  String getLabel(String key) {
    return _labels[_language]?[key] ?? _labels['en']?[key] ?? key;
  }

  // --- Robust Loader ---
  void _loadPoolToMemory() {
    final String? jsonString = _prefs.getString(_poolKey);
    if (jsonString != null) {
      try {
        final List<dynamic> decoded = jsonDecode(jsonString);
        _cachedPool = decoded.map((e) {
          if (e['localImagePath'] != null && _appPath.isNotEmpty) {
            final String rawPath = e['localImagePath'].toString();
            final String fileName = rawPath.split(RegExp(r'[/\\]')).last;
            e['localImagePath'] = '$_appPath${Platform.pathSeparator}$fileName';
          }
          return Sticker.fromJson(e);
        }).toList();
      } catch (e) {
        debugPrint('Error parsing collection: $e');
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


  // --- sticker pool management ---

  List<Sticker> getStickerPool() {
    return List.unmodifiable(_cachedPool);
  }

  bool isStickerInPool(int id) {
    return _cachedPool.any((s) => s.id == id);
  }

  Future<void> addToPool(Sticker sticker) async {
    if (isStickerInPool(sticker.id)) return;
    Sticker stickerToSave = sticker;
    _cachedPool.add(stickerToSave);
    notifyListeners();

    try {
      if (sticker.imageUrl.isNotEmpty) {
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
      if (json['localImagePath'] != null) {
        final String fullPath = json['localImagePath'].toString();
        final String fileName = fullPath.split(RegExp(r'[/\\]')).last;
        json['localImagePath'] = fileName;
      }
      return json;
    }).toList();

    await _prefs.setString(_poolKey, jsonEncode(jsonList));
  }

  Future<String> _downloadAndSaveImage(String url, int id) async {
    final directory = await getApplicationDocumentsDirectory();
    final uri = Uri.parse(url);
    String extension = uri.pathSegments.isNotEmpty ? uri.pathSegments.last.split('.').last : 'jpg';
    if (extension.length > 4) extension = 'jpg';
    final fileName = 'pool_$id.$extension';
    final filePath = '${directory.path}/$fileName';
    final file = File(filePath);
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      await file.writeAsBytes(response.bodyBytes, flush: true);
      return filePath;
    } else {
      throw Exception('Failed to download image');
    }
  }

  static const _keyWidgetStickerId = 'current_widget_sticker_id';
  int? get widgetStickerId => _prefs.getInt(_keyWidgetStickerId);
  Future<void> setWidgetStickerId(int id) async {
    await _prefs.setInt(_keyWidgetStickerId, id);
    notifyListeners();
  }
}