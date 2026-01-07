import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';

class WidgetSettingsScreen extends StatelessWidget {
  static const String routeName = '/settings/widget';

  const WidgetSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Widget Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Font Size
          const Text('Font Size', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: prefs.widgetFontSize,
            items: const [
              DropdownMenuItem(value: 'small', child: Text('Small')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'large', child: Text('Large')),
            ],
            onChanged: (val) {
              if (val != null) prefs.setWidgetFontSize(val);
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.format_size),
            ),
          ),

          const SizedBox(height: 24),

          // 2. With/Without Image
          SwitchListTile(
            title: const Text('Show Image'),
            subtitle: const Text('Display the sticker image on the widget'),
            secondary: const Icon(Icons.image),
            value: prefs.widgetShowImage,
            onChanged: (val) {
              prefs.setWidgetShowImage(val);
            },
          ),
        ],
      ),
    );
  }
}