import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stickers_of_meaning/screens/daily_sticker_settings_screen.dart';
import 'package:stickers_of_meaning/screens/sticker_pool_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../services/preferences_service.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import 'preferences_screen.dart';
import 'sticker_search_screen.dart';
import 'widget_settings_screen.dart';
import '../widgets/set_as_widget_button.dart'; // Import the new widget

class HomeScreen extends StatefulWidget {
  static const String routeName = '/';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<Sticker>? _futureSticker;
  bool _isUpdatingWidget = false;

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
      // Just load the sticker; widget ID is now handled by Provider watching
      _futureSticker = api.getDailySticker(prefs, widgetService);
    });
  }

  Future<void> _refreshSticker() async {
    _loadDailySticker();
    try {
      if (_futureSticker != null) await _futureSticker;
    } catch (e) {}
  }

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

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    // 3. Watch global widget ID state
    final currentWidgetId = prefs.widgetStickerId;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(kToolbarHeight),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AppBar(
            backgroundColor: const Color(0xFFF5F7FA),
            leading: IconButton(
              icon: const Icon(Icons.info_outline, size: 25),
              tooltip: prefs.getLabel('visit_site'),
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
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, StickerSearchScreen.routeName);
        },
        backgroundColor: const Color(0xFF1E3A8A),
        child: const Icon(Icons.search, color: Colors.white),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSticker,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          children: [
            Text(
              prefs.getLabel('todays_sticker'),
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A8A),
              ),
            ),
            const SizedBox(height: 10),
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
                      'Error loading sticker.',
                      style: TextStyle(color: Colors.red),
                    ),
                  );
                } else if (!snapshot.hasData) {
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(prefs.getLabel('no_sticker_available')),
                  );
                }

                final sticker = snapshot.data!;
                // Check using global state
                final isAlreadyInWidget = currentWidgetId == sticker.id;

                String displayName = prefs.language == 'en'
                    ? (sticker.nameInEnglish.isNotEmpty ? sticker.nameInEnglish : sticker.text)
                    : sticker.nameInHebrew;

                return Card(
                  elevation: 2,
                  shadowColor: Colors.black.withOpacity(0.08),
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Stack(
                    children: [
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
                              displayName,
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
                                      child: Text(
                                        prefs.getLabel('see_info'),
                                        style: const TextStyle(
                                          color: Color(0xFF1E3A8A),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: StickerWidgetButton(sticker: sticker),
                                ),
                                // Expanded(
                                //   child: isAlreadyInWidget
                                //       ? SizedBox(
                                //     height: 40,
                                //     child: OutlinedButton.icon(
                                //       onPressed: () {},
                                //       style: OutlinedButton.styleFrom(
                                //         padding: EdgeInsets.zero,
                                //         side: const BorderSide(color: Color(0xFF1E3A8A), width: 1),
                                //         shape: RoundedRectangleBorder(
                                //           borderRadius: BorderRadius.circular(20),
                                //         ),
                                //       ),
                                //       icon: const Icon(Icons.check, size: 16, color: Color(0xFF1E3A8A)),
                                //       label: Text(
                                //         prefs.getLabel('sticker_in_widget'),
                                //         textAlign: TextAlign.center,
                                //         style: const TextStyle(
                                //           color: Color(0xFF1E3A8A),
                                //           fontWeight: FontWeight.bold,
                                //           fontSize: 11,
                                //         ),
                                //       ),
                                //     ),
                                //   )
                                //       : Container(
                                //     height: 40,
                                //     decoration: BoxDecoration(
                                //       borderRadius: BorderRadius.circular(20),
                                //       gradient: const LinearGradient(
                                //         begin: Alignment.topCenter,
                                //         end: Alignment.bottomCenter,
                                //         colors: [
                                //           Color(0xFF1E3A8A),
                                //           Color(0xFF3B82C4)
                                //         ],
                                //       ),
                                //     ),
                                //     child: ElevatedButton(
                                //       // Disable button if updating
                                //       onPressed: _isUpdatingWidget ? null : () => _sendToWidget(sticker),
                                //       style: ElevatedButton.styleFrom(
                                //         backgroundColor: Colors.transparent,
                                //         shadowColor: Colors.transparent,
                                //         shape: RoundedRectangleBorder(
                                //           borderRadius: BorderRadius.circular(20),
                                //         ),
                                //         padding: EdgeInsets.zero,
                                //       ),
                                //       child: Text(
                                //         prefs.getLabel('send_to_widget'),
                                //         style: const TextStyle(
                                //           color: Colors.white,
                                //           fontWeight: FontWeight.bold,
                                //           fontSize: 13,
                                //         ),
                                //       ),
                                //     ),
                                //   ),
                                // ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      Positioned(
                        top: 0,
                        right: 5,
                        child: Consumer<PreferencesService>(
                          builder: (context, prefs, _) {
                            final isSaved = prefs.isStickerInPool(sticker.id);
                            return Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.white.withAlpha(0),
                                    blurRadius: 7,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: IconButton(
                                icon: Icon(
                                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                                  color: const Color(0xFF1E3A8A),
                                  size: 30,
                                ),
                                tooltip: isSaved
                                    ? prefs.getLabel('tooltip_remove_collection')
                                    : prefs.getLabel('tooltip_save_collection'),
                                splashColor: Colors.transparent,
                                highlightColor: Colors.transparent,
                                hoverColor: Colors.transparent,
                                onPressed: () async {
                                  if (isSaved) {
                                    await context.read<ApiService>().safeRemoveFromPool(context, sticker.id);
                                  } else {
                                    await prefs.addToPool(sticker);
                                  }
                                },
                              ),
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
              title: prefs.getLabel('your_collection'),
              subtitle: prefs.getLabel('explore_collection'),
              icon: Icons.collections,
              onTap: () => Navigator.pushNamed(context, StickerPoolScreen.routeName),
            ),
            _buildMenuButton(
              title: prefs.getLabel('customize_widget'),
              subtitle: prefs.getLabel('settings_customization'),
              icon: Icons.color_lens,
              onTap: () => Navigator.pushNamed(context, WidgetSettingsScreen.routeName),
            ),
            _buildMenuButton(
              title: prefs.getLabel('content_preferences'),
              subtitle: prefs.getLabel('what_to_see'),
              icon: Icons.widgets,
              onTap: () => Navigator.pushNamed(context, DailyStickerSettingsScreen.routeName),
            ),
            _buildMenuButton(
              title: prefs.getLabel('visit_site'),
              subtitle: prefs.getLabel('sticker_of_meaning'),
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