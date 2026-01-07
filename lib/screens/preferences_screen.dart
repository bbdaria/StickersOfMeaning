import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import 'daily_sticker_settings_screen.dart';
import 'widget_settings_screen.dart';
import '../widgets/gradient_button.dart'; // Assuming you want to keep the style

class PreferencesScreen extends StatelessWidget {
  static const String routeName = '/preferences';

  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Language Dropdown
          const Text('Language', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: prefs.language,
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'he', child: Text('Hebrew')),
            ],
            onChanged: (val) {
              if (val != null) prefs.setLanguage(val);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              // The requested Google Translate-style icon
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
              title: const Text('Daily Sticker Preferences'),
              subtitle: const Text('Source & Filters'),
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
              title: const Text('Widget Preferences'),
              subtitle: const Text('Font size & Image settings'),
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