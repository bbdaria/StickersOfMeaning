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
    // WordPress stores the title/content in a nested object called 'rendered'
    String textContent = json['title']['rendered'] ?? '';

    // WordPress stores images in a weird embedded field usually
    // We will assume for now the image URL is inside 'jetpack_featured_media_url'
    // or you might need to parse the '_embedded' field if you use standard WP media.
    // For this example, let's look for a common featured media field:
    String imgUrl = '';
    if (json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
      var media = json['_embedded']['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        imgUrl = media[0]['source_url'];
      }
    }

    return Sticker(
      id: json['id'] as int,
      text: textContent,
      imageUrl: imgUrl,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
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
