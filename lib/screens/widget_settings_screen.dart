import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';

class WidgetSettingsScreen extends StatefulWidget {
  static const String routeName = '/widget_settings';

  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  bool _showImage = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = context.read<PreferencesService>();
    final showImage = await prefs.getWidgetShowImage();
    if (mounted) {
      setState(() {
        _showImage = showImage;
      });
    }
  }

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
            title: const Text('Show Image in Widget'),
            subtitle: const Text('If disabled, only the sticker text will be shown.'),
            value: _showImage,
            onChanged: (bool value) async {
              setState(() => _showImage = value);

              // 1. Save to App Preferences
              await context.read<PreferencesService>().setWidgetShowImage(value);

              // 2. TRIGGER THE WIDGET UPDATE IMMEDIATELY
              if (mounted) {
                await context.read<WidgetService>().refreshWidgetSettings();

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Widget settings updated!'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
    );
  }
}