import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'screens/preferences_screen.dart';
import 'screens/sticker_search_screen.dart';
import 'screens/todays_sticker_screen.dart';
import 'screens/daily_sticker_settings_screen.dart';
import 'screens/widget_settings_screen.dart';
import 'widgets/connectivity_wrapper.dart';


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class StickersApp extends StatelessWidget {
  const StickersApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Stickers of meaning',
      theme: ThemeData(
        // 1. Force the background to be pure white
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,

        // 2. Remove the "Orange/Blue" Tint from all Colors
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2596be),
          surface: Colors.white, // Force surface to be white
          surfaceTint: Colors.transparent, // CRITICAL: Removes the overlay tint
        ),

        // 3. Fix the Daily Sticker & Menu Cards (Force White)
        // UPDATED: Changed 'CardTheme' to 'CardThemeData' to fix the error
        cardTheme: const CardThemeData(
          color: Colors.white,
          surfaceTintColor: Colors.transparent, // No color overlay
          elevation: 2, // Keeps a small shadow for depth
        ),

        // 4. Fix Filter Chips (Search Screen) - "Off" state becomes light gray
        chipTheme: ChipThemeData(
          backgroundColor: Colors.grey[200], // Neutral Light Gray when unselected
          selectedColor: const Color(0xFF1E3A8A), // Blue when selected
          disabledColor: Colors.grey[300],
          surfaceTintColor: Colors.transparent,
          // Text color logic
          labelStyle: const TextStyle(color: Colors.black),
          secondaryLabelStyle: const TextStyle(color: Colors.white),
        ),

        // Global AppBar theme
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          iconTheme: IconThemeData(color: Colors.black),
          actionsIconTheme: IconThemeData(color: Colors.black),
          elevation: 0,
        ),

        // Global Search / Input Theme
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white, // Pure white background
          hintStyle: const TextStyle(color: Color(0xFF8A8A8A)), // Neutral gray placeholder
          prefixIconColor: const Color(0xFF0B2A6F), // Matching navy icon
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          // Default Border (Navy Blue #0B2A6F)
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
          ),
          // Enabled Border (When not clicked)
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
          ),
          // Focused Border (When typing)
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
      },
    );
  }
}