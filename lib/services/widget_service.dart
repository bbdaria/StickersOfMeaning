import 'package:home_widget/home_widget.dart';

import '../models/sticker.dart';

class WidgetService {
  static const String androidWidgetProvider =
      'StickerWidgetProvider'; // must match android name
  static const String iosWidgetName = 'StickerWidget'; // later when you do iOS

  Future<void> init() async {
    await HomeWidget.setAppGroupId('group.stickers.of.meaning'); // iOS later
  }

  Future<void> updateStickerWidget(Sticker sticker) async {
    await HomeWidget.saveWidgetData<String>('sticker_text', sticker.text);
    await HomeWidget.saveWidgetData<String>('sticker_image', sticker.imageUrl);

    await HomeWidget.updateWidget(
      name: androidWidgetProvider,
      iOSName: iosWidgetName,
    );
  }
}
