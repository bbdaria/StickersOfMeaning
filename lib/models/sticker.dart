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
    var unescape = HtmlUnescape();

    // 1. Get Title
    String textContent = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      textContent = unescape.convert(json['title']['rendered']);
    }

    // 2. Get Image URL (from embedded media)
    String imgUrl = '';
    if (json['_embedded'] != null &&
        json['_embedded']['wp:featuredmedia'] != null) {
      var mediaList = json['_embedded']['wp:featuredmedia'];
      if (mediaList is List && mediaList.isNotEmpty) {
        // Try to get the full size URL, or fallback to source_url
        imgUrl = mediaList[0]['source_url'] ?? '';
      }
    }

    // 3. Get Link
    String link = json['link'] ?? '';

    return Sticker(
      id: json['id'] as int,
      text: textContent,
      imageUrl: imgUrl,
      postUrl: link,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }
}