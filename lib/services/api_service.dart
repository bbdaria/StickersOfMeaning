import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sticker.dart';
import 'preferences_service.dart';
import 'widget_service.dart';

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
          queryParams['$key[]'] = value.map((e) => e.toString()).toList();
        } else {
          queryParams[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: queryParams);
    }

    return uri;
  }

  // --- Original Methods (Restored) ---

  Future<Map<int, String>> fetchCategories() async {
    final uri = _buildUri(dbUrl, 'categories', {'per_page': '100'});
    final response = await http.get(uri);

    if (response.statusCode != 200) {
      throw Exception('Failed to load categories');
    }

    final List<dynamic> data = jsonDecode(response.body);
    return {for (var item in data) item['id']: item['name']};
  }

  Future<List<Sticker>> searchStickers({
    String query = '',
    List<int>? categoryIds,
    List<String>? searchIn,
  }) async {
    final Map<String, dynamic> params = {
      '_embed': 'true',
      'per_page': '20',
      'status': 'publish',
      if(query.isNotEmpty) 'search': query,
    };

    if (query.trim().isNotEmpty) {
      params['search'] = query.trim();
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }

    final uri = _buildUri(dbUrl, 'posts', params);
    debugPrint('Searching Sticker URL: $uri');

    final response = await http.get(uri);
    debugPrint('Response Status Code: ${response.body}');
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

  // --- New Daily Sticker Logic ---

  Future<List<int>> _fetchAllStickerIds() async {
    final uri = _buildUri(dbUrl, 'posts', {
      '_fields': 'id',
      'per_page': '100',
      'status': 'publish',
    });

    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Failed to fetch IDs');

    final List<dynamic> data = jsonDecode(response.body);
    return data.map<int>((e) => e['id'] as int).toList();
  }

  Future<Sticker> _fetchStickerById(int id) async {
    final uri = _buildUri(dbUrl, 'posts/$id', {'_embed': 'true'});
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Failed to fetch sticker details');

    return Sticker.fromJson(jsonDecode(response.body));
  }

  Future<Sticker> getDailySticker(
      PreferencesService prefs,
      WidgetService widgetService
      ) async {
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final lastDate = prefs.dailyDate;
    final currentId = prefs.dailyStickerId;

    // 1. If same day, return saved sticker
    if (lastDate == todayString && currentId != null) {
      try {
        return await _fetchStickerById(currentId);
      } catch (e) {
        debugPrint('Error fetching saved daily sticker: $e');
      }
    }

    // 2. New day or error: pick new unique sticker
    final allIds = await _fetchAllStickerIds();
    if (allIds.isEmpty) throw Exception('No stickers found in database');

    final seenIds = prefs.seenStickerIds.map(int.parse).toSet();

    List<int> availableIds = allIds.where((id) => !seenIds.contains(id)).toList();

    if (availableIds.isEmpty) {
      await prefs.clearHistory();
      availableIds = allIds;
    }

    final randomId = availableIds[Random().nextInt(availableIds.length)];
    final newSticker = await _fetchStickerById(randomId);

    await prefs.setDailySticker(randomId, todayString);
    await widgetService.updateStickerWidget(newSticker);

    return newSticker;
  }
}