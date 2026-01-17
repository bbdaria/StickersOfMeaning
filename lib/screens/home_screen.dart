import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stickers_of_meaning/screens/sticker_pool_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/preferences_service.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import '../widgets/gradient_button.dart';
import 'preferences_screen.dart';
import 'sticker_search_screen.dart';
import 'widget_settings_screen.dart';



class HomeScreen extends StatefulWidget {
  static const String routeName = '/';


  const HomeScreen({super.key});


  @override
  State<HomeScreen> createState() => _HomeScreenState();
}


class _HomeScreenState extends State<HomeScreen> {
  Future<Sticker>? _futureSticker;


  @override
  void initState() {
    super.initState();
    _loadDailySticker();
  }


  void _loadDailySticker() {
    final api = context.read<ApiService>();
    final prefs = context.read<PreferencesService>();
    final widgetService = context.read<WidgetService>();


    setState(() {
      _futureSticker = api.getDailySticker(prefs, widgetService);
    });
  }


  Future<void> _refreshSticker() async {
    _loadDailySticker();
  }


  Future<void> _sendToWidget(Sticker sticker) async {
    final widgetService = context.read<WidgetService>();
    await widgetService.updateStickerWidget(sticker);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Widget updated'), duration: Duration(milliseconds: 750)));
  }


