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
  final List<int> categories;

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
    this.categories = const [], // Default empty
  });

  factory Sticker.fromJson(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();
    String cleanText(dynamic input) {
      if (input == null) return '';
      String s = input.toString();
      // 1. Remove HTML tags
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
      // 2. Decode HTML entities (e.g. &amp; -> &)
      return unescape.convert(s).trim();
    }

    // 1. Get Title (The Person's Name)
    String textContent = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      textContent = cleanText(json['title']['rendered']);
    }

    // --- NEW: Parse Meta Fields for English/Hebrew Data ---
    String nameEn = '';
    String nameHe = '';
    String quoteEn = '';
    String quoteHe = '';

    if (json['meta'] != null) {
      nameEn = cleanText(json['meta']['name_in_english']);
      nameHe = cleanText(json['meta']['name_in_hebrew']);
      quoteEn = cleanText(json['meta']['en_quote']);
      quoteHe = cleanText(json['meta']['he_quote']);
    }
    // -------------------------------------------------------

    // 2. Find the Quote (The Meaning)
    // [Existing logic remains, but we prioritize meta if found]
    String quoteContent = quoteHe.isNotEmpty ? quoteHe : '';

    if (quoteContent.isEmpty) {
      // List of probable keys where the quote might be hidden
      const possibleKeys = [
        'quote', 'motto', 'message', 'meaning', 'description',
        'sticker_text', 'sticker_quote', 'life_rule'
      ];

      // [Existing Fallback Logic...]
      // A. Check Root Level
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

      // [Keep existing C and D fallbacks for Content and Image Caption if needed]
      // C. Fallback: Check Content/Excerpt
      if (quoteContent.isEmpty) {
        if (json['content'] != null && json['content']['rendered'] != null && json['content']['rendered'].toString().isNotEmpty) {
          String raw = json['content']['rendered'];
          String stripped = raw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
          if (stripped.isNotEmpty) quoteContent = unescape.convert(stripped);
        }
      }

      // D. Fallback: Check Image Caption/Alt
      if (quoteContent.isEmpty && json['_embedded'] != null && json['_embedded']['wp:featuredmedia'] != null) {
        var mediaList = json['_embedded']['wp:featuredmedia'];
        if (mediaList is List && mediaList.isNotEmpty) {
          var media = mediaList[0];
          if (media['caption'] != null && media['caption']['rendered'] != null) {
            String cap = media['caption']['rendered'].toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
            if (cap.isNotEmpty) quoteContent = unescape.convert(cap);
          }
          if (quoteContent.isEmpty && media['alt_text'] != null) {
            quoteContent = unescape.convert(media['alt_text'].toString());
          }
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

    // Fallback if imageUrl is directly in root (sometimes used in local saves)
    if (imgUrl.isEmpty && json['imageUrl'] != null) {
      imgUrl = json['imageUrl'];
    }

    List<int> cats = [];
    if (json['categories'] != null && json['categories'] is List) {
      cats = List<int>.from(json['categories']);
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
      localImagePath: localPath,
      categories: cats
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': {'rendered': text},
      'content': {'rendered': content},
      'localImagePath': localImagePath,
      'imageUrl': imageUrl,
      'link': postUrl,
      'date': date?.toIso8601String(),
      'categories': categories,
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
      categories: categories,
      localImagePath: localImagePath ?? this.localImagePath,
    );
  }
}