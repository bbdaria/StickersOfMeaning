import 'package:meta/meta.dart';

@immutable
class StickerCategory {
  final int id;
  final String name;
  final String slug;

  const StickerCategory({
    required this.id,
    required this.name,
    required this.slug,
  });

  factory StickerCategory.fromJson(Map<String, dynamic> json) {
    return StickerCategory(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      slug: json['slug'] as String? ?? '',
    );
  }
}
