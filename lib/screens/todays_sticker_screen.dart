import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';

class TodaysStickerScreen extends StatefulWidget {
  static const String routeName = '/todays_sticker';

  const TodaysStickerScreen({super.key});

  @override
  State<TodaysStickerScreen> createState() => _TodaysStickerScreenState();
}

class _TodaysStickerScreenState extends State<TodaysStickerScreen> {
  late Future<Sticker> _futureSticker;

  @override
  void initState() {
    super.initState();
    final api = context.read<ApiService>();
    final prefs = context.read<PreferencesService>();
    final widgetService = context.read<WidgetService>();

    _futureSticker = api.getDailySticker(prefs, widgetService);
  }

  // UPDATED: Now accepts the specific URL to open
  Future<void> _openSite(String url) async {
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No link available for this sticker')),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open site')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Today's Sticker"),
      ),
      body: FutureBuilder<Sticker>(
        future: _futureSticker,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Error loading today\'s sticker: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData) {
            return const Center(child: Text('No sticker available'));
          }

          final sticker = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sticker.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: Image.network(
                      sticker.imageUrl,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) =>
                      const Icon(Icons.broken_image, size: 64),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                sticker.text,
                style:
                const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 24),

              // UPDATED BUTTON
              ElevatedButton.icon(
                // Pass the sticker's specific URL to the function
                onPressed: () => _openSite(sticker.postUrl),
                icon: const Icon(Icons.open_in_new),
                label: const Text('Open full post on site'),
              ),
            ],
          );
        },
      ),
    );
  }
}