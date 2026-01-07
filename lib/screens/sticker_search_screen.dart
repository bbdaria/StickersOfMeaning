import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/gradient_button.dart';
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
    // If BOTH are empty, we clear the results.
    if (query.isEmpty && _selectedCategories.isEmpty) {
      setState(() {
        _futureResults = null;
      });
      return;
    }

    // --- SMART FILTER LOGIC ---
    List<String>? searchColumns;

    // Only apply limits if the user explicitly UNCHECKED something.
    // If both are true (default), we leave searchColumns as null.
    // This lets WordPress use its default powerful search.
    if (_searchInTitle && !_searchInContent) {
      searchColumns = ['post_title']; // Search ONLY Title
    } else if (!_searchInTitle && _searchInContent) {
      searchColumns = ['post_content', 'post_excerpt']; // Search ONLY Content
    }
    // If both are true: searchColumns remains null -> Searches Everything.
    // If both are false: searchColumns remains null -> Searches Everything.

    final api = context.read<ApiService>();
    setState(() {
      _futureResults = api.searchStickers(
        query: query,
        categoryIds: _selectedCategories.toList(),
        searchIn: searchColumns, // Pass null to search everywhere
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

  Widget _buildGradientChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30), // Pill shape
          gradient: isSelected
              ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82C4)], // Button Gradient
          )
              : null,
          color: isSelected ? null : Colors.grey[200], // Grey if not selected
          boxShadow: isSelected
              ? [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
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
                        // SEARCH BAR with Navy Outline Style
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            labelText: 'Search...',
                            hintText: 'Type to search...',
                            hintStyle: const TextStyle(color: Color(0xFF8A8A8A)),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF0B2A6F)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF0B2A6F), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(color: Color(0xFF0B2A6F)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Forward button can also be gradient if you like
                      Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0xFF1E3A8A), Color(0xFF3B82C4)],
                          ),
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.arrow_forward, color: Colors.white),
                          onPressed: _search,
                        ),
                      ),
                    ],
                  ),
                ),

                // FILTERS
                ExpansionTile(
                  title: const Text("Filters (Topics & Options)"),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text("Search in:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _buildGradientChip("Name (Title)", _searchInTitle, () => setState(() => _searchInTitle = !_searchInTitle)),
                              const SizedBox(width: 8),
                              _buildGradientChip("Meaning (Content)", _searchInContent, () => setState(() => _searchInContent = !_searchInContent)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const Text("Topics:", style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          _availableCategories.isEmpty
                              ? const Text("Loading topics...")
                              : Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: _availableCategories.entries.map((entry) {
                              final isSelected = _selectedCategories.contains(entry.key);
                              return _buildGradientChip(
                                entry.value,
                                isSelected,
                                    () {
                                  setState(() {
                                    if (isSelected) {
                                      _selectedCategories.remove(entry.key);
                                    } else {
                                      _selectedCategories.add(entry.key);
                                    }
                                    _search();
                                  });
                                },
                              );
                            }).toList(),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(child: _buildResults()),
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