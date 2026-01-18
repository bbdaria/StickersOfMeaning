import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticker.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';
import 'sticker_search_screen.dart';
import 'package:html/parser.dart' show parse;

class StickerPoolScreen extends StatefulWidget {
  static const String routeName = '/sticker-pool';

  const StickerPoolScreen({super.key});

  @override
  State<StickerPoolScreen> createState() => _StickerPoolScreenState();
}

class _StickerPoolScreenState extends State<StickerPoolScreen> {
  List<Sticker> _pool = [];
  List<Sticker> _filteredPool = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadPool();
  }

  void _loadPool() {
    final prefs = context.read<PreferencesService>();
    final list = prefs.getStickerPool();
    setState(() {
      _pool = list;
      if (_searchController.text.isNotEmpty) {
        _filterPool(_searchController.text);
      } else {
        _filteredPool = list;
      }
    });
  }

  void _filterPool(String query) {
    if (query.isEmpty) {
      setState(() => _filteredPool = _pool);
      return;
    }
    final lower = query.toLowerCase();
    setState(() {
      _filteredPool = _pool.where((s) {
        return s.text.toLowerCase().contains(lower) ||
            s.content.toLowerCase().contains(lower) ||
            s.nameInEnglish.toLowerCase().contains(lower) ||
            s.enQuote.toLowerCase().contains(lower);
      }).toList();
    });
  }

  Future<void> _removeFromPool(int id) async {
    final prefs = context.read<PreferencesService>();
    await prefs.removeFromPool(id);
    _loadPool();
    // Removed Snackbar
  }

  Future<void> _setAsWidget(Sticker sticker) async {
    await context.read<WidgetService>().updateStickerWidget(sticker);
    // Removed Snackbar
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
          child: AppBar(title: Text(prefs.getLabel('your_collection'))),
        ),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, StickerSearchScreen.routeName).then((_) {
            _loadPool();
          });
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.add, color: Colors.white),
      ),

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
              decoration: InputDecoration(
                hintText: prefs.getLabel('search_collection_hint'),
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: _filterPool,
            ),
          ),

          Expanded(
            child: _filteredPool.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.collections_bookmark_outlined, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text(
                    prefs.getLabel('empty_collection_message'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredPool.length,
              itemBuilder: (context, index) {
                final sticker = _filteredPool[index];
                ImageProvider? imageProvider;

                if (sticker.localImagePath != null) {
                  final file = File(sticker.localImagePath!);
                  if (file.existsSync()) {
                    imageProvider = FileImage(file);
                  }
                }

                if (imageProvider == null && sticker.imageUrl.isNotEmpty) {
                  imageProvider = NetworkImage(sticker.imageUrl);
                }

                String displayTitle = isEnglish
                    ? (parse(sticker.enQuote).body?.text ?? sticker.enQuote)
                    : (parse(sticker.heQuote).body?.text ?? sticker.heQuote);
                if (displayTitle.isEmpty) displayTitle = sticker.content;

                String displaySubtitle = isEnglish
                    ? (sticker.nameInEnglish.isNotEmpty ? sticker.nameInEnglish : sticker.text)
                    : (sticker.nameInHebrew.isNotEmpty ? sticker.nameInHebrew : sticker.text);

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),
                    leading: imageProvider != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: imageProvider,
                        width: 80,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (_,__,___) => const Icon(Icons.broken_image),
                      ),
                    )
                        : const Icon(Icons.sticky_note_2, size: 40),

                    title: Text(displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl
                    ),
                    subtitle: Text(
                        displaySubtitle,
                        textDirection: isEnglish ? TextDirection.ltr : TextDirection.rtl,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis
                    ),

                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        PopupMenuItem(
                          value: 'widget',
                          child: Row(
                            children: [
                              const Icon(Icons.send, size: 20, color: Colors.blue),
                              const SizedBox(width: 8),
                              Text(prefs.getLabel('set_as_widget'))
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'remove',
                          child: Row(
                            children: [
                              const Icon(Icons.delete, color: Colors.red, size: 20),
                              const SizedBox(width: 8),
                              Text(
                                prefs.getLabel('remove'),
                                style: const TextStyle(color: Colors.red),
                              )
                            ],
                          ),
                        ),
                      ],
                      onSelected: (value) {
                        if (value == 'widget') _setAsWidget(sticker);
                        if (value == 'remove') _removeFromPool(sticker.id);
                      },
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}