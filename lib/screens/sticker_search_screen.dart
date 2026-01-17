import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stickers_of_meaning/screens/sticker_pool_screen.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_button.dart';
import 'package:html/parser.dart' show parse;
import '../services/preferences_service.dart';

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

    // 1. Show empty state if nothing selected/typed
    if (query.isEmpty && _selectedCategories.isEmpty) {
      setState(() {
        _futureResults = null;
      });
      return;
    }

    setState(() {
      final matchingIds = _searchIndex.where((item) {

        // 1. Category Logic
        // If a category is selected, the item MUST have it.
        if (_selectedCategories.isNotEmpty) {
          // Safety check: ensure categoryIds is not null (it shouldn't be with new model)
          if (item.categoryIds.isEmpty) return false;

          bool hasCategory = item.categoryIds.any((id) => _selectedCategories.contains(id));
          if (!hasCategory) return false;
        }

        // 2. Name Logic
        // If query is typed, it must match the name.
        if (query.isNotEmpty) {
          bool nameMatch =
              item.hebrewName.toLowerCase().contains(query) ||
                  item.englishName.toLowerCase().contains(query);
          if (!nameMatch) return false;
        }

        return true;
      }).map((item) => item.id).toList();

      // 3. Fetch Data
      final api = context.read<ApiService>();
      if (matchingIds.isEmpty) {
        _futureResults = Future.value([]);
      } else {
        _futureResults = api.getStickersByIds(matchingIds.take(100).toList());
      }
    });
  }

  void _showStickerDetails(Sticker sticker) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min, // Shrink to fit content
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Top Section: Image + Close Button (Stack)
            Stack(
              children: [
                // The Image
                if (sticker.imageUrl.isNotEmpty)
                  SizedBox(
                    width: double.infinity,
                    height: 200, // Fixed height for consistency
                    child: Image.network(
                      sticker.imageUrl,
                      fit: BoxFit.contain, // Contain keeps the whole image visible
                      errorBuilder: (_, __, ___) =>
                          Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                    ),
                  )
                else
                  Container(
                    height: 60,
                    color: const Color(0xFFF5F7FA),
                    child: const Center(child: Icon(Icons.sticky_note_2, size: 30, color: Colors.grey)),
                  ),

                // The "X" Close Button (Top Right)
                Positioned(
                  top: 8,
                  right: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black.withOpacity(0.4),
                    radius: 16,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ),
              ],
            ),

            // 2. Middle Section: Scrollable Text Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // Hebrew Quote
                    if (sticker.content.isNotEmpty) ...[
                      Text(
                        parse(sticker.content).body?.text ?? '',
                        style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // English Quote
                    if (sticker.enQuote.isNotEmpty && sticker.enQuote != sticker.content) ...[
                      Text(
                        parse(sticker.enQuote).body?.text ?? '',
                        style: TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey[700],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // Names
                    Text(
                      sticker.text,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A), // App Blue
                      ),
                      textAlign: TextAlign.center,
                    ),
                    if (sticker.nameInEnglish.isNotEmpty)
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
                ),
              ),
            ),

            // 3. Bottom Section: Buttons Side-by-Side
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  // A. Save to Pool Button
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.bookmark_add, size: 20),
                      label: const Text('Save to Pool'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () async {
                        await context.read<PreferencesService>().addToPool(sticker);
                        if (!mounted) return;
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Sticker saved to collection'),
                            duration: const Duration(milliseconds: 750),
                            action: SnackBarAction(
                              label: 'View',
                              onPressed: () {
                                // We must check 'mounted' again because this callback
                                // runs later, when the user clicks the button.
                                if (mounted) {
                                  Navigator.pushNamed(context, StickerPoolScreen.routeName);
                                }
                              },
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(width: 12), // Gap between buttons

                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.widgets, size: 20),
                      label: const Text('Set as Widget'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1E3A8A),
                        side: const BorderSide(color: Color(0xFF1E3A8A), width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await context.read<WidgetService>().updateStickerWidget(sticker);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Widget updated successfully!'), duration: Duration(milliseconds: 750)),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
                              // const Text("Search in:", style: TextStyle(
                              //     fontWeight: FontWeight.bold)),
                              // const SizedBox(height: 8),
                              // Row(
                              //   children: [
                              //     _buildGradientChip(
                              //         "Name (Title)", _searchInTitle, () =>
                              //         setState(() =>
                              //         _searchInTitle = !_searchInTitle)),
                              //     const SizedBox(width: 8),
                              //     _buildGradientChip("Meaning (Content)",
                              //         _searchInContent, () =>
                              //             setState(() =>
                              //             _searchInContent = !_searchInContent)),
                              //   ],
                              // ),
                              // const SizedBox(height: 16),
                              // const Text("Topics:", style: TextStyle(
                              //     fontWeight: FontWeight.bold)),
                              // const SizedBox(height: 8),
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
                  parse(sticker.heQuote).body?.text ?? '',
                  textDirection: TextDirection.rtl
              ),

              // SUBTITLE (English Name)
              subtitle: sticker.nameInHebrew.isNotEmpty
                  ? Text(sticker.nameInHebrew, textDirection: TextDirection.rtl)
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