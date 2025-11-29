import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sticker.dart';

class ApiService {
  final String baseUrl;
  final String dbUrl;

  ApiService({required this.baseUrl, required this.dbUrl});

  Uri _buildUri(String rootUrl, String path, [Map<String, dynamic>? query]) {
    String cleanRoot = rootUrl.endsWith('/') ? rootUrl : '$rootUrl/';
    String cleanPath = path.startsWith('/') ? path.substring(1) : path;

    final uri = Uri.parse('$cleanRoot$cleanPath');

    if (query != null && query.isNotEmpty) {
      final queryParams = <String, dynamic>{};
      query.forEach((key, value) {
        if (value is List) {
          // PHP/WordPress array style: key[]=value1&key[]=value2
          queryParams['$key[]'] = value.map((e) => e.toString()).toList();
        } else {
          queryParams[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  Future<Map<int, String>> fetchCategories() async {
    final uri = _buildUri(dbUrl, 'categories', {'per_page': '100'});
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load categories');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return {for (var item in data) item['id']: item['name']};
  }

  // UPDATED: query is now optional (defaults to empty string)
  Future<List<Sticker>> searchStickers({
    String query = '',
    List<int>? categoryIds,
    List<String>? searchIn,
  }) async {
    final Map<String, dynamic> params = {
      '_embed': 'true',
      'per_page': '20',
    };

    // Only add search param if text exists
    if (query.trim().isNotEmpty) {
      params['search'] = query.trim();

      // Only apply column filters if we are actually searching text
      if (searchIn != null && searchIn.isNotEmpty) {
        params['search_columns'] = searchIn;
      }
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }

    final uri = _buildUri(dbUrl, 'posts', params);
    debugPrint('Searching Sticker URL: $uri');

    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to search: ${response.statusCode}');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Sticker.fromJson(e)).toList();
  }

  Future<Sticker> fetchTodaysSticker() async {
    final uri = _buildUri(baseUrl, 'posts', {'per_page': '1', '_embed': 'true'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Error');
    final List<dynamic> data = jsonDecode(response.body);
    if (data.isEmpty) throw Exception('Empty');
    return Sticker.fromJson(data[0]);
  }
}