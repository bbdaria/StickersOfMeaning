import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/sticker.dart';

class WidgetService {
  static const String androidWidgetProvider = 'StickerWidgetProvider';
  static const String iosWidgetName = 'StickerWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.stickers.of.meaning');
  }

  // --- HELPER: Logic to pick the correct text ---
  String _gettextToShow(String lang, String? quoteHe, String? quoteEn, String? content, String? title) {
    // 1. Try Specific Language Quote
    if (lang == 'he' && quoteHe != null && quoteHe.isNotEmpty) return quoteHe;
    if (lang == 'en' && quoteEn != null && quoteEn.isNotEmpty) return quoteEn;

    // 2. Fallback to Main Content (The "Quote" from the DB)
    if (content != null && content.isNotEmpty) return content;

    // 3. Last Resort: Title (Name)
    return title ?? "Sticker of Meaning";
  }

  // --- NEW: Get the ID of the sticker currently in the widget ---
  Future<int?> getWidgetStickerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('latest_sticker_id');
  }

  // --- 1. REFRESH SETTINGS (Called by Language Toggle) ---
  Future<void> refreshWidgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;
    final double fontSize = prefs.getDouble('widget_font_size') ?? 16.0;

    // 1. Get Current Language
    final String language = prefs.getString('app_language') ?? 'en';

    // 2. Retrieve the LAST sticker data (Saved in updateStickerWidget)
    final quoteHe = prefs.getString('latest_sticker_quote_he');
    final quoteEn = prefs.getString('latest_sticker_quote_en');
    final content = prefs.getString('latest_sticker_content');
    final title = prefs.getString('latest_sticker_title');

    // 3. Calculate the correct text NOW (In Dart)
    final String textToShow = _gettextToShow(language, quoteHe, quoteEn, content, title);

    // 4. Recovery logic (Image check)
    if (showImage) {
      final savedUrl = prefs.getString('saved_sticker_image_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        try {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_image.png');
          if (!await file.exists()) {
            final response = await http.get(Uri.parse(savedUrl));
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
              await HomeWidget.saveWidgetData<String>('sticker_image', file.path);
            }
          }
        } catch (e) {
          print('Error recovering widget image: $e');
        }
      }
    }

    // Save Data
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());

    // --- KEY FIX: Overwrite 'sticker_text' with the QUOTE ---
    await HomeWidget.saveWidgetData<String>('sticker_text', textToShow);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }

  // --- 2. UPDATE CONTENT (Called by Today's Sticker) ---
  Future<void> updateStickerWidget(Sticker sticker) async {
    String? localImagePath;

    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;
    final double fontSize = prefs.getDouble('widget_font_size') ?? 16.0;
    final String language = prefs.getString('app_language') ?? 'en';

    // 1. Save Sticker Components locally (So we can switch languages later)
    await prefs.setInt('latest_sticker_id', sticker.id); // Save ID
    await prefs.setString('latest_sticker_quote_he', sticker.heQuote);
    await prefs.setString('latest_sticker_quote_en', sticker.enQuote);
    await prefs.setString('latest_sticker_content', sticker.content);
    await prefs.setString('latest_sticker_title', sticker.text);
    await prefs.setString('saved_sticker_image_url', sticker.imageUrl);

    // 2. Download Image
    if (sticker.imageUrl.isNotEmpty) {
      try {
        final url = Uri.parse(sticker.imageUrl);
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_image.png');
          await file.writeAsBytes(response.bodyBytes);
          localImagePath = file.path;
        }
      } catch (e) {
        print('Error downloading widget image: $e');
      }
    }

    // 3. Calculate Text (Use Helper)
    final String textToShow = _gettextToShow(language, sticker.heQuote, sticker.enQuote, sticker.content, sticker.text);

    // 4. Send to Widget
    // We overwrite 'sticker_text' (which usually holds the name) with the QUOTE.
    await HomeWidget.saveWidgetData<String>('sticker_text', textToShow);

    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}