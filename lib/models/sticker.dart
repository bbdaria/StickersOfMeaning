import 'package:html_unescape/html_unescape.dart';

class Sticker {
  final int id;
  final String text;
  final String imageUrl;
  final String postUrl;
  final DateTime? date;

  Sticker({
    required this.id,
    required this.text,
    required this.imageUrl,
    required this.postUrl,
    this.date,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    // 2. Create the converter
    var unescape = HtmlUnescape();

    // 3. Get the raw text and convert it
    String rawText = json['title']['rendered'] ?? '';
    String textContent = unescape.convert(rawText);

    // Get Image URL
    String imgUrl = '';
    if (json['_embedded'] != null &&
        json['_embedded']['wp:featuredmedia'] != null) {
      var media = json['_embedded']['wp:featuredmedia'];
      if (media is List && media.isNotEmpty) {
        imgUrl = media[0]['source_url'] ?? '';
      }
    }

    // Get Link
    String link = json['link'] ?? '';

    return Sticker(
      id: json['id'] as int,
      text: textContent, // Use the clean text
      imageUrl: imgUrl,
      postUrl: link,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }
}