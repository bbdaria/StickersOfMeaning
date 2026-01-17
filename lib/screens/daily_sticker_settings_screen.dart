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
  Map<int, String> _availableCategories = {};
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
          _availableCategories = cats;
          _isLoadingCats = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCats = false);
    }
  }

  Future<void> _performAutoRefresh() async {
    // Show a mini loading indicator or just do it in background?
    // User requested "Auto refresh", so a visual feedback is good.
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Refreshing daily sticker...'),
        duration: Duration(seconds: 1),
      ),
    );

    try {
      await context.read<ApiService>().getDailySticker(
        context.read<PreferencesService>(),
        context.read<WidgetService>(),
        forceRefresh: true,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Updated successfully!')),
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
      appBar: AppBar(title: const Text('Daily Sticker Settings')),
      body: Consumer<PreferencesService>(
        builder: (context, prefs, child) {
          final poolSize = prefs.getStickerPool().length;
          final currentFilters = prefs.dailyFilterCategories;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // --- SOURCE SECTION ---
              const Text(
                'Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'web',
                    label: Text('From Web'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: 'pool',
                    label: Text('My Pool'),
                    icon: Icon(Icons.collections_bookmark),
                  ),
                ],
                selected: {prefs.stickerSource},
                onSelectionChanged: (Set<String> newSelection) async {
                  final newValue = newSelection.first;
                  if (newValue != prefs.stickerSource) {
                    await prefs.setStickerSource(newValue);
                    // --- AUTO REFRESH TRIGGER ---
                    _performAutoRefresh();
                  }
                },
                style: ButtonStyle(
                  visualDensity: VisualDensity.comfortable,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),

              if (prefs.stickerSource == 'pool' && poolSize == 0)
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
                          'Your pool is empty! We will use the Web until you add some stickers.',
                          style: TextStyle(color: Colors.orange[800], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),

              // --- FILTER SECTION ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter by Category',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (currentFilters.isNotEmpty)
                    TextButton(
                      onPressed: () => prefs.setDailyFilterCategories([]),
                      child: const Text('Clear All'),
                    ),
                ],
              ),
              const Text(
                'Only show stickers from these categories (Web or Pool). Leave empty for all.',
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 12),

              if (_isLoadingCats)
                const Center(child: CircularProgressIndicator())
              else if (_availableCategories.isEmpty)
                const Text('Unable to load categories.')
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 0,
                  children: _availableCategories.entries.map((entry) {
                    final isSelected = currentFilters.contains(entry.key);
                    return FilterChip(
                      label: Text(entry.value),
                      selected: isSelected,
                      selectedColor: const Color(0xFF1E3A8A).withOpacity(0.2),
                      checkmarkColor: const Color(0xFF1E3A8A),
                      onSelected: (bool selected) {
                        List<int> newFilters = List.from(currentFilters);
                        if (selected) {
                          newFilters.add(entry.key);
                        } else {
                          newFilters.remove(entry.key);
                        }
                        prefs.setDailyFilterCategories(newFilters);
                        // Optional: Refresh immediately on filter change?
                        // Usually simpler to let user hit "Force Update"
                        // or just wait for next day, but let's stick to explicit update for now
                        // to avoid too many requests while toggling chips.
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              // --- ACTIONS ---
              ListTile(
                title: const Text('Force Update Today\'s Sticker'),
                leading: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: _performAutoRefresh,
              ),
            ],
          );
        },
      ),
    );
  }
}