import 'package:html_unescape/html_unescape.dart';

class Sticker {
  final int id;
  final String text;    // The Title (Name of the person)
  final String content; // The Quote (Content/Meaning)
  final String imageUrl;
  final String postUrl;
  final DateTime? date;

  Sticker({
    required this.id,
    required this.text,
    required this.content, // Add this
    required this.imageUrl,
    required this.postUrl,
    this.date,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();

    // 1. Get Title (The Person's Name)
    String textContent = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      textContent = unescape.convert(json['title']['rendered']);
    }

    // 2. Find the Quote (The Meaning)
    String quoteContent = '';

    // List of probable keys where the quote might be hidden
    // (JetEngine/ACF often uses these names)
    const possibleKeys = [
      'quote', 'motto', 'message', 'meaning', 'description',
      'sticker_text', 'sticker_quote', 'life_rule'
    ];

    // A. Check Root Level Custom Fields (JetEngine often exposes them here)
    for (var key in possibleKeys) {
      if (json[key] != null && json[key].toString().isNotEmpty) {
        quoteContent = unescape.convert(json[key].toString());
        break;
      }
    }

    // B. Check "meta" fields
    if (quoteContent.isEmpty && json['meta'] != null) {
      for (var key in possibleKeys) {
        if (json['meta'][key] != null && json['meta'][key].toString().isNotEmpty) {
          quoteContent = unescape.convert(json['meta'][key].toString());
          break;
        }
      }
    }

    // C. Fallback: Check Content/Excerpt (if they decide to use it later)
    if (quoteContent.isEmpty) {
      if (json['content'] != null && json['content']['rendered'] != null && json['content']['rendered'].toString().isNotEmpty) {
        String raw = json['content']['rendered'];
        String stripped = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        if (stripped.isNotEmpty) quoteContent = unescape.convert(stripped);
      }
    }

    // D. Fallback: Check Image Caption/Alt (If provided via _embed)
    if (quoteContent.isEmpty && json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
      var mediaList = json['_embedded']['wp:featuredmedia'];
      if (mediaList is List && mediaList.isNotEmpty) {
        var media = mediaList[0];
        // Check Caption
        if (media['caption'] != null && media['caption']['rendered'] != null) {
          String cap = media['caption']['rendered'].toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (cap.isNotEmpty) quoteContent = unescape.convert(cap);
        }
        // Check Alt Text
        if (quoteContent.isEmpty && media['alt_text'] != null) {
          quoteContent = unescape.convert(media['alt_text'].toString());
        }
      }
    }

    // 3. Get Image URL
    String imgUrl = '';
    if (json['_embedded'] != null &&
        json['_embedded']['wp:featuredmedia'] != null) {
      var mediaList = json['_embedded']['wp:featuredmedia'];
      if (mediaList is List && mediaList.isNotEmpty) {
        imgUrl = mediaList[0]['source_url'] ?? '';
      }
    }

    // 4. Get Link
    String link = json['link'] ?? '';

    return Sticker(
      id: json['id'] as int,
      text: textContent,
      content: quoteContent,
      imageUrl: imgUrl,
      postUrl: link,
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
    );
  }
}