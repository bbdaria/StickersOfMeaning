import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/preferences_service.dart';
import 'sticker_detail_screen.dart';

class StickerSearchScreen extends StatefulWidget {
  static const String routeName = '/sticker_search';

  const StickerSearchScreen({super.key});

  @override
  State<StickerSearchScreen> createState() => _StickerSearchScreenState();
}

class _StickerSearchScreenState extends State<StickerSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  bool _isSearching = false;
  List<Sticker> _results = [];
  String? _error;

  Future<void> _search() async {
    final api = context.read<ApiService>();
    final prefs = context.read<PreferencesService>();

    final query = _controller.text.trim();
    if (query.isEmpty) {
      setState(() {
        _results = [];
        _error = null;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _error = null;
    });

    try {
      final stickers = await api.searchStickers(
        textQuery: query,
        categoryIds: prefs.selectedCategoryIds.isEmpty
            ? null
            : prefs.selectedCategoryIds.toList(),
      );
      setState(() {
        _results = stickers;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  void _openSticker(Sticker sticker) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StickerDetailScreen(sticker: sticker),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildBody() {
    final prefs = context.watch<PreferencesService>();

    if (_isSearching) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          _error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: Text('No stickers yet,try searching'),
      );
    }

    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final sticker = _results[index];
        final text = prefs.isHebrew ? sticker.hebrewText : sticker.englishText;
        final direction =
            prefs.isHebrew ? TextDirection.rtl : TextDirection.ltr;

        return ListTile(
          title: Text(
            text,
            textDirection: direction,
          ),
          subtitle: sticker.pageUrl != null ? Text(sticker.pageUrl!) : null,
          onTap: () => _openSticker(sticker),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search-stickers'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      labelText: 'Search-text',
                    ),
                  ),
                ),
                IconButton(
                  icon: _isSearching
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.search),
                  onPressed: _isSearching ? null : _search,
                  tooltip:
                      'Search in ${prefs.selectedCategoryIds.isEmpty ? 'all-categories' : 'selected-categories'}',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }
}
