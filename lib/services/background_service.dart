import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';
import 'api_service.dart';
import 'preferences_service.dart';
import 'widget_service.dart';

const String taskName = "widgetUpdateTask";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      if (task == taskName) {
        final prefs = PreferencesService();
        await prefs.init();

        final apiService = ApiService(
          baseUrl: 'https://stickersofmeaning.org/wp-json/wp/v2/',
          dbUrl: 'https://stickersofmeaning.org/wp-json/wp/v2/',
        );

        final widgetService = WidgetService();
        await apiService.updateWidgetContent(prefs, widgetService);
      }
      return Future.value(true);
    } catch (e) {
      debugPrint("Background Task Error: $e");
      return Future.value(false);
    }
  });
}

class BackgroundService {
  static Future<void> init() async {
    await Workmanager().initialize(
      callbackDispatcher
    );
  }

  static Future<void> scheduleUpdate(int intervalMinutes) async {
    await Workmanager().cancelAll();

    if (intervalMinutes > 0) {
      await Workmanager().registerPeriodicTask(
        "1",
        taskName,
        frequency: Duration(minutes: intervalMinutes),
        constraints: Constraints(
          networkType: NetworkType.connected,
        ),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
        initialDelay: Duration(minutes: intervalMinutes),
      );
    }
  }
}