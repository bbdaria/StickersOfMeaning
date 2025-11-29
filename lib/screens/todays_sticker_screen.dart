import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import 'sticker_detail_screen.dart';

class TodaysStickerScreen extends StatefulWidget {
  static const String routeName = '/todays_sticker';

  const TodaysStickerScreen({super.key});

  @override
  State<TodaysStickerScreen> createState() => _TodaysStickerScreenState();
}

class _TodaysStickerScreenState extends State<TodaysStickerScreen> {
  Sticker? _sticker;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadSticker();
  }

  Future<void> _loadSticker() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PreferencesService>();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final sticker = await api.fetchTodaysSticker(
        categoryFilter: prefs.selectedCategoryIds.isEmpty
            ? null
            : prefs.selectedCategoryIds.toList(),
      );
      setState(() {
        _sticker = sticker;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _openOnSite() async {
    if (_sticker?.pageUrl == null) return;
    final uri = Uri.parse(_sticker!.pageUrl!);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  void _openInsideApp() {
    final sticker = _sticker;
    if (sticker == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => StickerDetailScreen(sticker: sticker)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Todays-sticker'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isLoading ? null : _loadSticker,
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: _isLoading
              ? const CircularProgressIndicator()
              : _error != null
              ? Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                )
              : _sticker == null
              ? const Text('No sticker returned from the server')
              : _buildContent(prefs),
        ),
      ),
    );
  }

  Widget _buildContent(PreferencesService prefs) {
    final sticker = _sticker!;
    final text = prefs.isHebrew ? sticker.hebrewText : sticker.englishText;
    final direction = prefs.isHebrew ? TextDirection.rtl : TextDirection.ltr;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (sticker.imageUrl != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Image.network(sticker.imageUrl!),
          ),
        Text(
          text,
          textAlign: TextAlign.center,
          textDirection: direction,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 16),
        if (sticker.date != null)
          Text(
            'Date:${sticker.date}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _openInsideApp,
          icon: const Icon(Icons.sticky_note_2_outlined),
          label: const Text('Open in app'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _openOnSite,
          icon: const Icon(Icons.open_in_new),
          label: const Text('Open on website'),
        ),
      ],
    );
  }
}
