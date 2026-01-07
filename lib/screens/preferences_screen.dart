import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';

class PreferencesScreen extends StatefulWidget {
  static const String routeName = '/preferences';

  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  // Local state for the new toggles (not connected to logic yet)
  bool _isHebrew = false;
  bool _isQuoteOnly = false;

  InputDecoration _getSearchStyleDecoration() {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0B2A6F)), // Navy Blue
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0B2A6F), width: 2),
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
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
              DropdownMenuItem(value: 'classic', child: Text('Classic')),
              DropdownMenuItem(value: 'minimal', child: Text('Minimal')),
              DropdownMenuItem(value: 'bold', child: Text('Bold')),
            ],
            onChanged: (v) => v != null ? prefs.setWidgetStyle(v) : null,
            decoration: _getSearchStyleDecoration(), // Apply Style
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
              DropdownMenuItem(value: 'small', child: Text('Small')),
              DropdownMenuItem(value: 'medium', child: Text('Medium')),
              DropdownMenuItem(value: 'large', child: Text('Large')),
            ],
            onChanged: (v) => v != null ? prefs.setWidgetSize(v) : null,
            decoration: _getSearchStyleDecoration(), // Apply Style
          ),

          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 16),

          // --- New Toggle: Language ---
          _buildToggleRow(
            title: "App Language",
            subtitle: _isHebrew ? "Hebrew" : "English",
            value: _isHebrew,
            onChanged: (val) {
              setState(() {
                _isHebrew = val;
              });
            },
          ),

          const SizedBox(height: 24),

          // --- New Toggle: Display Mode ---
          _buildToggleRow(
            title: "Content Display",
            subtitle: _isQuoteOnly ? "Show quote only" : "Show fallen soldier",
            value: _isQuoteOnly,
            onChanged: (val) {
              setState(() {
                _isQuoteOnly = val;
              });
            },
          ),

          const SizedBox(height: 40),
          const Center(
            child: Text(
              'These settings will be used by the home-screen widget.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ],
        ),
        GradientSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// Custom Switch with Horizontal Gradient Support
class GradientSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const GradientSwitch({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        width: 55.0,
        height: 30.0,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15.0),
          gradient: value
              ? const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [
              Color(0xFF001a7e),
              Color(0xFF1d6caf),
            ],
          )
              : null,
          // UPDATED: "Off" state is now explicitly Neutral Light Gray (Colors.grey[300])
          // If you want it exactly like the hint text, use Color(0xFF8A8A8A)
          color: value ? null : const Color(0xFFE0E0E0),
        ),
        child: Padding(
          padding: const EdgeInsets.all(2.0),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26.0,
              height: 26.0,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    offset: Offset(0, 2),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}