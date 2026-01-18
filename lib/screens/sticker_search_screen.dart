import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stickers_of_meaning/screens/sticker_pool_screen.dart';

import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_button.dart';
import 'package:html/parser.dart' show parse;
import '../services/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';

class StickerSearchScreen extends StatefulWidget {
  static const String routeName = '/sticker_search';

  const StickerSearchScreen({super.key});

  @override
  State<StickerSearchScreen> createState() => _StickerSearchScreenState();
}

class _StickerSearchScreenState extends State<StickerSearchScreen> {
  // -- UI Controllers --
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  // -- Data Source (The "Index") --
  List<StickerIndexItem> _searchIndex = [];
  Map<int, String> _availableCategories = {};
  bool _isIndexLoading = true;

  // -- Filter State --
  final Set<int> _selectedCategories = {};

  // -- Results State --
  List<int> _filteredIds = []; // All potential matches (just IDs)
  List<Sticker> _displayedStickers = []; // Full stickers loaded so far
  bool _isLoadingMore = false;
  bool _hasSearched = false; // To distinguish "start" vs "no results"

  @override
  void initState() {
    super.initState();
    _loadIndexInBackground();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    // If scrolled to bottom (threshold 200px), load more
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadMoreStickers();
    }
  }

  Future<void> _loadIndexInBackground() async {
    final api = context.read<ApiService>();
    try {
      // 1. Fetch Categories
      final cats = await api.fetchCategories();
      if (mounted) setState(() => _availableCategories = cats);

      // 2. Fetch Index with Incremental Updates
      await api.fetchStickerIndex(
        onBatchLoaded: (newBatch) {
          if (!mounted) return;
          setState(() {
            _searchIndex.addAll(newBatch);

            // If the user already has a filter active, update results live
            if (_controller.text.isNotEmpty || _selectedCategories.isNotEmpty) {
              _applyFilter();
            }
          });
        },
      );
      if (mounted) setState(() => _isIndexLoading = false);
    } catch (e) {
      debugPrint('Index load error: $e');
      if (mounted) setState(() => _isIndexLoading = false);
    }
  }

  // --- CORE LOGIC: Filter Index -> Get IDs ---
  void _applyFilter() {
    final query = _controller.text.trim().toLowerCase();

    // 1. Reset if empty
    if (query.isEmpty && _selectedCategories.isEmpty) {
      setState(() {
        _filteredIds = [];
        _displayedStickers = [];
        _hasSearched = false;
      });
      return;
    }

    setState(() {
      _hasSearched = true;

      // 2. Find matching IDs from local index
      _filteredIds = _searchIndex.where((item) {
        // Category Match
        if (_selectedCategories.isNotEmpty) {
          if (item.categoryIds.isEmpty) return false;
          bool hasCategory = item.categoryIds.any((id) => _selectedCategories.contains(id));
          if (!hasCategory) return false;
        }

        // Text Match
        if (query.isNotEmpty) {
          bool nameMatch =
              item.hebrewName.toLowerCase().contains(query) ||
                  item.englishName.toLowerCase().contains(query);
          if (!nameMatch) return false;
        }
        return true;
      }).map((item) => item.id).toList();
    });

    // 3. Reset displayed list and load first batch
    // IMPORTANT: Only clear if we are starting a fresh search logic,
    // but here we simply re-fetch to ensure consistency.
    _displayedStickers.clear();

    if (_filteredIds.isNotEmpty) {
      _loadMoreStickers();
    } else {
      // Safety Net: Fallback to Server if local index found nothing
      _fetchServerFallback();
    }
  }

  // --- BATCH LOADER ---
  Future<void> _loadMoreStickers() async {
    if (_isLoadingMore) return;
    // Stop if we have displayed everything
    if (_displayedStickers.length >= _filteredIds.length) return;

    setState(() => _isLoadingMore = true);

    try {
      final api = context.read<ApiService>();

      // Calculate next batch
      final startIndex = _displayedStickers.length;
      final count = 20; // Load 20 at a time
      final idsToLoad = _filteredIds.skip(startIndex).take(count).toList();

      if (idsToLoad.isNotEmpty) {
        final newStickers = await api.getStickersByIds(idsToLoad);
        if (mounted) {
          setState(() {
            _displayedStickers.addAll(newStickers);
          });
        }
      }
    } catch (e) {
      debugPrint("Error loading more stickers: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  // --- FALLBACK: Direct API Search ---
  Future<void> _fetchServerFallback() async {
    setState(() => _isLoadingMore = true);
    try {
      final api = context.read<ApiService>();
      final results = await api.searchStickers(
        query: _controller.text.trim(),
        categoryIds: _selectedCategories.toList(),
      );
      if (mounted) {
        setState(() {
          _displayedStickers = results;
          // We can't really pagination easily here without complex state,
          // so we just show the first page from server.
        });
      }
    } catch (e) {
      debugPrint("Server fallback error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  Future<void> _openExternalUrl(BuildContext context, url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open site')),
        );
      }
    }
  }

  void _showStickerDetails(Sticker sticker) {
    // 1. Get current language preference
    final language = context.read<PreferencesService>().language;
    final isEnglish = language == 'en';

    // 2. Prepare Data based on Language
    // We use fallbacks so the dialog isn't empty if a translation is missing
    String displayQuote = isEnglish
        ? (sticker.enQuote.isNotEmpty ? sticker.enQuote : sticker.content)
        : sticker.content;

    String displayName = isEnglish
        ? (sticker.nameInEnglish.isNotEmpty ? sticker.nameInEnglish : sticker.text)
        : sticker.text;

    // Clean HTML tags from the quote just in case
    displayQuote = parse(displayQuote).body?.text ?? displayQuote;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white, // FIX: Force white background
        surfaceTintColor: Colors.white, // FIX: Remove M3 purple tint
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [

            Stack(
              children: [
                // 1. BACKGROUND LAYER: Image
                if (sticker.imageUrl.isNotEmpty)
                  Padding(
                    // CHANGED: Increased padding to 50.0 so it doesn't touch buttons
                    padding: const EdgeInsets.only(top: 50.0),
                    child: SizedBox(
                      width: double.infinity,
                      height: 200,
                      child: Image.network(
                        sticker.imageUrl,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.white, child: const Icon(Icons.broken_image)),
                      ),
                    ),
                  )
                else
                  Container(
                    height: 60,
                    // CHANGED: Increased margin here too for consistency
                    margin: const EdgeInsets.only(top: 50.0),
                    color: const Color(0xFFFFFFFF),
                    child: const Center(child: Icon(Icons.sticky_note_2, size: 30, color: Colors.white)),
                  ),

                // 2. FOREGROUND LAYER: AppBar with buttons
                if (sticker.postUrl.isNotEmpty)
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    // CHANGED: Added padding around the button
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.info_outline, size: 25, color: Colors.black87),
                        tooltip: 'Visit Site',
                        onPressed: () => _openExternalUrl(context, sticker.postUrl),
                      ),
                    ),
                    actions: [
                      // CHANGED: Added padding around the button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 25, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      )
                    ],
                  )
                else
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    automaticallyImplyLeading: false,
                    actions: [
                      // CHANGED: Added padding around the button
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: IconButton(
                          icon: const Icon(Icons.close, size: 25, color: Colors.black87),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      )
                    ],
                  ),
              ],
            ),
            // --- Text Section (Dynamic Language) ---
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    // 1. The Quote
                    if (displayQuote.isNotEmpty) ...[
                      Text(
                        '"$displayQuote"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        // RTL for Hebrew, LTR for English
                        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                      ),
                      const SizedBox(height: 12),
                    ],

                    // 2. The Name
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A8A),
                      ),
                      textAlign: TextAlign.center,
                      textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
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
                      icon: const Icon(Icons.bookmark_border, size: 20),
                      label: const Text('Add to Collection'),
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
                            duration: const Duration(seconds: 750),
                            action: SnackBarAction(
                              label: 'View',
                              onPressed: () => Navigator.pushNamed(context, StickerPoolScreen.routeName),
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
                          onChanged: (_) => _applyFilter(),
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
                          onPressed: _applyFilter,
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
                                        _applyFilter();
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
    final prefs = Provider.of<PreferencesService>(context);
    final isEnglish = prefs.language == 'en';

    if (!_hasSearched) {
      return const Center(child: Text('Type or select a category to start searching.'));
    }

    if (_displayedStickers.isEmpty) {
      if (_isLoadingMore) return const Center(child: CircularProgressIndicator());
      return const Center(child: Text('No stickers found.'));
    }

    return ListView.separated(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      itemCount: _displayedStickers.length + (_isLoadingMore ? 1 : 0),
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (context, index) {
        if (index == _displayedStickers.length) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(8.0),
            child: CircularProgressIndicator(),
          ));
        }

        final sticker = _displayedStickers[index];
        String displayName;

        if (isEnglish && sticker.nameInEnglish.isNotEmpty) {
          displayName = sticker.nameInEnglish;
        } else if (!isEnglish && sticker.nameInHebrew.isNotEmpty) {
          displayName = sticker.nameInHebrew;
        } else {
          // Fallback to the default "text" (Usually Hebrew Title)
          displayName = sticker.text;
        }

        // 3. Determine Display Quote (Subtitle)
        String displayQuote;
        if (isEnglish && sticker.enQuote.isNotEmpty) {
          displayQuote = sticker.enQuote;
        } else if (!isEnglish && sticker.heQuote.isNotEmpty) {
          displayQuote = sticker.heQuote;
        } else {
          // Fallback to the default "content" (Usually Hebrew Quote)
          displayQuote = sticker.content;
        }

        return ListTile(
          leading: sticker.imageUrl.isNotEmpty
              ? ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              sticker.imageUrl,
              width: 50, height: 50, fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Icon(Icons.image),
            ),
          )
              : const Icon(Icons.sticky_note_2),

          // PRIMARY TITLE (Hebrew)
          title: Text(
            displayName,
            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),

          // SUBTITLE (English Name)
          subtitle: Text(
              parse(displayQuote).body?.text ?? '',
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              maxLines: 2,
              overflow: TextOverflow.ellipsis
          ),
          onTap: () {
            _showStickerDetails(sticker);
          },
        );
      },
    );
  }
}