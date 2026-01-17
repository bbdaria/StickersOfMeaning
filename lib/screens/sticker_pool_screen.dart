import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sticker.dart';
import '../services/preferences_service.dart';
import '../services/widget_service.dart';
import 'sticker_search_screen.dart'; // Import for navigation
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
      // Re-apply filter if text is present
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
    await context.read<PreferencesService>().removeFromPool(id);
    _loadPool();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Removed from pool'), duration: Duration(milliseconds: 750)));
    }
  }

  Future<void> _setAsWidget(Sticker sticker) async {
    await context.read<WidgetService>().updateStickerWidget(sticker);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Widget Updated!'), duration: Duration(milliseconds: 750)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Stickers')),

      // --- NEW: Floating Action Button ---
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Navigate to Search Screen
          Navigator.pushNamed(context, StickerSearchScreen.routeName).then((_) {
            // Refresh pool when user returns (in case they added new stickers)
            _loadPool();
          });
        },
        backgroundColor: const Color(0xFF1E3A8A), // Your App Blue
        child: const Icon(Icons.add, color: Colors.white),
      ),
      // -----------------------------------

      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search your stickers...',
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
                  const Text(
                    'Your collection is empty.\nTap the + button to add stickers!',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredPool.length,
              itemBuilder: (context, index) {
                final sticker = _filteredPool[index];

                // 1. Determine the Image Source (Local File vs Network)
                ImageProvider? imageProvider;

                // A. Try Local File
                if (sticker.localImagePath != null) {
                  final file = File(sticker.localImagePath!);
                  if (file.existsSync()) {
                    imageProvider = FileImage(file);
                  }
                }

                // B. Fallback to Network (only if valid)
                if (imageProvider == null && sticker.imageUrl.isNotEmpty) {
                  imageProvider = NetworkImage(sticker.imageUrl);
                }

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(8),

                    // 2. THE FIX: Check 'imageProvider' instead of 'imageUrl' string
                    leading: imageProvider != null
                        ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image(
                        image: imageProvider, // Use the provider we found
                        width: 60,
                        height: 60,
                        fit: BoxFit.contain,
                        errorBuilder: (_,__,___) => const Icon(Icons.broken_image),
                      ),
                    )
                        : const Icon(Icons.sticky_note_2, size: 40),

                    title: Text(parse(sticker.heQuote).body?.text ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textDirection: TextDirection.rtl),
                    subtitle: Text(
                        sticker.nameInHebrew.isNotEmpty ? sticker.nameInHebrew : sticker.content, textDirection: TextDirection.rtl,
                        maxLines: 1, overflow: TextOverflow.ellipsis
                    ),
                    trailing: PopupMenuButton(
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'widget',
                          child: Row(children: [Icon(Icons.arrow_back, size: 20, color: Colors.blue), SizedBox(width: 8), Text('Set as Widget')]),
                        ),
                        const PopupMenuItem(
                          value: 'remove',
                          child: Row(children: [Icon(Icons.delete, color: Colors.red, size: 20), SizedBox(width: 8), Text('Remove', style: TextStyle(color: Colors.red))]),
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