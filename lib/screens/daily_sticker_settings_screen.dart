import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/api_service.dart';

class DailyStickerSettingsScreen extends StatefulWidget {
  static const String routeName = '/settings/daily_sticker';

  const DailyStickerSettingsScreen({super.key});

  @override
  State<DailyStickerSettingsScreen> createState() => _DailyStickerSettingsScreenState();
}

class _DailyStickerSettingsScreenState extends State<DailyStickerSettingsScreen> {
  Map<int, String> _availableCategories = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiService>().fetchCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    final isWeb = prefs.stickerSource == 'web';

    return Scaffold(
      appBar: AppBar(title: const Text('Daily Sticker Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. Source Toggle
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Sticker Source', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'web', label: Text('From Web')),
                      ButtonSegment(value: 'pool', label: Text('From Pool')),
                    ],
                    selected: {prefs.stickerSource},
                    onSelectionChanged: (Set<String> newSelection) {
                      prefs.setStickerSource(newSelection.first);
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Filters
          const Text('Sticker Pool Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_availableCategories.isEmpty)
            const Text('No categories available.')
          else
            ..._availableCategories.entries.map((entry) {
              final idStr = entry.key.toString();
              final isSelected = prefs.stickerFilters.contains(idStr);

              return CheckboxListTile(
                title: Text(entry.value),
                value: isSelected,
                onChanged: (bool? checked) {
                  final currentFilters = List<String>.from(prefs.stickerFilters);
                  if (checked == true) {
                    currentFilters.add(idStr);
                  } else {
                    currentFilters.remove(idStr);
                  }
                  prefs.setStickerFilters(currentFilters);
                },
              );
            }),
        ],
      ),
    );
  }
}