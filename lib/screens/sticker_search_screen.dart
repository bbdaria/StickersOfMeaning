import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';
import 'package:html/parser.dart' show parse;
import '../services/preferences_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/set_as_widget_button.dart';

class StickerSearchScreen extends StatefulWidget {
  static const String routeName = '/sticker_search';

  const StickerSearchScreen({super.key});

  @override
  State<StickerSearchScreen> createState() => _StickerSearchScreenState();
}

class _StickerSearchScreenState extends State<StickerSearchScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<StickerIndexItem> _searchIndex = [];
  Map<int, String> _availableCategories = {};
  bool _isIndexLoading = true;

  final Set<int> _selectedCategories = {};

  List<int> _filteredIds = [];
  List<Sticker> _displayedStickers = [];
  bool _isLoadingMore = false;
  bool _hasSearched = false;

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
    if (_scrollController.hasClients &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _loadMoreStickers();
    }
  }

  Future<void> _loadIndexInBackground() async {
    final api = context.read<ApiService>();
    try {
      final cats = await api.fetchCategories();
      if (mounted) setState(() => _availableCategories = cats);

      await api.fetchStickerIndex(
        onBatchLoaded: (newBatch) {
          if (!mounted) return;

          setState(() {
            _searchIndex.addAll(newBatch);
          });

          if (_controller.text.isNotEmpty || _selectedCategories.isNotEmpty) {
            _applyFilter(refreshExisting: false);
          }
        },
      );
      if (mounted) setState(() => _isIndexLoading = false);
    } catch (e) {
      debugPrint('Index load error: $e');
      if (mounted) setState(() => _isIndexLoading = false);
    }
  }

  void _applyFilter({bool refreshExisting = true}) {
    final query = _controller.text.trim().toLowerCase();

    if (query.isEmpty && _selectedCategories.isEmpty) {
      setState(() {
        _filteredIds = [];
        _displayedStickers = [];
        _hasSearched = false;
      });
      return;
    }

    final newFilteredIds = _searchIndex.where((item) {
      if (_selectedCategories.isNotEmpty) {
        if (item.categoryIds.isEmpty) return false;
        bool hasCategory = item.categoryIds.any((id) => _selectedCategories.contains(id));
        if (!hasCategory) return false;
      }

      if (query.isNotEmpty) {
        bool nameMatch =
            item.hebrewName.toLowerCase().contains(query) ||
                item.englishName.toLowerCase().contains(query);
        if (!nameMatch) return false;
      }
      return true;
    }).map((item) => item.id).toList();

    setState(() {
      _hasSearched = true;
      _filteredIds = newFilteredIds;
    });

    if (refreshExisting) {
      _displayedStickers.clear();
      if (_filteredIds.isNotEmpty) {
        _loadMoreStickers();
      } else {
        _fetchServerFallback();
      }
    } else {
      if (_displayedStickers.isEmpty && _filteredIds.isNotEmpty) {
        _loadMoreStickers();
      }
      else if (_displayedStickers.length < 20 && _filteredIds.length > _displayedStickers.length) {
        _loadMoreStickers();
      }
    }
  }

  Future<void> _loadMoreStickers() async {
    if (_isLoadingMore) return;
    if (_displayedStickers.length >= _filteredIds.length) return;

    setState(() => _isLoadingMore = true);

    try {
      final api = context.read<ApiService>();
      final startIndex = _displayedStickers.length;
      final count = 20;
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

  Future<void> _openExternalUrl(BuildContext context, url) async {
    final prefs = context.read<PreferencesService>();
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(prefs.getLabel('could_not_open_site'))),
        );
      }
    }
  }

  Future<void> _fetchServerFallback() async {
    if (_isIndexLoading) return;

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
        });
      }
    } catch (e) {
      debugPrint("Server fallback error: $e");
    } finally {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _showStickerDetails(Sticker sticker) {
    final prefs = context.read<PreferencesService>();
    final language = prefs.language;
    final isEnglish = language == 'en';

    String displayQuote = isEnglish
        ? (sticker.enQuote.isNotEmpty ? sticker.enQuote : sticker.content)
        : sticker.content;

    String displayName = isEnglish
        ? (sticker.nameInEnglish.isNotEmpty ? sticker.nameInEnglish : sticker.text)
        : sticker.text;

    displayQuote = parse(displayQuote).body?.text ?? displayQuote;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              children: [
                if (sticker.imageUrl.isNotEmpty)
                  Padding(
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
                    margin: const EdgeInsets.only(top: 50.0),
                    color: const Color(0xFFFFFFFF),
                    child: const Center(child: Icon(Icons.sticky_note_2, size: 30, color: Colors.white)),
                  ),
                if (sticker.postUrl.isNotEmpty)
                  AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    leading: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: IconButton(
                        icon: const Icon(Icons.info_outline, size: 25, color: Colors.black87),
                        tooltip: 'Visit Site',
                        onPressed: () => _openExternalUrl(context, sticker.postUrl),
                      ),
                    ),
                    actions: [
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
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    if (displayQuote.isNotEmpty) ...[
                      Text(
                        '"$displayQuote"',
                        style: const TextStyle(
                          fontSize: 18,
                          fontStyle: FontStyle.italic,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                      ),
                      const SizedBox(height: 12),
                    ],
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

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: Consumer<PreferencesService>(
                          builder: (context, prefs, _) {
                            final isSaved = prefs.isStickerInPool(sticker.id);
                            return OutlinedButton.icon(
                              icon: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  size: 20
                              ),
                              label: Text(
                                isSaved ? prefs.getLabel('already_in_collection') : prefs.getLabel('add_to_collection'),
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFF1E3A8A),
                                side: const BorderSide(color: Color(0xFF1E3A8A), width: 1.5),
                                padding: EdgeInsets.zero,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              onPressed: () async {
                                if (isSaved) {
                                  await context.read<ApiService>().safeRemoveFromPool(context, sticker.id);
                                } else {
                                  await prefs.addToPool(sticker);
                                }
                              },
                            );
                          }
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),
                  Expanded(
                    child: StickerWidgetButton(sticker: sticker),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

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
    final prefs = context.watch<PreferencesService>();
    final isEnglish = prefs.language == 'en';

    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(title: Text(prefs.getLabel('sticker_search'))),
        ),
      ),
      // CHANGED: Used CustomScrollView to allow header to scroll with keyboard open
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: Material(
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
                            textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                            onChanged: (_) => _applyFilter(refreshExisting: true),
                            decoration: InputDecoration(
                              labelText: prefs.getLabel('search_hint'),
                              hintText: prefs.getLabel('type_to_search'),
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
                            onPressed: () => _applyFilter(refreshExisting: true),
                          ),
                        ),
                      ],
                    ),
                  ),

                  ExpansionTile(
                    title: Text(prefs.getLabel('filters')),
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 300),
                        child: SingleChildScrollView(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _availableCategories.isEmpty
                                    ? Text(prefs.getLabel('loading_topics'))
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
                                          _applyFilter(refreshExisting: true);
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
          ),

          // CHANGED: Use a sliver builder instead of expanded widget
          _buildResultsSliver(),
        ],
      ),
    );
  }

  Widget _buildResultsSliver() {
    final prefs = Provider.of<PreferencesService>(context);
    final isEnglish = prefs.language == 'en';

    if (!_hasSearched) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(prefs.getLabel('start_search_instruction'))),
      );
    }

    if (_displayedStickers.isEmpty) {
      if (_isLoadingMore) {
        return const SliverFillRemaining(
          hasScrollBody: false,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return SliverFillRemaining(
        hasScrollBody: false,
        child: Center(child: Text(prefs.getLabel('no_stickers_found'))),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate(
            (context, index) {
          if (index == _displayedStickers.length) {
            return const Padding(
              padding: EdgeInsets.all(8.0),
              child: Center(child: CircularProgressIndicator()),
            );
          }

          final sticker = _displayedStickers[index];
          String displayName;

          if (isEnglish && sticker.nameInEnglish.isNotEmpty) {
            displayName = sticker.nameInEnglish;
          } else if (!isEnglish && sticker.nameInHebrew.isNotEmpty) {
            displayName = sticker.nameInHebrew;
          } else {
            displayName = sticker.text;
          }

          String displayQuote;
          if (isEnglish && sticker.enQuote.isNotEmpty) {
            displayQuote = sticker.enQuote;
          } else if (!isEnglish && sticker.heQuote.isNotEmpty) {
            displayQuote = sticker.heQuote;
          } else {
            displayQuote = sticker.content;
          }

          return Column(
            children: [
              ListTile(
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

                title: Text(
                  displayName,
                  textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),

                subtitle: Text(
                    parse(displayQuote).body?.text ?? '',
                    textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis
                ),
                onTap: () {
                  _showStickerDetails(sticker);
                },
              ),
              if (index < _displayedStickers.length - 1)
                const Divider(height: 1),
            ],
          );
        },
        childCount: _displayedStickers.length + (_isLoadingMore ? 1 : 0),
      ),
    );
  }
}