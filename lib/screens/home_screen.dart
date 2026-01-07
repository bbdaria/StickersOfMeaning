import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/preferences_service.dart';
import '../models/sticker.dart';
import '../services/api_service.dart';
import '../services/widget_service.dart';
import 'preferences_screen.dart';
import 'sticker_search_screen.dart';
import 'todays_sticker_screen.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../widgets/gradient_button.dart';

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
      // Use the new getDailySticker method
      _futureSticker = api.getDailySticker(prefs, widgetService);
    });
  }

  Future<void> _refreshSticker() async {
    // For manual refresh, you might want to force a new random sticker?
    // Or just reload the current daily one. Let's just reload for now.
    _loadDailySticker();
  }

  Future<void> _sendToWidget(Sticker sticker) async {
    final widgetService = context.read<WidgetService>();
    await widgetService.updateStickerWidget(sticker);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Widget updated')));
  }
  Widget _buildMenuButton({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GradientButton(
      onPressed: onTap,
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: SvgPicture.asset(
          'assets/icons/Logo.svg',
          height: 40,
          fit: BoxFit.contain,
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.pushNamed(context, PreferencesScreen.routeName);
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshSticker,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              "Today's Sticker",
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: Color(0xFF001a7e)),
            ),
            const SizedBox(height: 8),
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
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Error loading sticker: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
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
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Color(0xFF001a7e), width: 3.0),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (sticker.imageUrl.isNotEmpty)
                        AspectRatio(
                          aspectRatio: 16 / 9,
                          // You can now remove the ClipRRect wrapper if you want,
                          // or keep it. The Card's clipBehavior handles the edges now.
                          child: Image.network(
                            sticker.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return const Center(child: Icon(Icons.broken_image));
                            },
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          sticker.text,
                          style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold
                          ),
                          textAlign:  TextAlign.center,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            TextButton(
                              onPressed: () async {
                                final uri = Uri.parse(sticker.postUrl);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                }
                              },
                              child: const Text('See more info in website'),
                            ),
                            const SizedBox(height:1),
                            TextButton(
                              onPressed: () => _sendToWidget(sticker),
                              child: const Text('Send to widget'),
                            ),
                          ],
                        ),

                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'More',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF001a7e)),
            ),
            const SizedBox(height: 12),
            _buildMenuButton(
              title: 'Sticker database search',
              subtitle: 'Find stickers by topic and author',
              icon: Icons.search,
              onTap: () => Navigator.pushNamed(context, StickerSearchScreen.routeName),
            ),
            const SizedBox(height: 12),
            _buildMenuButton(
              title: 'Widget setup',
              subtitle: 'Configure widget size and style',
              icon: Icons.widgets,
              onTap: () => Navigator.pushNamed(context, PreferencesScreen.routeName),
            ),
            const SizedBox(height: 12),
            _buildMenuButton(
              title: 'Our site',
              subtitle: 'Sticker Of Meaning',
              icon: Icons.computer,
              onTap: () => launchUrl(Uri.https('stickersofmeaning.org')),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
