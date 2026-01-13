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

  // --- 1. REFRESH SETTINGS (Called by Slider) ---
  Future<void> refreshWidgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;
    final double fontSize = prefs.getDouble('widget_font_size') ?? 16.0;

    // Recovery logic (Image check)
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

    // Save Settings
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);

    // --- FIX: Pass Font Size as String to safely cross to Android ---
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());
    // ---------------------------------------------------------------

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

    await prefs.setString('saved_sticker_image_url', sticker.imageUrl);

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

    await HomeWidget.saveWidgetData<String>('sticker_text', sticker.text);
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);

    // --- FIX: Pass Font Size as String here too ---
    await HomeWidget.saveWidgetData<String>('sticker_font_size', fontSize.toString());
    // ----------------------------------------------

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}