import 'dart:io';
import 'package:home_widget/home_widget.dart';
import 'package:http/http.dart' as http; // Import http
import 'package:path_provider/path_provider.dart'; // Import path_provider

import '../models/sticker.dart';

class WidgetService {
  static const String androidWidgetProvider = 'StickerWidgetProvider';
  static const String iosWidgetName = 'StickerWidget';

  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.stickers.of.meaning');
  }

  Future<void> updateStickerWidget(Sticker sticker) async {
    String? localImagePath;

    // 1. Download the image if it exists
    if (sticker.imageUrl.isNotEmpty) {
      try {
        final url = Uri.parse(sticker.imageUrl);
        final response = await http.get(url);

        if (response.statusCode == 200) {
          // Get a temporary directory on the phone
          final dir = await getApplicationSupportDirectory();
          final file = File('${dir.path}/widget_image.png');

          // Write the image bytes to the file
          await file.writeAsBytes(response.bodyBytes);
          localImagePath = file.path; // This is a real file path now!
        }
      } catch (e) {
        print('Error downloading widget image: $e');
      }
    }

    // 2. Save Data (Pass the LOCAL path, not the URL)
    await HomeWidget.saveWidgetData<String>('sticker_text', sticker.text);
    await HomeWidget.saveWidgetData<String>('sticker_image', localImagePath);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}