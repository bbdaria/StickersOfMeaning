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
  double _fontSize = 16.0;

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
      // Removed Success Snackbar
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(title: Text(prefs.getLabel('widget_customization'))),
        ),
      ),
      body: ListView(
        children: [
          SwitchListTile(
            title: Text(prefs.getLabel('show_image_widget')),
            subtitle: Text(prefs.getLabel('show_image_desc')),
            value: _showImage,
            onChanged: (bool value) {
              setState(() => _showImage = value);
              _saveSettings();
            },
          ),
          const Divider(),
          ListTile(
            title: Text(prefs.getLabel('widget_font_size')),
            subtitle: Text('${_fontSize.toInt()} sp'),
            enabled: !_showImage,
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
                : null,
            onChangeEnd: (value) {
              _saveSettings();
            },
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              prefs.getLabel('preview_text_size'),
              style: TextStyle(fontSize: _fontSize),
            ),
          ),
        ],
      ),
    );
  }
}