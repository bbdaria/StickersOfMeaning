import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/sticker.dart';
import '../models/sticker_category.dart';

/// Thin wrapper around the WordPress rest-api.
class ApiService {
  /// Example:'https://stickersofmeaning.org/wp-json/wp/v2/'
  final String baseUrl;

  ApiService({required this.baseUrl});

  Uri _buildUri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$baseUrl$path');
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {...uri.queryParameters, ...query});
  }

  Future<List<Sticker>> searchStickers({
    String? textQuery,
    int page = 1,
    int perPage = 20,
    List<int>? categoryIds,
  }) async {
    final params = <String, String>{
      'page': '$page',
      'per_page': '$perPage',
      '_embed': 'true', // so we can get featured-image
    };

    if (textQuery != null && textQuery.trim().isNotEmpty) {
      params['search'] = textQuery.trim();
    }
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }

    final uri = _buildUri('posts', params);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to search stickers:${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => Sticker.fromJson(e))
        .toList();
  }

  /// Use the latest post as todays-sticker.
  Future<Sticker> fetchTodaysSticker({List<int>? categoryFilter}) async {
    final params = <String, String>{
      'page': '1',
      'per_page': '1',
      'orderby': 'date',
      'order': 'desc',
      '_embed': 'true',
    };
    if (categoryFilter != null && categoryFilter.isNotEmpty) {
      params['categories'] = categoryFilter.join(',');
    }

    final uri = _buildUri('posts', params);
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load todays-sticker:${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    if (data.isEmpty) {
      throw Exception('No stickers returned from api');
    }
    final first = data.first as Map<String, dynamic>;
    return Sticker.fromJson(first);
  }

  Future<List<StickerCategory>> fetchCategories() async {
    final uri = _buildUri('categories', {
      'per_page': '100',
      'hide_empty': 'true',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Failed to load categories:${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body) as List<dynamic>;
    return data
        .whereType<Map<String, dynamic>>()
        .map((e) => StickerCategory.fromJson(e))
        .toList();
  }
}
