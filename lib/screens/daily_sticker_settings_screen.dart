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
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Daily Sticker Settings')),
      body: Consumer<PreferencesService>(
        builder: (context, prefs, child) {
          final poolSize = prefs.getStickerPool().length;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Source',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              const Text(
                'Where should the daily sticker come from?',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),

              // --- SOURCE TOGGLE ---
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'web',
                    label: Text('Random from web'),
                    icon: Icon(Icons.public),
                  ),
                  ButtonSegment(
                    value: 'pool',
                    label: Text('My collection'),
                    icon: Icon(Icons.collections_bookmark),
                  ),
                ],
                selected: {prefs.stickerSource},
                onSelectionChanged: (Set<String> newSelection) {
                  prefs.setStickerSource(newSelection.first);
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
                          'Your collection is empty! We will use the Web until you add some stickers.',
                          style: TextStyle(color: Colors.orange[800], fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 24),

              // --- FORCE REFRESH ---
              const Text(
                'Actions',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              ListTile(
                title: const Text('Refresh Today\'s Sticker'),
                subtitle: const Text('Update the widget and home screen immediately with a new sticker.'),
                leading: const Icon(Icons.refresh, color: Color(0xFF1E3A8A)),
                shape: RoundedRectangleBorder(
                  side: BorderSide(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(12),
                ),
                onTap: () async {
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => const Center(child: CircularProgressIndicator()),
                  );

                  try {
                    await context.read<ApiService>().getDailySticker(
                      prefs,
                      context.read<WidgetService>(),
                      forceRefresh: true,
                    );

                    if (mounted) {
                      Navigator.pop(context); // Close loader
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Updated successfully!')),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }
}