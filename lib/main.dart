import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'services/api_service.dart';
import 'services/preferences_service.dart';
import 'services/widget_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final preferencesService = PreferencesService();
  await preferencesService.init(); // load stored prefs

  final apiService = ApiService(
    baseUrl: 'https://example.com/wp-json', // TODO set your WordPress url
  );

  final widgetService = WidgetService();

  runApp(
    MultiProvider(
      providers: [
        Provider<ApiService>.value(value: apiService),
        ChangeNotifierProvider<PreferencesService>.value(
          value: preferencesService,
        ),
        Provider<WidgetService>.value(value: widgetService),
      ],
      child: const StickersApp(),
    ),
  );
}
