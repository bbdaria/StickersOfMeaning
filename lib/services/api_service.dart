import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sticker.dart';
import 'preferences_service.dart';
import 'widget_service.dart';
import 'package:flutter/foundation.dart';
import 'package:html_unescape/html_unescape.dart';



class StickerIndexItem {
  final int id;
  final String hebrewName;
  final String englishName;

  StickerIndexItem({required this.id, required this.hebrewName, required this.englishName});

  factory StickerIndexItem.fromJson(Map<String, dynamic> json) {
    var unescape = HtmlUnescape(); // Ensure you have this import

    String heName = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      heName = unescape.convert(json['title']['rendered'].toString());
    }

    String enName = '';
    if (json['meta'] != null && json['meta']['name_in_english'] != null) {
      enName = unescape.convert(json['meta']['name_in_english'].toString());
    }

    return StickerIndexItem(
      id: json['id'],
      hebrewName: heName,
      englishName: enName,
    );
  }
}

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

  Future<List<StickerIndexItem>> fetchStickerIndex() async {
    List<StickerIndexItem> allItems = [];
    int page = 1;
    bool hasMore = true;

    // Keep fetching pages until we run out
    while (hasMore) {
      // request only specific fields to keep it fast/small
      final uri = _buildUri(dbUrl, 'posts', {
        'per_page': '100',
        'page': page.toString(),
        'status': 'publish',
        '_fields': 'id,title,meta', // <--- THE MAGIC: Only fetch what we need
      });

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (data.isEmpty) {
            hasMore = false;
          } else {
            // Parse and add to list
            final items = data.map((json) => StickerIndexItem.fromJson(json)).toList();
            allItems.addAll(items);
            page++;
          }
        } else {
          // If 400 (Bad Request), usually means page number is out of range
          hasMore = false;
        }
      } catch (e) {
        debugPrint('Error fetching index page $page: $e');
        hasMore = false;
      }
    }
    return allItems;
  }

  Future<List<Sticker>> getStickersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];

    final uri = _buildUri(dbUrl, 'posts', {
      '_embed': 'true',
      'include': ids.join(','), // <--- Fetch only these specific matches
      'per_page': '100',
    });

    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((e) => Sticker.fromJson(e)).toList();
    } else {
      throw Exception('Failed to load specific stickers');
    }
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

  Future<List<Sticker>> searchStickers({
    String query = '',
    List<int>? categoryIds,
    List<String>? searchIn,
  }) async {
    var english = RegExp(r'[a-zA-Z]');
    var searchKey = 'search';
    if (english.hasMatch(query.split(' ')[0])){
      searchKey += '_en';
    }

    final Map<String, dynamic> params = {
      '_embed': 'true',
      'per_page': '20',
      'status': 'publish',
      if(query.isNotEmpty) searchKey: query,
    };

    if (query.trim().isNotEmpty) {
      params[searchKey] = query.trim();
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }

    // --- FIX: Add Search Columns Support ---
    if (searchIn != null && searchIn.isNotEmpty) {
      // Note: This requires WordPress 5.0+
      params['search_columns'] = searchIn;
    }
    // ---------------------------------------

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