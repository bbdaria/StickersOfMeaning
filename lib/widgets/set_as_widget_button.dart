import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticker.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';

class StickerWidgetButton extends StatefulWidget {
  final Sticker sticker;
  final bool compact;

  const StickerWidgetButton({
    super.key,
    required this.sticker,
    this.compact = false,
  });

  @override
  State<StickerWidgetButton> createState() => _StickerWidgetButtonState();
}

class _StickerWidgetButtonState extends State<StickerWidgetButton> {
  bool _isUpdating = false;

  Future<void> _sendToWidget() async {
    if (_isUpdating) return;

    setState(() => _isUpdating = true);

    // Visual Feedback: Loading
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
          SizedBox(width: 16),
          Text("Updating Widget...")
        ]),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      final widgetService = context.read<WidgetService>();
      final prefs = context.read<PreferencesService>();

      await widgetService.updateStickerWidget(widget.sticker);

      // Update Global State
      await prefs.setWidgetStickerId(widget.sticker.id);

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Widget Updated!")),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch the global preference state
    final prefs = context.watch<PreferencesService>();
    final isAlreadyInWidget = prefs.widgetStickerId == widget.sticker.id;

    if (_isUpdating) {
      return const SizedBox(
        height: 40,
        child: Center(
            child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2)
            )
        ),
      );
    }

    if (isAlreadyInWidget) {
      // "In Widget" State (Outlined Button)
      return SizedBox(
        height: 40,
        child: OutlinedButton.icon(
          onPressed: () {}, // No action needed
          style: OutlinedButton.styleFrom(
            padding: EdgeInsets.zero,
            side: const BorderSide(color: Color(0xFF1E3A8A), width: 1),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          icon: const Icon(Icons.check, size: 16, color: Color(0xFF1E3A8A)),
          label: Text(
            prefs.getLabel('sticker_in_widget'),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFF1E3A8A),
              fontWeight: FontWeight.bold,
              fontSize: 11,
            ),
          ),
        ),
      );
    } else {
      // "Set as Widget" State (Gradient Button)
      return Container(
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF1E3A8A),
              Color(0xFF3B82C4)
            ],
          ),
        ),
        child: ElevatedButton(
          onPressed: _sendToWidget,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            padding: EdgeInsets.zero,
          ),
          child: Text(
            prefs.getLabel('send_to_widget'),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      );
    }
  }
}