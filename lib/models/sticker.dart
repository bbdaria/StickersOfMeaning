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
    return Sticker(
      id: json['id'] as int,
      text: json['text'] as String? ?? '',
      imageUrl: json['image_url'] as String? ?? '',
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String)
          : null,
    );
  }
}
