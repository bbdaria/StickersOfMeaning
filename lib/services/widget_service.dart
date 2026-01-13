import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <--- Import this

import '../models/sticker.dart';

class WidgetService {
  static const String androidWidgetProvider = 'StickerWidgetProvider';
  static const String iosWidgetName = 'StickerWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.stickers.of.meaning');
  }

  Future<void> updateStickerWidget(Sticker sticker) async {
    String? localImagePath;

    // 1. Get the "Show Image" preference
    final prefs = await SharedPreferences.getInstance();
    final bool showImage = prefs.getBool('widget_show_image') ?? true;

    // 2. Download the image (only if we need to show it)
    if (showImage && sticker.imageUrl.isNotEmpty) {
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

    // 3. Save Data to Widget
    await HomeWidget.saveWidgetData<String>('sticker_text', sticker.text);
    // Send the boolean setting to the widget
    await HomeWidget.saveWidgetData<bool>('show_image', showImage);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}