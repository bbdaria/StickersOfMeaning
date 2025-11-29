import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sticker.dart';
import '../services/preferences_service.dart';

class StickerDetailScreen extends StatelessWidget {
  final Sticker sticker;

  const StickerDetailScreen({super.key, required this.sticker});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    final text = prefs.isHebrew ? sticker.hebrewText : sticker.englishText;
    final direction = prefs.isHebrew ? TextDirection.rtl : TextDirection.ltr;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticker-details'),
        actions: [
          if (sticker.pageUrl != null)
            IconButton(
              icon: const Icon(Icons.open_in_new),
              onPressed: () => _openOnSite(sticker.pageUrl!),
              tooltip: 'Open on website',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (sticker.imageUrl != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Center(child: Image.network(sticker.imageUrl!)),
            ),
          Text(
            text,
            textAlign: TextAlign.center,
            textDirection: direction,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (!prefs.isHebrew && sticker.hebrewText.isNotEmpty)
            Text(
              sticker.hebrewText,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          if (prefs.isHebrew && sticker.englishText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                sticker.englishText,
                textAlign: TextAlign.center,
                textDirection: TextDirection.ltr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          const SizedBox(height: 24),
          if (sticker.pageUrl != null)
            FilledButton.icon(
              onPressed: () => _openOnSite(sticker.pageUrl!),
              icon: const Icon(Icons.open_in_new),
              label: const Text('Open full-page on website'),
            ),
        ],
      ),
    );
  }

  Future<void> _openOnSite(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
