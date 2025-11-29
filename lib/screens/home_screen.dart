import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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
    final api = context.read<ApiService>();
    _futureSticker = api.fetchTodaysSticker();
  }

  Future<void> _refreshSticker() async {
    final api = context.read<ApiService>();
    setState(() {
      _futureSticker = api.fetchTodaysSticker();
    });
  }

  Future<void> _sendToWidget(Sticker sticker) async {
    final widgetService = context.read<WidgetService>();
    await widgetService.updateStickerWidget(sticker);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Widget updated')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stickers of meaning'),
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
              'Todays sticker',
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
                      ButtonBar(
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
                subtitle: const Text('Find stickers by mood topic author'),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    StickerSearchScreen.routeName,
                  );
                },
              ),
            ),
            Card(
              child: ListTile(
                leading: const Icon(Icons.widgets),
                title: const Text('Widget setup'),
                subtitle: const Text('Configure widget size and style'),
                onTap: () {
                  Navigator.pushNamed(
                    context,
                    PreferencesScreen.routeName,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
