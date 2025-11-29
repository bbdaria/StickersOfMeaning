import 'package:meta/meta.dart';

/// Domain-model for a sticker(WordPress post).
/// A sticker is a quote in Hebrew+English with a link to its page
/// and the WordPress categories it belongs to.
@immutable
class Sticker {
  final int id;
  final String hebrewText;
  final String englishText;
  final String? imageUrl;
  final String? pageUrl;
  final List<int> categoryIds;
  final DateTime? date;

  const Sticker({
    required this.id,
    required this.hebrewText,
    required this.englishText,
    this.imageUrl,
    this.pageUrl,
    this.categoryIds = const [],
    this.date,
  });

  /// Parse from a generic WordPress post json.
  ///
  /// You will probably need to tweak the field names here once you
  /// inspect the real json from your site.
  factory Sticker.fromJson(Map<String, dynamic> json) {
    // Hebrew text is inside title.rendered
    final String hebrew = (json['title']?['rendered'] as String? ?? '').trim();

    // English text is usually inside content.rendered HTML
    String english = '';
    final contentRaw = json['content']?['rendered'];
    if (contentRaw is String) {
      // Simple HTML strip
      english = contentRaw.replaceAll(RegExp('<[^>]*>'), '').trim();
    }

    final List<int> categories = (json['categories'] as List<dynamic>? ?? [])
        .where((e) => e is int)
        .cast<int>()
        .toList();

    // Featured image from embedded media
    String? imageUrl;
    final embedded = json['_embedded'];
    if (embedded != null &&
        embedded['wp:featuredmedia'] is List &&
        embedded['wp:featuredmedia'].isNotEmpty &&
        embedded['wp:featuredmedia'][0] is Map) {
      final media = embedded['wp:featuredmedia'][0];
      if (media['source_url'] is String) {
        imageUrl = media['source_url'];
      }
    }

    return Sticker(
      id: json['id'],
      hebrewText: hebrew,
      englishText: english,
      imageUrl: imageUrl,
      pageUrl: json['link'],
      categoryIds: categories,
      date: DateTime.tryParse(json['date'] ?? ''),
    );
  }

  static String? _tryExtractFeaturedImage(Map<String, dynamic>? embedded) {
    if (embedded == null) return null;
    final mediaList = embedded['wp:featuredmedia'];
    if (mediaList is List && mediaList.isNotEmpty) {
      final media = mediaList.first;
      if (media is Map<String, dynamic>) {
        final sourceUrl = media['source_url'];
        if (sourceUrl is String && sourceUrl.isNotEmpty) {
          return sourceUrl;
        }
      }
    }
    return null;
  }
}
