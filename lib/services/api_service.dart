import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/sticker.dart';
import 'preferences_service.dart';
import 'widget_service.dart';
import 'package:html_unescape/html_unescape.dart';

class StickerIndexItem {
  final int id;
  final String hebrewName;
  final String englishName;
  // FIX 1: Add this field to store the category IDs
  final List<int> categoryIds;

  StickerIndexItem({
    required this.id,
    required this.hebrewName,
    required this.englishName,
    required this.categoryIds,
  });

  factory StickerIndexItem.fromJson(Map<String, dynamic> json) {
    var unescape = HtmlUnescape();

    String heName = '';
    if (json['title'] != null && json['title']['rendered'] != null) {
      heName = unescape.convert(json['title']['rendered'].toString());
    }

    String enName = '';
    if (json['meta'] != null && json['meta']['name_in_english'] != null) {
      enName = unescape.convert(json['meta']['name_in_english'].toString());
    }

    // FIX 2: Safely parse categories.
    // If the API sends null (which happens if '_fields' is missing), we use []
    List<int> cats = [];

    // 2. Check if key exists and is actually a list
    if (json['categories'] != null && json['categories'] is List) {
      // 3. Convert safely
      cats = List<int>.from(json['categories']);
    }

    return StickerIndexItem(
      id: json['id'],
      hebrewName: heName,
      englishName: enName,
      categoryIds: cats, // Pass the safe list
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

  Future<void> fetchStickerIndex({
    required Function(List<StickerIndexItem>) onBatchLoaded,
  }) async {
    int page = 1;
    bool hasMore = true;

    while (hasMore) {
      final uri = _buildUri(dbUrl, 'posts', {
        'per_page': '100',
        'page': page.toString(),
        'status': 'publish',
        '_fields': 'id,title,meta,categories',
      });

      try {
        final response = await http.get(uri);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          if (data.isEmpty) {
            hasMore = false;
          } else {
            final items = data.map((json) => StickerIndexItem.fromJson(json)).toList();
            onBatchLoaded(items);
            page++;
          }
        } else {
          hasMore = false;
        }
      } catch (e) {
        debugPrint('Error fetching index page $page: $e');
        hasMore = false;
      }
    }
  }

  Future<List<Sticker>> getStickersByIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final uri = _buildUri(dbUrl, 'posts', {
      '_embed': 'true',
      'include': ids.join(','),
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
    if (response.statusCode != 200) throw Exception('Failed to load categories');
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
    if (query.isNotEmpty && english.hasMatch(query.split(' ')[0])){
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

    if (searchIn != null && searchIn.isNotEmpty) {
      params['search_columns'] = searchIn;
    }

    final uri = _buildUri(dbUrl, 'posts', params);

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

  // Future<List<int>> _fetchAllStickerIds() async {
  //   final uri = _buildUri(dbUrl, 'posts', {
  //     '_fields': 'id',
  //     'per_page': '100',
  //     'status': 'publish',
  //   });
  //
  //   final response = await http.get(uri);
  //   if (response.statusCode != 200) throw Exception('Failed to fetch IDs');
  //
  //   final List<dynamic> data = jsonDecode(response.body);
  //   return data.map<int>((e) => e['id'] as int).toList();
  // }

  // Future<Sticker> _fetchStickerById(int id) async {
  //   final uri = _buildUri(dbUrl, 'posts/$id', {'_embed': 'true'});
  //   final response = await http.get(uri);
  //   if (response.statusCode != 200) throw Exception('Failed to fetch sticker details');
  //
  //   return Sticker.fromJson(jsonDecode(response.body));
  // }

  Future<Sticker> getDailySticker(
      PreferencesService prefs,
      WidgetService widgetService, {
        bool forceRefresh = false, // <--- NEW PARAMETER
      }) async {
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final lastDate = prefs.dailyDate;
    final currentId = prefs.dailyStickerId;

    // 1. Return cached sticker if valid and not forcing refresh
    if (!forceRefresh && lastDate == todayString && currentId != null) {
      if (prefs.isStickerInPool(currentId)) {
        return prefs.getStickerPool().firstWhere((s) => s.id == currentId);
      }
      try {
        return await _fetchStickerById(currentId);
      } catch (e) {
        debugPrint('Error fetching saved daily sticker: $e');
      }
    }

    // 2. Generate New Sticker
    Sticker newSticker;

    // Check Preference
    if (prefs.stickerSource == 'pool') {
      final pool = prefs.getStickerPool();
      if (pool.isNotEmpty) {
        // Pick random from pool
        newSticker = pool[Random().nextInt(pool.length)];
      } else {
        // Fallback to web
        newSticker = await _fetchRandomFromWeb(prefs);
      }
    } else {
      // Web strategy
      newSticker = await _fetchRandomFromWeb(prefs);
    }

    // 3. Save & Update
    await prefs.setDailySticker(newSticker.id, todayString);
    await widgetService.updateStickerWidget(newSticker);

    return newSticker;
  }


  Future<Sticker> _fetchRandomFromWeb(PreferencesService prefs) async {
    final allIds = await _fetchAllStickerIds();
    if (allIds.isEmpty) throw Exception('No stickers found in database');

    final seenIds = prefs.seenStickerIds.map(int.parse).toSet();
    List<int> availableIds = allIds.where((id) => !seenIds.contains(id)).toList();

    if (availableIds.isEmpty) {
      await prefs.clearHistory();
      availableIds = allIds;
    }

    final randomId = availableIds[Random().nextInt(availableIds.length)];
    return await _fetchStickerById(randomId);
  }

  // ... (Ensure _fetchAllStickerIds and _fetchStickerById are present in the class) ...
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


  // Helper for the original Web Logic
  // Future<Sticker> _fetchRandomFromWeb(PreferencesService prefs) async {
  //   final allIds = await _fetchAllStickerIds();
  //   if (allIds.isEmpty) throw Exception('No stickers found in database');
  //
  //   final seenIds = prefs.seenStickerIds.map(int.parse).toSet();
  //
  //   // Filter out seen ones
  //   List<int> availableIds = allIds.where((id) => !seenIds.contains(id)).toList();
  //
  //   // Reset history if all seen
  //   if (availableIds.isEmpty) {
  //     await prefs.clearHistory();
  //     availableIds = allIds;
  //   }
  //
  //   final randomId = availableIds[Random().nextInt(availableIds.length)];
  //   return await _fetchStickerById(randomId);
  // }
}