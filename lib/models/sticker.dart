class Sticker {
  final int id;
  final String text;
  final String imageUrl;
  final String postUrl; // <--- NEW FIELD
  final DateTime? date;

  Sticker({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.postUrl, // <--- NEW REQUIREMENT
    this.date,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    // 1. Get the title (WordPress format)
    String textContent = json['title']['rendered'] ?? '';

    // 2. Get the Image URL (WordPress format using _embedded)
    String imgUrl = '';
    if (json['_embedded'] != null &&
        json['_embedded']['wp:featuredmedia'] != null) {
      var media = json['_embedded']['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        imgUrl = media[0]['source_url'] ?? '';
      }
    }

    // 3. Get the Post Link
    String link = json['link'] ?? ''; // <--- Capture the link

    return Sticker(
      id: json['id'] as int,
      text: textContent,
      imageUrl: imgUrl,
      postUrl: link, // <--- Store it
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }
}