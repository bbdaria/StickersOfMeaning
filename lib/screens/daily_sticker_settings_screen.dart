import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/preferences_service.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import '../services/background_service.dart';
import 'package:workmanager/workmanager.dart';

class DailyStickerSettingsScreen extends StatefulWidget {
  static const routeName = '/daily-settings';
  const DailyStickerSettingsScreen({super.key});

  @override
  State<DailyStickerSettingsScreen> createState() => _DailyStickerSettingsScreenState();
}

class _DailyStickerSettingsScreenState extends State<DailyStickerSettingsScreen> {
  Map<int, String> _allWebCategories = {};
  bool _isLoadingCats = true;
  int _refreshInterval = 15;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }


  Future<void> _updateRefreshInterval(int? newValue) async {
    if (newValue == null) return;

    setState(() => _refreshInterval = newValue);

    final prefs = context.read<PreferencesService>();
    await prefs.setRefreshInterval(newValue);
    await BackgroundService.scheduleUpdate(newValue);
  }

  Future<void> _loadCategories() async {
    try {
      final prefs = context.read<PreferencesService>();
      final cats = await context.read<ApiService>().fetchCategories();

      if (mounted) {
        int loadedInterval = prefs.getRefreshInterval();

        const allowedValues = [0, 15, 60, 720, 1440];

        if (!allowedValues.contains(loadedInterval)) {
          loadedInterval = 15;
          prefs.setRefreshInterval(loadedInterval);
        }

        setState(() {
          _allWebCategories = cats;
          _isLoadingCats = false;
          _refreshInterval = loadedInterval;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingCats = false);
    }
  }

  Future<void> _updateWidgetOnly() async {
    final prefs = context.read<PreferencesService>();

    try {
      await context.read<ApiService>().updateWidgetContent(
        context.read<PreferencesService>(),
        context.read<WidgetService>(),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${prefs.getLabel('update_failed')}: $e'), backgroundColor: Colors.red),
        );
      }
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
          child: AppBar(title: Text(prefs.getLabel('content_preferences'))),
        ),
      ),
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
              Text(
                prefs.getLabel('widget_source'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                prefs.getLabel('widget_source_desc'),
                style: const TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(
                    value: 'web',
                    label: Text(prefs.getLabel('from_web')),
                    icon: const Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: 'pool',
                    label: Text(prefs.getLabel('from_collection')),
                    icon: const Icon(Icons.collections_bookmark),
                  ),
                ],
                selected: {prefs.stickerSource},
                onSelectionChanged: (Set<String> newSelection) async {
                  final newValue = newSelection.first;
                  if (newValue != prefs.stickerSource) {
                    await prefs.setDailyFilterCategories([]);
                    await prefs.setStickerSource(newValue);
                    _updateWidgetOnly();
                  }
                },
                style: const ButtonStyle(
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
                          prefs.getLabel('empty_collection_warning'),
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
                  Text(
                    prefs.getLabel('filter_stickers_title'),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  if (currentFilters.isNotEmpty)
                    TextButton(
                      onPressed: () async {
                        await prefs.setDailyFilterCategories([]);
                        _updateWidgetOnly();
                      },
                      child: Text(prefs.getLabel('clear_all')),
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
                          ? prefs.getLabel('no_categorized_stickers')
                          : prefs.getLabel('no_categories_available'),
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
                        _updateWidgetOnly();
                      },
                    );
                  }).toList(),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),
              Text(
                prefs.getLabel('auto_refresh_widget'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E3A8A)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<int>(
                    isExpanded: true,
                    value: _refreshInterval,
                    items: [
                      DropdownMenuItem(value: 0, child: Text(prefs.getLabel('manual_refresh_opt'))),
                      DropdownMenuItem(value: 15, child: Text(prefs.getLabel('15min_refresh_opt'))),
                      DropdownMenuItem(value: 60, child: Text(prefs.getLabel('1h_refresh_opt'))),
                      DropdownMenuItem(value: 720, child: Text(prefs.getLabel('12h_refresh_opt'))),
                      DropdownMenuItem(value: 1440, child: Text(prefs.getLabel('24h_refresh_opt'))),
                    ],
                    onChanged: _updateRefreshInterval,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                title: Text(prefs.getLabel('refresh_widget')),
                leading: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: _updateWidgetOnly,
              ),
              const SizedBox(height: 10),

              // >>>>>>>>>>>>>> TEST BUTTON:
              TextButton(
                onPressed: () {
                  Workmanager().registerOneOffTask(
                    "test_task_${DateTime.now().millisecondsSinceEpoch}",
                    "widgetUpdateTask",
                    constraints: Constraints(networkType: NetworkType.connected),
                  );
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Triggered Background Test!')));
                },
                child: const Text("Test Background Logic Now"),
              )
            ],
          );
        },
      ),
    );
  }
}