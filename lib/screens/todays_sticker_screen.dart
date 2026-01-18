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

  Future<void> _openSite(String url) async {
    final prefs = context.read<PreferencesService>();
    if (url.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prefs.getLabel('no_link_available')), duration: const Duration(milliseconds: 750)),
      );
      return;
    }

    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(prefs.getLabel('could_not_open_site'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      // --- FIX: Force LTR on AppBar ---
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            title: Text(prefs.getLabel('todays_sticker')),
          ),
        ),
      ),
      // --------------------------------
      body: FutureBuilder<Sticker>(
        future: _futureSticker,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                '${prefs.getLabel('error_loading')}: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            );
          } else if (!snapshot.hasData) {
            return Center(child: Text(prefs.getLabel('no_sticker_available')));
          }

          final sticker = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (sticker.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    sticker.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.fitWidth,
                    errorBuilder: (context, error, stackTrace) =>
                    const SizedBox(
                      height: 200,
                      child: Center(child: Icon(Icons.broken_image, size: 64)),
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

              ElevatedButton.icon(
                onPressed: () => _openSite(sticker.postUrl),
                icon: const Icon(Icons.open_in_new),
                label: Text(prefs.getLabel('open_full_post')),
              ),
            ],
          );
        },
      ),
    );
  }
}