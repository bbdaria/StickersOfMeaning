import 'package:html_unescape/html_unescape.dart';

class Sticker {
  final int id;
  final String text;    // Hebrew Name
  final String content; // Hebrew Quote
  final String imageUrl;
  final String postUrl;
  final DateTime? date;

  final String nameInEnglish;
  final String nameInHebrew;
  final String enQuote;
  final String heQuote;

  // This field is crucial for the pool
  final String? localImagePath;

  Sticker({
    required this.id,
    required this.text,
    required this.content,
    required this.imageUrl,
    required this.postUrl,
    this.date,
    this.nameInEnglish = '',
    this.nameInHebrew = '',
    this.enQuote = '',
    this.heQuote = '',
    this.localImagePath,
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();

    // 1. Title
    String textContent = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      textContent = unescape.convert(json['title']['rendered']);
    }

    // 2. Meta Data
    String nameEn = '';
    String nameHe = '';
    String quoteEn = '';
    String quoteHe = '';

    if (json['meta'] != null) {
      if (json['meta']['name_in_english'] != null) nameEn = unescape.convert(json['meta']['name_in_english'].toString());
      if (json['meta']['name_in_hebrew'] != null) nameHe = unescape.convert(json['meta']['name_in_hebrew'].toString());
      if (json['meta']['en_quote'] != null) quoteEn = unescape.convert(json['meta']['en_quote'].toString());
      if (json['meta']['he_quote'] != null) quoteHe = unescape.convert(json['meta']['he_quote'].toString());
    }

    // 3. Content (Logic from before)
    String quoteContent = quoteHe.isNotEmpty ? quoteHe : '';
    if (quoteContent.isEmpty) {
      // ... (Your existing content fallback logic here) ...
      if (json['content'] != null && json['content']['rendered'] != null) {
        quoteContent = unescape.convert(json['content']['rendered'].replaceAll(RegExp(r'<[^>]*>'), '').trim());
      }
    }

    // 4. Image URL
    String imgUrl = '';
    if (json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
      var list = json['_embedded']['wp:featuredmedia'];
      if (list is List && list.isNotEmpty) {
        imgUrl = list[0]['source_url'] ?? '';
      }
    }
    // Fallback if imageUrl is directly in root (sometimes used in local saves)
    if (imgUrl.isEmpty && json['imageUrl'] != null) {
      imgUrl = json['imageUrl'];
    }

    // 5. Link
    String link = json['link'] ?? '';

    // --- CRITICAL FIX: READ LOCAL PATH ---
    String? localPath = json['localImagePath'];
    // -------------------------------------

    return Sticker(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id'].toString()) ?? 0,
      text: textContent,
      content: quoteContent,
      imageUrl: imgUrl,
      postUrl: link,
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
      nameInEnglish: nameEn,
      nameInHebrew: nameHe,
      enQuote: quoteEn,
      heQuote: quoteHe,
      localImagePath: localPath, // <--- IMPORTANT
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'rendered': text},
      'content': {'rendered': content},
      'localImagePath': localImagePath, // <--- IMPORTANT
      'imageUrl': imageUrl,
      'link': postUrl,
      'date': date?.toIso8601String(),
      'meta': {
        'name_in_english': nameInEnglish,
        'name_in_hebrew': nameInHebrew,
        'en_quote': enQuote,
        'he_quote': heQuote,
      }
    };
  }

  Sticker copyWith({String? localImagePath}) {
    return Sticker(
      id: id,
      text: text,
      content: content,
      imageUrl: imageUrl,
      postUrl: postUrl,
      date: date,
      nameInEnglish: nameInEnglish,
      nameInHebrew: nameInHebrew,
      enQuote: enQuote,
      heQuote: heQuote,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}