  // Redesigned Menu Button (Compact White Card Style)
  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                // Icon with light blue background
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFE3F2FD),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: const Color(0xFF1E3A8A), size: 20),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios, color: Colors.grey, size: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openMainSite(BuildContext context) async {
    const url = 'https://stickersofmeaning.org';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA), // Light off-white background
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F7FA),
        leading: IconButton(
          icon: const Icon(Icons.info_outline, size: 25),
          tooltip: 'Visit Site',
          onPressed: () => _openExternalUrl(context, 'https://stickersofmeaning.org/contact/'),
        ),
        elevation: 0,
        title: SvgPicture.asset(
          'assets/icons/Logo.svg',
          height: 28,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.black87, size: 25),
            onPressed: () {
              Navigator.pushNamed(context, PreferencesScreen.routeName);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, StickerSearchScreen.routeName);
        },
        backgroundColor: const Color(0xFF1E3A8A), // Consistent App Blue
        child: const Icon(Icons.search, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSticker,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            const Text(
              "Today's Sticker",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 10),
            // FutureBuilder<Sticker>(
            //   future: _futureSticker,
            //   builder: (context, snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting) {
            //       return const Center(
            //         child: Padding(
            //           padding: EdgeInsets.all(24),
            //           child: CircularProgressIndicator(),
            //         ),
            //       );
            //     } else if (snapshot.hasError) {
            //       return Padding(
            //         padding: const EdgeInsets.all(16),
            //         child: Text(
            //           'Error loading sticker: while connecting',
            //           style: const TextStyle(color: Colors.red),
            //         ),
            //       );
            //     } else if (!snapshot.hasData) {
            //       return const Padding(
            //         padding: EdgeInsets.all(16),
            //         child: Text('No sticker available'),
            //       );
            //     }
            //
            //
            //     final sticker = snapshot.data!;
            //     return Card(
            //       elevation: 2,
            //       shadowColor: Colors.black.withOpacity(0.08),
            //       clipBehavior: Clip.antiAlias,
            //       shape: RoundedRectangleBorder(
            //         borderRadius: BorderRadius.circular(16),
            //       ),
            //       child: Column(
            //         crossAxisAlignment: CrossAxisAlignment.stretch,
            //         children: [
            //           if (sticker.imageUrl.isNotEmpty)
            //             Padding(
            //               padding: const EdgeInsets.only(top: 12.0), // Adds the gap at the top
            //               child: AspectRatio(
            //                 aspectRatio: 16 / 9,
            //                 child: Image.network(
            //                   sticker.imageUrl,
            //                   fit: BoxFit.contain,
            //                   errorBuilder: (context, error, stackTrace) {
            //                     return const Center(child: Icon(Icons.broken_image));
            //                   },
            //                 ),
            //               ),
            //             ),
            //           Padding(
            //             padding: const EdgeInsets.all(14),
            //             child: Text(
            //               sticker.text,
            //               style: const TextStyle(
            //                 fontSize: 18,
            //                 fontWeight: FontWeight.bold,
            //               ),
            //               textAlign: TextAlign.center,
            //             ),
            //           ),
            //           Padding(
            //             padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
            //             child: Row(
            //               children: [
            //                 // 1. See Info Button (Compact Outlined)
            //                 Expanded(
            //                   child: SizedBox(
            //                     height: 40,
            //                     child: OutlinedButton(
            //                       onPressed: () async {
            //                         final uri = Uri.parse(sticker.postUrl);
            //                         if (await canLaunchUrl(uri)) {
            //                           await launchUrl(uri,
            //                               mode: LaunchMode.externalApplication);
            //                         }
            //                       },
            //                       style: OutlinedButton.styleFrom(
            //                         padding: EdgeInsets.zero,
            //                         side: const BorderSide(
            //                             color: Color(0xFF1E3A8A), width: 1),
            //                         shape: RoundedRectangleBorder(
            //                           borderRadius: BorderRadius.circular(20),
            //                         ),
            //                       ),
            //                       child: const Text(
            //                         'See Info',
            //                         style: TextStyle(
            //                           color: Color(0xFF1E3A8A),
            //                           fontWeight: FontWeight.bold,
            //                           fontSize: 13,
            //                         ),
            //                       ),
            //                     ),
            //                   ),
            //                 ),
            //                 const SizedBox(width: 10),
            //                 // 2. Send to Widget Button (Compact Gradient)
            //                 Expanded(
            //                   child: Container(
            //                     height: 40,
            //                     decoration: BoxDecoration(
            //                       borderRadius: BorderRadius.circular(20),
            //                       gradient: const LinearGradient(
            //                         begin: Alignment.topCenter,
            //                         end: Alignment.bottomCenter,
            //                         colors: [
            //                           Color(0xFF1E3A8A),
            //                           Color(0xFF3B82C4)
            //                         ],
            //                       ),
            //                       boxShadow: [
            //                         BoxShadow(
            //                           color: const Color(0xFF1E3A8A).withOpacity(0.2),
            //                           blurRadius: 4,
            //                           offset: const Offset(0, 2),
            //                         ),
            //                       ],
            //                     ),
            //                     child: ElevatedButton(
            //                       onPressed: () => _sendToWidget(sticker),
            //                       style: ElevatedButton.styleFrom(
            //                         backgroundColor: Colors.transparent,
            //                         shadowColor: Colors.transparent,
            //                         shape: RoundedRectangleBorder(
            //                           borderRadius: BorderRadius.circular(20),
            //                         ),
            //                         padding: EdgeInsets.zero,
            //                       ),
            //                       child: const Text(
            //                         'Send to Widget',
            //                         style: TextStyle(
            //                           color: Colors.white,
            //                           fontWeight: FontWeight.bold,
            //                           fontSize: 13,
            //                         ),
            //                       ),
            //                     ),
            //                   ),
            //                 ),
            //                 const SizedBox(width: 10),
            //                 // 2. Send to Widget Button (Compact Gradient)
            //                 Expanded(
            //                   child: Container(
            //                     height: 40,
            //                     decoration: BoxDecoration(
            //                       borderRadius: BorderRadius.circular(20),
            //                       gradient: const LinearGradient(
            //                         begin: Alignment.topCenter,
            //                         end: Alignment.bottomCenter,
            //                         colors: [
            //                           Color(0xFF1E3A8A),
            //                           Color(0xFF3B82C4)
            //                         ],
            //                       ),
            //                       boxShadow: [
            //                         BoxShadow(
            //                           color: const Color(0xFF1E3A8A).withOpacity(0.2),
            //                           blurRadius: 4,
            //                           offset: const Offset(0, 2),
            //                         ),
            //                       ],
            //                     ),
            //                     child: ElevatedButton(
            //                       onPressed: () => _sendToWidget(sticker),
            //                       style: ElevatedButton.styleFrom(
            //                         backgroundColor: Colors.transparent,
            //                         shadowColor: Colors.transparent,
            //                         shape: RoundedRectangleBorder(
            //                           borderRadius: BorderRadius.circular(20),
            //                         ),
            //                         padding: EdgeInsets.zero,
            //                       ),
            //                       child: const Text(
            //                         'Save',
            //                         style: TextStyle(
            //                           color: Colors.white,
            //                           fontWeight: FontWeight.bold,
            //                           fontSize: 13,
            //                         ),
            //                       ),
            //                     ),
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ],
            //       ),
            //     );
            //   },
            // ),

            FutureBuilder<Sticker>(
              future: _futureSticker,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: CircularProgressIndicator(),
                    ),
                  );
                } else if (snapshot.hasError) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Error loading sticker. Please check your connection.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No sticker available'),
                  );
                }

                final sticker = snapshot.data!;
                return Card(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.08),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
                      // 1. Existing Content (Column)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (sticker.imageUrl.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 12.0),
                              child: AspectRatio(
                                aspectRatio: 16 / 9,
                                child: Image.network(
                                  sticker.imageUrl,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Center(child: Icon(Icons.broken_image));
                                  },
                                ),
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Text(
                              sticker.text,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                            child: Row(
                              children: [
                                // See Info Button
                                Expanded(
                                  child: SizedBox(
                                    height: 40,
                                    child: OutlinedButton(
                                      onPressed: () async {
                                        final uri = Uri.parse(sticker.postUrl);
                                        if (await canLaunchUrl(uri)) {
                                          await launchUrl(uri,
                                              mode: LaunchMode.externalApplication);
                                        }
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        side: const BorderSide(
                                            color: Color(0xFF1E3A8A), width: 1),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                      ),
                                      child: const Text(
                                        'See Info',
                                        style: TextStyle(
                                          color: Color(0xFF1E3A8A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                // Send to Widget Button
                                Expanded(
                                  child: Container(
                                    height: 40,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(20),
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF1E3A8A),
                                          Color(0xFF3B82C4)
                                        ],
                                      ),
                                    ),
                                    child: ElevatedButton(
                                      onPressed: () => _sendToWidget(sticker),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(20),
                                        ),
                                        padding: EdgeInsets.zero,
                                      ),
                                      child: const Text(
                                        'Send to Widget',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 2. NEW: Floating Ribbon Button (Top Right)
                      Positioned(
                        top: 0,
                        right: 4,
                        child: Consumer<PreferencesService>(
                          builder: (context, prefs, _) {
                            final isSaved = prefs.isStickerInPool(sticker.id);
                            return IconButton(
                              icon: Icon(
                                isSaved ? Icons.bookmark : Icons.bookmark_border,
                                color: const Color(0xFF1E3A8A),
                                size: 30,
                              ),
                              tooltip: isSaved ? 'Remove from Pool' : 'Save to Pool',
                              onPressed: () async {
                                if (isSaved) {
                                  await prefs.removeFromPool(sticker.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Removed from pool'), duration: Duration(seconds: 1)),
                                    );
                                  }
                                } else {
                                  await prefs.addToPool(sticker);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Saved to pool!'), duration: Duration(milliseconds: 750)),
                                    );
                                  }
                                }
                              },
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            const SizedBox(height: 20),
            _buildMenuButton(
              title: 'Manage your stickers',
              subtitle: 'Explore and add to the collection',
              icon: Icons.collections,
              onTap: () =>
                  Navigator.pushNamed(context, StickerPoolScreen.routeName),
            ),
            _buildMenuButton(
              title: 'Setup your widget',
              subtitle: 'Settings and customization',
              icon: Icons.widgets,
              onTap: () =>
                  Navigator.pushNamed(context, WidgetSettingsScreen.routeName),
            ),
            _buildMenuButton(
              title: 'Visit our site',
              subtitle: 'Sticker Of Meaning',
              icon: Icons.language,
              onTap: () => launchUrl(Uri.https('stickersofmeaning.org')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}



