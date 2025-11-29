class Sticker {
  final int id;
  final String text;
  final String imageUrl;
  final DateTime? date;

  Sticker({
    required this.id,
    required this.text,
    required this.imageUrl,
    this.date,
  });

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
}
