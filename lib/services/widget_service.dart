import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/sticker.dart';
import 'package:flutter/material.dart';


class WidgetService {
  static const String androidWidgetProvider = 'StickerWidgetProvider';
  static const String iosWidgetName = 'StickerWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.stickers.of.meaning');
  }

  String _gettextToShow(String lang, String? quoteHe, String? quoteEn, String? content, String? title) {
    if (lang == 'he' && quoteHe != null && quoteHe.isNotEmpty) return quoteHe;
    if (lang == 'en' && quoteEn != null && quoteEn.isNotEmpty) return quoteEn;

    if (content != null && content.isNotEmpty) return content;

    return title ?? "Sticker of Meaning";
  }

  Future<int?> getWidgetStickerId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('latest_sticker_id');
  }

  Future<void> refreshWidgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;
    final double fontSize = prefs.getDouble('widget_font_size') ?? 16.0;
    final int textColor = prefs.getInt('widget_text_color') ?? 0xFF1E3A8A;
    final int rawBgColor = prefs.getInt('widget_bg_color') ?? 0xFFFFFFFF;
    final double opacity = prefs.getDouble('widget_opacity') ?? 1.0;
    final int safeTextColor = Color(textColor).value.toSigned(32);
    final int safeBgColor = Color(rawBgColor).withOpacity(opacity).value.toSigned(32);

    final String language = prefs.getString('app_language') ?? 'en';

    final quoteHe = prefs.getString('latest_sticker_quote_he');
    final quoteEn = prefs.getString('latest_sticker_quote_en');
    final content = prefs.getString('latest_sticker_content');
    final title = prefs.getString('latest_sticker_title');

    final String textToShow = _gettextToShow(language, quoteHe, quoteEn, content, title);

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

    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());
    await HomeWidget.saveWidgetData<String>('sticker_text', textToShow);
    await HomeWidget.saveWidgetData<int>('sticker_text_color', safeTextColor);
    await HomeWidget.saveWidgetData<int>('sticker_bg_color', safeBgColor);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }

  Future<void> updateStickerWidget(Sticker sticker) async {
    String? localImagePath;

    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;
    final double fontSize = prefs.getDouble('widget_font_size') ?? 16.0;
    final String language = prefs.getString('app_language') ?? 'en';

    await prefs.setInt('latest_sticker_id', sticker.id);
    await prefs.setString('latest_sticker_quote_he', sticker.heQuote);
    await prefs.setString('latest_sticker_quote_en', sticker.enQuote);
    await prefs.setString('latest_sticker_content', sticker.content);
    await prefs.setString('latest_sticker_title', sticker.text);
    await prefs.setString('saved_sticker_image_url', sticker.imageUrl);

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final file = File('${docDir.path}/widget_id.txt');
      await file.writeAsString(sticker.id.toString(), flush: true);
    } catch (e) {
      debugPrint("Error writing widget sync file: $e");
    }

    final int textColor = prefs.getInt('widget_text_color') ?? 0xFF1E3A8A;
    final int rawBgColor = prefs.getInt('widget_bg_color') ?? 0xFFFFFFFF;
    final double opacity = prefs.getDouble('widget_opacity') ?? 1.0;

    // MUST cast colors to 32-bit signed integers before passing them over the 
    // home_widget bridge. Flutter uses 64-bit unsigned integers, which will crash 
    // Android's native SharedPreferences if not explicitly converted.
    final int safeTextColor = Color(textColor).value.toSigned(32);
    final int safeBgColor = Color(rawBgColor).withOpacity(opacity).value.toSigned(32);

    final int finalBgColor = Color(rawBgColor).withOpacity(opacity).value;
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


    final String textToShow = _gettextToShow(language, sticker.heQuote, sticker.enQuote, sticker.content, sticker.text);
    await HomeWidget.saveWidgetData<String>('sticker_text', textToShow);
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());
    await HomeWidget.saveWidgetData<int>('sticker_text_color', safeTextColor);
    await HomeWidget.saveWidgetData<int>('sticker_bg_color', safeBgColor);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}
