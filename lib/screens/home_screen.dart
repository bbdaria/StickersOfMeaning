import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/preferences_service.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import 'preferences_screen.dart';
import 'sticker_search_screen.dart';
import 'todays_sticker_screen.dart';

class HomeScreen extends StatefulWidget {
  static const String routeName = '/';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Sticker>? _futureSticker;

  @override
  void initState() {
    super.initState();
    _loadDailySticker();
  }

  void _loadDailySticker() {
    final api = context.read<ApiService>();
    final prefs = context.read<PreferencesService>();
    final widgetService = context.read<WidgetService>();

    setState(() {
      // Use the new getDailySticker method
      _futureSticker = api.getDailySticker(prefs, widgetService);
    });
  }

  Future<void> _refreshSticker() async {
    // For manual refresh, you might want to force a new random sticker?
    // Or just reload the current daily one. Let's just reload for now.
    _loadDailySticker();
  }

  Future<void> _sendToWidget(Sticker sticker) async {
    final widgetService = context.read<WidgetService>();
    await widgetService.updateStickerWidget(sticker);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Widget updated')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF001a7e), // Top gradient color
              Color(0xFF1d6caf), // Bottom gradient color
            ],
          ).createShader(bounds),
          child: const Text(
            'Stickers of Meaning',
            style: TextStyle(
              // The color must be white for the ShaderMask to apply the gradient correctly
              color: Colors.white,
              fontSize: 34, // Larger font
              fontWeight: FontWeight.w900, // Extra bold look
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, PreferencesScreen.routeName);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSticker,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Today's Sticker",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            FutureBuilder<Sticker>(
              future: _futureSticker,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading sticker: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No sticker available'),
                  );
                }

                final sticker = snapshot.data!;
                return Card(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sticker.imageUrl.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            sticker.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(
                                child: Icon(Icons.broken_image),
                              );
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          sticker.text,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ),
                      OverflowBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pushNamed(
                                context,
                                TodaysStickerScreen.routeName,
                              );
                            },
                            child: const Text('Open details'),
                          ),
                          TextButton(
                            onPressed: () => _sendToWidget(sticker),
                            child: const Text('Send to widget'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'More',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Card(
              child: ListTile(
                leading: const Icon(Icons.search),
                title: const Text('Sticker database search'),
                subtitle: const Text('Find stickers by topic and author'),
                onTap: () {
                  Navigator.pushNamed(context, StickerSearchScreen.routeName);
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text('Widget setup'),
                subtitle: const Text('Configure widget size and style'),
                onTap: () {
                  Navigator.pushNamed(context, PreferencesScreen.routeName);
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.computer),
                title: const Text('Our site'),
                subtitle: const Text('Sticker Of Meaning'),
                onTap: () {
                  launchUrl(Uri.https('stickersofmeaning.org'),);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
