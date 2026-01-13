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

  // --- 1. REFRESH & RECOVER (Call this from Settings) ---
  Future<void> refreshWidgetSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;

    // RECOVERY LOGIC: If turning ON, ensure we actually have the image file!
    if (showImage) {
      final savedUrl = prefs.getString('saved_sticker_image_url');
      if (savedUrl != null && savedUrl.isNotEmpty) {
        try {
          // Check if we need to re-download
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_image.png');

          if (!await file.exists()) {
            print('DEBUG: Image missing. Downloading recovery image...');
            final response = await http.get(Uri.parse(savedUrl));
            if (response.statusCode == 200) {
              await file.writeAsBytes(response.bodyBytes);
              // Ensure the widget knows the path
              await HomeWidget.saveWidgetData<String>('sticker_image', file.path);
            }
          }
        } catch (e) {
          print('Error recovering widget image: $e');
        }
      }
    }

    // Save the new setting
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);

    // Force update
    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }

  // --- 2. UPDATE (Call this from Today's Sticker) ---
  Future<void> updateStickerWidget(Sticker sticker) async {
    String? localImagePath;

    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;

    // Save URL for future recovery (in case user toggles settings later)
    await prefs.setString('saved_sticker_image_url', sticker.imageUrl);

    // ALWAYS download the image if it exists.
    // This ensures that if the user toggles "Show Image" later, the file is ready.
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

    // Save Data
    await HomeWidget.saveWidgetData<String>('sticker_text', sticker.text);
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}