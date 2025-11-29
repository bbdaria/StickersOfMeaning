import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/sticker.dart';

class ApiService {
  final String baseUrl;

  ApiService({required this.baseUrl});

  Uri _buildUri(String path, [Map<String, String>? query]) {
    return Uri.parse('$baseUrl$path').replace(queryParameters: query);
  }

  Future<Sticker> fetchTodaysSticker() async {
    final uri = _buildUri('/stickers/today');
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load todays sticker');
    }

    final Map<String, dynamic> data = jsonDecode(response.body);
    return Sticker.fromJson(data);
  }

  Future<List<Sticker>> searchStickers(String query) async {
    final uri = _buildUri('/stickers/search', {'q': query});
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to search stickers');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Sticker.fromJson(e)).toList();
  }

// You can add more endpoints here, for example fetch by id
}
