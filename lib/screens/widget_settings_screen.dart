import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    Colors.black,
    Color(0xFF0e197e), // Navy
    Color(0xFF1E3A8A), // Navy
    Color(0xFF4b83bc), // Navy
    Color(0xFF66b0fb), // Navy
    Colors.white
  ];

  final List<Color> _bgColors = const [
    Colors.black,
    Color(0xFF0e197e), // Navy
    Color(0xFF1E3A8A), // Navy
    Color(0xFF4b83bc), // Navy
    Color(0xFF66b0fb), // Navy
    Colors.white
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

  Widget _buildColorSelector(String title, List<Color> colors, int selectedValue, Function(int) onSelected, double size) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(title, style: TextStyle(fontSize: size)),
        ),
        Container(
          height: 45, // Height of the color bar
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12), // 1. Rounded Corners
            border: Border.all(color: Colors.grey.shade300, width: 1), // 2. Boundary
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1), // 3. Shadow
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(11), // Clip inner content to match border
            child: Row(
              // 4. "One next to the other" - No gaps, using Expanded
              children: colors.map((color) {
                final isSelected = color.value == selectedValue;

                // Calculate contrast for the checkmark icon
                final isLight = color.computeLuminance() > 0.5 || color.opacity < 0.5;

                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => onSelected(color.value));
                      _saveSettings();
                    },
                    child: Container(
                      color: color, // The color block
                      alignment: Alignment.center,
                      child: isSelected
                          ? Icon(
                        Icons.check_circle,
                        color: isLight ? Colors.black54 : Colors.white,
                        size: 24,
                      )
                          : null,
                    ),
                  ),
                );
              }).toList(),
            ),
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
            title: Text(prefs.getLabel('widget_font_size'), style: TextStyle(fontSize: 16),),
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
          if (!_showImage)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                prefs.getLabel('preview_text_size'),
                style: TextStyle(fontSize: _fontSize, color: Colors.grey, fontStyle: FontStyle.italic),
              ),
            ),

          const Divider(),
          // Opacity Slider
          ListTile(
            title: Text(prefs.getLabel('background_opacity'), style: TextStyle(fontSize: 16),),
            subtitle: Text('${(_opacity * 100).toInt()}%'),
            enabled: !_showImage
          ),
          Slider(
            value: _opacity,
            min: 0.0,
            max: 1.0,
            divisions: 20,
            label: '${(_opacity * 100).toInt()}%',
            onChanged: !_showImage ? (value) => setState(() => _opacity = value) : null,
            onChangeEnd: (value) => _saveSettings(),
          ),
          const SizedBox(height: 2),
          _buildColorSelector(prefs.getLabel('text_color'), _textColors, _textColor,(val) => _textColor = val, 16),
          const SizedBox(height: 8),
          _buildColorSelector(prefs.getLabel('background_color'), _bgColors, _bgColor, (val) => _bgColor = val, 16),

          const SizedBox(height: 16),

          // Live Preview Card
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(prefs.getLabel('preview'), style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 350,
              height: 130,
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
                    prefs.getLabel('widget_preview'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: _fontSize,
                      color: Color(_textColor),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Small logo simulation
                  SvgPicture.asset('assets/icons/Logo.svg', height: 24, errorBuilder: (_,__,___) => const Icon(Icons.star, size: 24)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}