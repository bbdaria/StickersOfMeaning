import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_button.dart';

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

  List<StickerIndexItem> _searchIndex = []; // The local "Partial DB"
  bool _isIndexLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
    _loadIndexInBackground();
  }

  Future<void> _loadIndexInBackground() async {
    final api = context.read<ApiService>();
    try {
      // 1. Fetch Categories (fast)
      final cats = await api.fetchCategories();

      if (mounted) {
        setState(() {
          _availableCategories = cats;
        });
      }

      // 2. Fetch the Index (heavier, but runs in background)
      final index = await api.fetchStickerIndex();

      if (mounted) {
        setState(() {
          _searchIndex = index;
          _isIndexLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Index load error: $e');
      if (mounted) setState(() => _isIndexLoading = false);
    }
  }

  Future<void> _loadCategories() async {
    try {
      final categories = await context.read<ApiService>().fetchCategories();
      if (mounted) {
        setState(() {
          _availableCategories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  void _search() {
    final query = _controller.text.trim().toLowerCase();

    // If empty query & no categories, clear results
    if (query.isEmpty && _selectedCategories.isEmpty) {
      setState(() {
        _futureResults = null;
      });
      return;
    }

    setState(() {
      // 1. FILTER LOCALLY (The "Partial DB" check)
      // Find IDs that match the name (Hebrew or English)
      final matchingIds = _searchIndex.where((item) {
        bool matches = false;

        // Check English Name
        if (item.englishName.toLowerCase().contains(query)) matches = true;
        // Check Hebrew Name
        if (item.hebrewName.toLowerCase().contains(query)) matches = true;

        return matches;
      }).map((item) => item.id).toList();

      // 2. CALL API (The "Use API as expected" part)
      // If we found local matches, ask API for those specific IDs.
      // If we found NO local matches (maybe user searched for content/quote?),
      // we fall back to the standard API search.

      final api = context.read<ApiService>();

      if (matchingIds.isNotEmpty) {
        // Option A: We found names! Fetch these specific stickers.
        _futureResults = api.getStickersByIds(matchingIds);
        debugPrint('Found local matches!');
      } else {
        // Option B: No name match. Maybe they searched a Quote?
        // Fallback to standard server-side search.
        debugPrint('Did not find local matches...');
        _futureResults = api.searchStickers(
          query: query,
          categoryIds: _selectedCategories.toList(),
        );
      }
    });
  }

  void _showStickerDetails(Sticker sticker) {
    showDialog(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (sticker.imageUrl.isNotEmpty)
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(16)),
                      child: Image.network(
                        sticker.imageUrl,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) =>
                        const SizedBox(
                            height: 100, child: Icon(Icons.broken_image)),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        // 1. The Quote (Content) - Hebrew/Primary
                        if (sticker.content.isNotEmpty) ...[
                          Text(
                            '"${sticker.content}"',
                            style: const TextStyle(
                              fontSize: 18,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                            textDirection: TextDirection.rtl, // Hebrew support
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 2. The English Quote (New)
                        if (sticker.enQuote.isNotEmpty &&
                            sticker.enQuote != sticker.content) ...[
                          Text(
                            '"${sticker.enQuote}"',
                            style: TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey[700],
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],

                        // 3. The Name (Title)
                        Text(
                          sticker.text,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF001a7e),
                          ),
                          textAlign: TextAlign.center,
                        ),

                        // 4. The English Name (New)
                        if (sticker.nameInEnglish.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            sticker.nameInEnglish,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF3B82C4),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              // ... actions remain the same
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              GradientButton(
                icon: Icons.widgets,
                onPressed: () async {
                  // ... existing logic
                  Navigator.pop(ctx);
                  await context.read<WidgetService>().updateStickerWidget(
                      sticker);
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Widget updated successfully!')),
                  );
                },
                child: const Text('Set as Widget'),
              ),
            ],
          ),
    );
  }

  // void _showStickerDetails(Sticker sticker) {
  //   showDialog(
  //     context: context,
  //     builder: (ctx) => AlertDialog(
  //       contentPadding: EdgeInsets.zero,
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       content: SingleChildScrollView(
  //         child: Column(
  //           mainAxisSize: MainAxisSize.min,
  //           crossAxisAlignment: CrossAxisAlignment.stretch,
  //           children: [
  //             if (sticker.imageUrl.isNotEmpty)
  //               ClipRRect(
  //                 borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
  //                 child: Image.network(
  //                   sticker.imageUrl,
  //                   fit: BoxFit.contain, // Keeps the dynamic fit we added
  //                   errorBuilder: (_, __, ___) =>
  //                   const SizedBox(height: 100, child: Icon(Icons.broken_image)),
  //                 ),
  //               ),
  //             Padding(
  //               padding: const EdgeInsets.all(20),
  //               child: Column(
  //                 children: [
  //                   // 1. The Quote (Content)
  //                   if (sticker.content.isNotEmpty) ...[
  //                     Text(
  //                       '"${sticker.content}"', // Added quotes for styling
  //                       style: const TextStyle(
  //                         fontSize: 18,
  //                         fontStyle: FontStyle.italic, // Italic for quotes
  //                         color: Colors.black87,
  //                       ),
  //                       textAlign: TextAlign.center,
  //                     ),
  //                     const SizedBox(height: 12),
  //                   ],
  //
  //                   // 2. The Name (Title)
  //                   Text(
  //                     sticker.text,
  //                     style: const TextStyle(
  //                       fontSize: 16,
  //                       fontWeight: FontWeight.bold, // Bold for the name
  //                       color: Color(0xFF001a7e),    // Brand blue color
  //                     ),
  //                     textAlign: TextAlign.center,
  //                   ),
  //                 ],
  //               ),
  //             ),
  //           ],
  //         ),
  //       ),
  //       actionsAlignment: MainAxisAlignment.center,
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(ctx),
  //           child: const Text('Cancel'),
  //         ),
  //         GradientButton(
  //           icon: Icons.widgets,
  //           onPressed: () async {
  //             Navigator.pop(ctx);
  //             await context.read<WidgetService>().updateStickerWidget(sticker);
  //             if (!mounted) return;
  //             ScaffoldMessenger.of(context).showSnackBar(
  //               const SnackBar(content: Text('Widget updated successfully!')),
  //             );
  //           },
  //           child: const Text('Set as Widget'),
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Helper for Gradient Chips
  Widget _buildGradientChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: isSelected
              ? const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1E3A8A), Color(0xFF3B82C4)],
          )
              : null,
          color: isSelected ? null : Colors.grey[200],
          boxShadow: isSelected
              ? [
            BoxShadow(color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ]
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
                        child: TextField(
                          controller: _controller,
                          textInputAction: TextInputAction.search,
                          onSubmitted: (_) => _search(),
                          decoration: InputDecoration(
                            labelText: 'Search...',
                            hintText: 'Type to search...',
                            hintStyle: const TextStyle(
                                color: Color(0xFF8A8A8A)),
                            prefixIcon: const Icon(
                                Icons.search, color: Color(0xFF0B2A6F)),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 16),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFF0B2A6F)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFF0B2A6F), width: 2),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                  color: Color(0xFF0B2A6F)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
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
                          icon: const Icon(Icons.arrow_forward, color: Colors
                              .white),
                          onPressed: _search,
                        ),
                      ),
                    ],
                  ),
                ),

                ExpansionTile(
                  title: const Text("Filters (Topics & Options)"),
                  children: [
                    // --- FIX IS APPLIED HERE ---
                    ConstrainedBox(
                      // Limit the height of the expanded area to 300 pixels
                      // This prevents it from taking up the entire screen and overflowing
                      constraints: const BoxConstraints(maxHeight: 300),
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text("Search in:", style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  _buildGradientChip(
                                      "Name (Title)", _searchInTitle, () =>
                                      setState(() =>
                                      _searchInTitle = !_searchInTitle)),
                                  const SizedBox(width: 8),
                                  _buildGradientChip("Meaning (Content)",
                                      _searchInContent, () =>
                                          setState(() =>
                                          _searchInContent = !_searchInContent)),
                                ],
                              ),
                              const SizedBox(height: 16),
                              const Text("Topics:", style: TextStyle(
                                  fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              _availableCategories.isEmpty
                                  ? const Text("Loading topics...")
                                  : Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: _availableCategories.entries.map((
                                    entry) {
                                  final isSelected = _selectedCategories
                                      .contains(entry.key);
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
    if (_futureResults == null) {
      return const Center(child: Text(''));
    }

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
          return const Center(
              child: Text('No stickers found matching your filters.'));
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
                  errorBuilder: (_, __, ___) => const Icon(Icons.image),
                ),
              )
                  : const Icon(Icons.sticky_note_2),

              // PRIMARY TITLE (Hebrew)
              title: Text(
                  sticker.text,
                  textDirection: TextDirection.rtl
              ),

              // SUBTITLE (English Name)
              subtitle: sticker.nameInEnglish.isNotEmpty
                  ? Text(sticker.nameInEnglish)
                  : null,

              onTap: () {
                _showStickerDetails(sticker);
              },
            );
          },
        );
      },
    );
  }
}