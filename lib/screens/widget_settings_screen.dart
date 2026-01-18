import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';



class WidgetSettingsScreen extends StatefulWidget {
  static const String routeName = '/widget_settings';

  const WidgetSettingsScreen({super.key});

  @override
  State<WidgetSettingsScreen> createState() => _WidgetSettingsScreenState();
}

class _WidgetSettingsScreenState extends State<WidgetSettingsScreen> {
  bool _showImage = true;
  double _fontSize = 16.0;

  int _textColor = 0xFF1E3A8A;
  int _bgColor = 0xFFFFFFFF;
  double _opacity = 1.0;

  // Predefined Palette
  final List<Color> _textColors = const [
    Color(0xFF1E3A8A), // Navy
    Colors.black,
    Colors.white,
    Colors.grey,
    Color(0xFF880E4F), // Maroon
  ];

  final List<Color> _bgColors = const [
    Colors.white,
    Colors.black,
    Color(0xFFE3F2FD),
    Color(0xFFFFF3E0),
    Color(0xFF1A237E),
    Colors.transparent,
  ];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = context.read<PreferencesService>();
    final showImage = await prefs.getWidgetShowImage();
    final fontSize = await prefs.getWidgetFontSize();
    final textColor = await prefs.getWidgetTextColor();
    final bgColor = await prefs.getWidgetBackgroundColor();
    final opacity = await prefs.getWidgetOpacity();

    if (mounted) {
      setState(() {
        _showImage = showImage;
        _fontSize = fontSize;
        _textColor = textColor;
        _bgColor = bgColor;
        _opacity = opacity;
      });
    }
  }

  Future<void> _saveSettings() async {
    final prefs = context.read<PreferencesService>();
    await prefs.setWidgetShowImage(_showImage);
    await prefs.setWidgetFontSize(_fontSize);

    await prefs.setWidgetTextColor(_textColor);
    await prefs.setWidgetBackgroundColor(_bgColor);
    await prefs.setWidgetOpacity(_opacity);

    if (mounted) {
      await context.read<WidgetService>().refreshWidgetSettings();
    }
  }

  void _showColorPicker(BuildContext context, String title, Color currentColor, Function(Color) onColorChanged) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Pick $title Color'),
        content: SingleChildScrollView(
          child: ColorPicker(
            pickerColor: currentColor,
            onColorChanged: onColorChanged,
            labelTypes: const [],
            pickerAreaHeightPercent: 0.8,
          ),
        ),
        actions: <Widget>[
          TextButton(
            child: const Text('Got it'),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildColorSelector(String title, List<Color> colors, int selectedValue, Function(int) onSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        SizedBox(
          height: 60,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: colors.length,
            separatorBuilder: (ctx, i) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final color = colors[index];
              final isSelected = color.value == selectedValue;
              return GestureDetector(
                onTap: () {
                  setState(() => onSelected(color.value));
                  _saveSettings();
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Theme.of(context).primaryColor : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: color.withOpacity(0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        )
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                    Icons.check,
                    color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                  )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
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

          const Divider(),
          // --- Text Mode Only Settings ---
          if (!_showImage) ...[

            // Opacity Slider
            ListTile(
              title: const Text("Background Opacity"),
              subtitle: Text('${(_opacity * 100).toInt()}%'),
            ),
            Slider(
              value: _opacity,
              min: 0.0,
              max: 1.0,
              divisions: 20,
              label: '${(_opacity * 100).toInt()}%',
              onChanged: (value) => setState(() => _opacity = value),
              onChangeEnd: (value) => _saveSettings(),
            ),

            const SizedBox(height: 8),
            _buildColorSelector("Text Color", _textColors, _textColor, (val) => _textColor = val),
            const SizedBox(height: 16),
            _buildColorSelector("Background Color", _bgColors, _bgColor, (val) => _bgColor = val),

            const SizedBox(height: 24),

            // Live Preview Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: const Text("Preview", style: TextStyle(color: Colors.grey)),
            ),
            const SizedBox(height: 8),
            Center(
              child: Container(
                width: 300,
                height: 150,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Color(_bgColor).withOpacity(_opacity),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0,4))
                  ],
                ),
                alignment: Alignment.center,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      prefs.getLabel('preview_text_size'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: _fontSize,
                        color: Color(_textColor),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Small logo simulation
                    Image.asset('assets/icons/small_logo.png', height: 24, errorBuilder: (_,__,___) => const Icon(Icons.star, size: 24)),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}