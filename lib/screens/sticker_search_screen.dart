import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';

class StickerSearchScreen extends StatefulWidget {
  static const String routeName = '/sticker_search';

  const StickerSearchScreen({super.key});

  @override
  State<StickerSearchScreen> createState() => _StickerSearchScreenState();
}

class _StickerSearchScreenState extends State<StickerSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<List<Sticker>>? _futureResults;
  String _lastQuery = '';

  void _search() {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    final api = context.read<ApiService>();
    setState(() {
      _lastQuery = query;
      _futureResults = api.searchStickers(query);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildResults() {
    if (_futureResults == null) {
      return const Center(
        child: Text('Start by searching for a sticker.'),
      );
    }

    return FutureBuilder<List<Sticker>>(
      future: _futureResults,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Error searching stickers: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }

        final results = snapshot.data ?? [];

        if (results.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('No results for "$_lastQuery".'),
          );
        }

        return ListView.separated(
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sticker = results[index];
            return ListTile(
              leading: sticker.imageUrl.isNotEmpty
                  ? Image.network(
                sticker.imageUrl,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                const Icon(Icons.broken_image),
              )
                  : const Icon(Icons.sticky_note_2_outlined),
              title: Text(sticker.text, maxLines: 2, overflow: TextOverflow.ellipsis),
              onTap: () {
                // Later you can push a sticker details page
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sticker database search'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: const InputDecoration(
                      labelText: 'Search',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(child: _buildResults()),
        ],
      ),
    );
  }
}
