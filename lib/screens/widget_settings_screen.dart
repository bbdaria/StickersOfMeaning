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
  double _fontSize = 16.0; // Default

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = context.read<PreferencesService>();
    final showImage = await prefs.getWidgetShowImage();
    final fontSize = await prefs.getWidgetFontSize();
    if (mounted) {
      setState(() {
        _showImage = showImage;
        _fontSize = fontSize;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = context.read<PreferencesService>();
    await prefs.setWidgetShowImage(_showImage);
    await prefs.setWidgetFontSize(_fontSize);

    if (mounted) {
      await context.read<WidgetService>().refreshWidgetSettings();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Widget updated!'),
          duration: Duration(milliseconds: 750),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Settings')),
      body: ListView(
        children: [
          // 1. Show Image Toggle
          SwitchListTile(
            title: const Text('Show Image in Widget'),
            subtitle: const Text('If disabled, only the sticker text will be shown.'),
            value: _showImage,
            onChanged: (bool value) {
              setState(() => _showImage = value);
              _saveSettings();
            },
          ),
          const Divider(),

          // 2. Font Size Slider (Only visible if Image is OFF)
          ListTile(
            title: const Text('Widget Font Size'),
            subtitle: Text('${_fontSize.toInt()} sp'),
            enabled: !_showImage, // Disable if image is ON (since text is hidden anyway)
          ),
          Slider(
            value: _fontSize,
            min: 12.0,
            max: 40.0,
            divisions: 28,
            label: _fontSize.round().toString(),
            onChanged: !_showImage
                ? (value) {
              setState(() => _fontSize = value);
            }
                : null, // Disable slider if showing image
            onChangeEnd: (value) {
              _saveSettings(); // Only save/update when user releases the slider
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              "Preview Text Size",
              style: TextStyle(fontSize: _fontSize),
            ),
          ),
        ],
      ),
    );
  }
}