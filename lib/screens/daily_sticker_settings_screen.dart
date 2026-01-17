import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';

class DailyStickerSettingsScreen extends StatefulWidget {
  static const routeName = '/daily-settings';
  const DailyStickerSettingsScreen({super.key});

  @override
  State<DailyStickerSettingsScreen> createState() => _DailyStickerSettingsScreenState();
}

class _DailyStickerSettingsScreenState extends State<DailyStickerSettingsScreen> {
  Map<int, String> _allWebCategories = {};
  bool _isLoadingCats = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final cats = await context.read<ApiService>().fetchCategories();
      if (mounted) {
        setState(() {
          _allWebCategories = cats;
          _isLoadingCats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCats = false);
    }
  }

  // --- NEW: Updates ONLY the widget, not the Home Screen ---
  Future<void> _updateWidgetOnly() async {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Updating widget...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await context.read<ApiService>().updateWidgetContent(
        context.read<PreferencesService>(),
        context.read<WidgetService>(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Widget updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Widget Preferences')),
      body: Consumer<PreferencesService>(
        builder: (context, prefs, child) {
          final pool = prefs.getStickerPool();
          final poolSize = pool.length;
          final currentFilters = prefs.dailyFilterCategories;
          final isPoolSource = prefs.stickerSource == 'pool';

          Set<int> validCategoryIds;
          if (isPoolSource) {
            validCategoryIds = pool.expand((sticker) => sticker.categories).toSet();
          } else {
            validCategoryIds = _allWebCategories.keys.toSet();
          }

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Widget Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Where should the home screen widget get its sticker from?',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'web',
                    label: Text('From Web'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: 'pool',
                    label: Text('My Collection'),
                    icon: Icon(Icons.collections_bookmark),
                  ),
                ],
                selected: {prefs.stickerSource},
                onSelectionChanged: (Set<String> newSelection) async {
                  final newValue = newSelection.first;
                  if (newValue != prefs.stickerSource) {
                    await prefs.setDailyFilterCategories([]);
                    await prefs.setStickerSource(newValue);
                    _updateWidgetOnly(); // Trigger widget update
                  }
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              if (isPoolSource && poolSize == 0)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.5)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.orange),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your collection is empty! The sticker will be taken from the Web until you add some stickers.',
                          style: TextStyle(color: Colors.orange[800], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Stickers by Meaning',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (currentFilters.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await prefs.setDailyFilterCategories([]);
                        _updateWidgetOnly();
                      },
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (_isLoadingCats)
                const Center(child: CircularProgressIndicator())
              else if (validCategoryIds.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      isPoolSource
                          ? 'No categorized stickers in your collection.'
                          : 'No categories available.',
                      style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: _allWebCategories.entries
                      .where((entry) => validCategoryIds.contains(entry.key))
                      .map((entry) {
                    final isSelected = currentFilters.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF1E3A8A),
                      onSelected: (bool selected) async {
                        List<int> newFilters = List.from(currentFilters);
                        if (selected) {
                          newFilters.add(entry.key);
                        } else {
                          newFilters.remove(entry.key);
                        }
                        await prefs.setDailyFilterCategories(newFilters);
                        _updateWidgetOnly(); // Trigger widget update
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              ListTile(
                title: const Text('Refresh widget'),
                leading: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: _updateWidgetOnly,
              ),
            ],
          );
        },
      ),
    );
  }
}