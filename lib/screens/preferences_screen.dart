import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/preferences_service.dart';

class PreferencesScreen extends StatelessWidget {
  static const String routeName = '/preferences';

  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Preferences'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Widget style',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: prefs.widgetStyle,
            items: const [
              DropdownMenuItem(
                value: 'classic',
                child: Text('Classic'),
              ),
              DropdownMenuItem(
                value: 'minimal',
                child: Text('Minimal'),
              ),
              DropdownMenuItem(
                value: 'bold',
                child: Text('Bold'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                prefs.setWidgetStyle(value);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Widget size',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: prefs.widgetSize,
            items: const [
              DropdownMenuItem(
                value: 'small',
                child: Text('Small'),
              ),
              DropdownMenuItem(
                value: 'medium',
                child: Text('Medium'),
              ),
              DropdownMenuItem(
                value: 'large',
                child: Text('Large'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                prefs.setWidgetSize(value);
              }
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
              'These settings will be used by the home-screen widget.'),
        ],
      ),
    );
  }
}
