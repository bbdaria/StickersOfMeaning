import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// If flutter_localizations is not in pubspec, these imports might fail.
// Standard Flutter projects usually have them. If not, the Locale('he') will still trigger basic RTL.
import 'package:flutter_localizations/flutter_localizations.dart';

import 'screens/home_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/sticker_search_screen.dart';
import 'screens/todays_sticker_screen.dart';
import 'screens/daily_sticker_settings_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'screens/sticker_pool_screen.dart';
import 'widgets/connectivity_wrapper.dart';
import 'services/preferences_service.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class StickersApp extends StatelessWidget {
  const StickersApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Watch preferences to update locale when language changes
    final prefs = context.watch<PreferencesService>();

    return MaterialApp(
      // Dynamic Title
      title: prefs.getLabel('app_title'),

      // Locale Setup
      locale: Locale(prefs.language),
      supportedLocales: const [
        Locale('en', ''),
        Locale('he', ''),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],

      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2596be),
          surface: Colors.white,
          surfaceTint: Colors.transparent,
        ),
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 2,
        ),
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200],
          selectedColor: const Color(0xFF1E3A8A),
          disabledColor: Colors.grey[300],
          surfaceTintColor: Colors.transparent,
          labelStyle: const TextStyle(color: Colors.black),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
          actionsIconTheme: IconThemeData(color: Colors.black),
          elevation: 0,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
          prefixIconColor: const Color(0xFF0B2A6F),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B2A6F), width: 2),
          ),
        ),
      ),
      navigatorKey: navigatorKey,
      builder: (context, child) {
        return ConnectivityWrapper(
          navigatorKey: navigatorKey,
          child: child ?? const SizedBox.shrink(),
        );
      },
      initialRoute: HomeScreen.routeName,
      routes: {
        HomeScreen.routeName: (_) => const HomeScreen(),
        PreferencesScreen.routeName: (_) => const PreferencesScreen(),
        StickerSearchScreen.routeName: (_) => const StickerSearchScreen(),
        TodaysStickerScreen.routeName: (_) => const TodaysStickerScreen(),
        DailyStickerSettingsScreen.routeName: (_) => const DailyStickerSettingsScreen(),
        WidgetSettingsScreen.routeName: (_) => const WidgetSettingsScreen(),
        StickerPoolScreen.routeName: (_) => const StickerPoolScreen(),
      },
    );
  }
}