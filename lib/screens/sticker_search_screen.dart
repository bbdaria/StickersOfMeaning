import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';

class StickerSearchScreen extends StatefulWidget {
  static const String routeName = '/sticker_search';

  const StickerSearchScreen({super.key});

  @override
  State<StickerSearchScreen> createState() => _StickerSearchScreenState();
}

class _StickerSearchScreenState extends State<StickerSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Future<List<Sticker>>? _futureResults;

  Map<int, String> _availableCategories = {};
  final Set<int> _selectedCategories = {};

  bool _searchInTitle = true;
  bool _searchInContent = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiService>().fetchCategories();
      setState(() {
        _availableCategories = categories;
      });
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _search() {
    final query = _controller.text.trim();

    // UPDATED: Allow search if Query has text OR Categories are selected
    if (query.isEmpty && _selectedCategories.isEmpty) {
      // Optional: clear results if everything is empty
      setState(() {
        _futureResults = null;
      });
      return;
    }

    List<String> searchColumns = [];
    if (_searchInTitle) searchColumns.add('post_title');
    if (_searchInContent) {
      searchColumns.add('post_content');
      searchColumns.add('post_excerpt');
    }
    if (searchColumns.isEmpty) searchColumns = ['post_title', 'post_content', 'post_excerpt'];

    final api = context.read<ApiService>();
    setState(() {
      _futureResults = api.searchStickers(
        query: query,
        categoryIds: _selectedCategories.toList(),
        searchIn: searchColumns,
      );
    });
  }

  // ... (keep _showStickerDetails exactly as it was) ...
  void _showStickerDetails(Sticker sticker) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        contentPadding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (sticker.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.network(
                  sticker.imageUrl,
                  height: 200,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) =>
                  const SizedBox(height: 100, child: Icon(Icons.broken_image)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(
                sticker.text,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<WidgetService>().updateStickerWidget(sticker);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Widget updated successfully!')),
              );
            },
            icon: const Icon(Icons.widgets),
            label: const Text('Set as Widget'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sticker Search')),
      body: Column(
        children: [
          Material(
            elevation: 2,
            child: Column(
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
                            labelText: 'Search...',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.search),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: _search,
                      ),
                    ],
                  ),
                ),

                ExpansionTile(
                  title: const Text("Filters (Topics & Options)"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Search in:", style: TextStyle(fontWeight: FontWeight.bold)),
                          Row(
                            children: [
                              FilterChip(
                                label: const Text("Name (Title)"),
                                selected: _searchInTitle,
                                onSelected: (v) => setState(() => _searchInTitle = v),
                              ),
                              const SizedBox(width: 8),
                              FilterChip(
                                label: const Text("Meaning (Content)"),
                                selected: _searchInContent,
                                onSelected: (v) => setState(() => _searchInContent = v),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text("Topics:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          _availableCategories.isEmpty
                              ? const Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Text("Loading topics..."),
                          )
                              : Wrap(
                            spacing: 8,
                            children: _availableCategories.entries.map((entry) {
                              final isSelected = _selectedCategories.contains(entry.key);
                              return FilterChip(
                                label: Text(entry.value),
                                selected: isSelected,
                                onSelected: (selected) {
                                  setState(() {
                                    if (selected) {
                                      _selectedCategories.add(entry.key);
                                    } else {
                                      _selectedCategories.remove(entry.key);
                                    }
                                    // UPDATED: Trigger search immediately when topic changes
                                    _search();
                                  });
                                },
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _buildResults(),
          ),
        ],
      ),
    );
  }

  Widget _buildResults() {
    // If user hasn't searched yet, show instruction
    if (_futureResults == null) {
      return const Center(child: Text('Select a topic or type a search term.'));
    }

    // ... (keep the rest of _buildResults exactly as it was) ...
    return FutureBuilder<List<Sticker>>(
      future: _futureResults,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        }

        final results = snapshot.data ?? [];
        if (results.isEmpty) {
          return const Center(child: Text('No stickers found matching your filters.'));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(8),
          itemCount: results.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (context, index) {
            final sticker = results[index];
            return ListTile(
              leading: sticker.imageUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Image.network(
                  sticker.imageUrl,
                  width: 50, height: 50, fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => const Icon(Icons.image),
                ),
              )
                  : const Icon(Icons.sticky_note_2),
              title: Text(sticker.text),
              onTap: () => _showStickerDetails(sticker),
            );
          },
        );
      },
    );
  }
}