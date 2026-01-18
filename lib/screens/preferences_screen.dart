import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import 'daily_sticker_settings_screen.dart';
import 'widget_settings_screen.dart';

class PreferencesScreen extends StatelessWidget {
  static const String routeName = '/preferences';

  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      // --- FIX: Force LTR on AppBar to keep back button on the left ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(title: Text(prefs.getLabel('preferences'))),
        ),
      ),
      // ----------------------------------------------------------------
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Language Dropdown
          Text(prefs.getLabel('language'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: prefs.language,
            items: [
              DropdownMenuItem(value: 'en', child: Text(prefs.getLabel('english'))),
              DropdownMenuItem(value: 'he', child: Text(prefs.getLabel('hebrew'))),
            ],
            onChanged: (val) {
              if (val != null) prefs.setLanguage(val);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.translate),
            ),
          ),

          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),

          // 2. Daily Sticker Preferences Link
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.grey, width: 1.1),
            ),
            child: ListTile(
              leading: const Icon(Icons.calendar_today, color: Color(0xFF001a7e)),
              title: Text(prefs.getLabel('sticker_preferences')),
              subtitle: Text(prefs.getLabel('source_filters')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, DailyStickerSettingsScreen.routeName);
              },
            ),
          ),

          const SizedBox(height: 16),

          // 3. Widget Preferences Link
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Colors.grey, width: 1.1),
            ),
            child: ListTile(
              leading: const Icon(Icons.widgets, color: Color(0xFF001a7e)),
              title: Text(prefs.getLabel('widget_customization')),
              subtitle: Text(prefs.getLabel('font_size_image')),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pushNamed(context, WidgetSettingsScreen.routeName);
              },
            ),
          ),
        ],
      ),
    );
  }
}