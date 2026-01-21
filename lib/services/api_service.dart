import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:html_unescape/html_unescape.dart';
import '../models/sticker.dart';
import 'preferences_service.dart';
import 'widget_service.dart';

class StickerIndexItem {
  final int id;
  final String hebrewName;
  final String englishName;
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
    List<int> cats = [];
    if (json['categories'] != null && json['categories'] is List) {
      cats = List<int>.from(json['categories']);
    }

    return StickerIndexItem(
      id: json['id'],
      hebrewName: heName,
      englishName: enName,
      categoryIds: cats,
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
    var searchKey = 'search';
    final Map<String, dynamic> params = {
      '_embed': 'true',
      'per_page': '20',
      'status': 'publish',
      if(query.isNotEmpty) searchKey: query,
    };
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }
    final uri = _buildUri(dbUrl, 'posts', params);
    final response = await http.get(uri);
    if (response.statusCode != 200) throw Exception('Failed to search');
    final List<dynamic> data = jsonDecode(response.body);
    return data.map((e) => Sticker.fromJson(e)).toList();
  }

  Future<Sticker> getDailySticker(
      PreferencesService prefs,
      WidgetService widgetService, {
        bool forceRefresh = false,
      }) async {
    final now = DateTime.now();
    final todayString = "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";

    final lastDate = prefs.dailyDate;
    final currentId = prefs.dailyStickerId;

    Sticker homeSticker;
    bool shouldUpdateWidget = false;

    if (!forceRefresh && lastDate == todayString && currentId != null) {
      try {
        if (prefs.isStickerInPool(currentId)) {
          homeSticker = prefs.getStickerPool().firstWhere((s) => s.id == currentId);
        } else {
          homeSticker = await _fetchStickerById(currentId);
        }
      } catch (e) {
        debugPrint('Error fetching cached home sticker, fetching new: $e');
        homeSticker = await _fetchRandomFromWeb(prefs, null);
        await prefs.setDailySticker(homeSticker.id, todayString);
        shouldUpdateWidget = true;
      }
    } else {
      homeSticker = await _fetchRandomFromWeb(prefs, null);
      await prefs.setDailySticker(homeSticker.id, todayString);
      shouldUpdateWidget = true;
    }
    if (shouldUpdateWidget) {
      await updateWidgetContent(prefs, widgetService, candidateSticker: homeSticker);
    }

    return homeSticker;
  }

  Future<void> updateWidgetContent(
      PreferencesService prefs,
      WidgetService widgetService,
      {Sticker? candidateSticker}
      ) async {
    Sticker widgetSticker;
    final filters = prefs.dailyFilterCategories;

    try {
      if (prefs.stickerSource == 'pool') {
        List<Sticker> pool = prefs.getStickerPool();
        if (filters.isNotEmpty) {
          pool = pool.where((s) => s.categories.any((c) => filters.contains(c))).toList();
        }

        if (pool.isNotEmpty) {
          widgetSticker = pool[Random().nextInt(pool.length)];
        } else {
          widgetSticker = await _fetchRandomFromWeb(prefs, filters);
        }
      } else {
        if (filters.isNotEmpty) {
          widgetSticker = await _fetchRandomFromWeb(prefs, filters);
        } else {
          widgetSticker = candidateSticker ?? await _fetchRandomFromWeb(prefs, null);
        }
      }
      await prefs.setWidgetStickerId(widgetSticker.id);
      await widgetService.updateStickerWidget(widgetSticker);
    } catch (e) {
      debugPrint('Failed to update widget content: $e');
    }
  }

  Future<Sticker> _fetchRandomFromWeb(PreferencesService prefs, List<int>? categoryIds) async {
    final allIds = await _fetchStickerIds(categoryIds: categoryIds);
    if (allIds.isEmpty) throw Exception('No stickers found');

    final seenIds = prefs.seenStickerIds.map(int.parse).toSet();
    List<int> availableIds = allIds.where((id) => !seenIds.contains(id)).toList();

    if (availableIds.isEmpty) {
      if (categoryIds == null || categoryIds.isEmpty) {
        await prefs.clearHistory();
      }
      availableIds = allIds;
    }

    final randomId = availableIds[Random().nextInt(availableIds.length)];
    return await _fetchStickerById(randomId);
  }

  Future<List<int>> _fetchStickerIds({List<int>? categoryIds}) async {
    final params = {
      '_fields': 'id',
      'per_page': '100',
      'status': 'publish',
    };
    if (categoryIds != null && categoryIds.isNotEmpty) {
      params['categories'] = categoryIds.join(',');
    }

    final uri = _buildUri(dbUrl, 'posts', params);
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

  Future<void> safeRemoveFromPool(BuildContext context, int id) async {
    final prefs = context.read<PreferencesService>();
    final widgetService = context.read<WidgetService>();
    final isWidgetTarget = (id == prefs.widgetStickerId);
    final isPoolMode = (prefs.stickerSource == 'pool');

    await prefs.removeFromPool(id);

    if (isWidgetTarget && isPoolMode) {
      // Check if pool became empty
      if (prefs
          .getStickerPool()
          .isEmpty) {
        // Switch to Web so future random refreshes actually work
        await prefs.setStickerSource('web');

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(prefs.getLabel('collection_empty')),
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    }
  }
}