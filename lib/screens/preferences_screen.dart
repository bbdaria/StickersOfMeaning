import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/preferences_service.dart';
import '../models/sticker_category.dart';

class PreferencesScreen extends StatelessWidget {
  static const String routeName = '/preferences';

  const PreferencesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final prefs = context.watch<PreferencesService>();
    final api = context.read<ApiService>();

    return Scaffold(
      appBar: AppBar(title: const Text('Preferences')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Language',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          RadioListTile<AppLanguage>(
            title: const Text('Hebrew'),
            value: AppLanguage.hebrew,
            groupValue: prefs.language,
            onChanged: (value) {
              if (value != null) {
                prefs.setLanguage(value);
              }
            },
          ),
          RadioListTile<AppLanguage>(
            title: const Text('English'),
            value: AppLanguage.english,
            groupValue: prefs.language,
            onChanged: (value) {
              if (value != null) {
                prefs.setLanguage(value);
              }
            },
          ),
          const Divider(height: 32),
          const Text(
            'Sticker-categories',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            prefs.selectedCategoryIds.isEmpty
                ? 'All categories are selected'
                : 'Filtering by ${prefs.selectedCategoryIds.length} categories',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<StickerCategory>>(
            future: api.fetchCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasError) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(
                    'Could not load categories:${snapshot.error}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                );
              }
              final categories = snapshot.data ?? [];
              if (categories.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Text('No categories returned from the server'),
                );
              }

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: prefs.selectedCategoryIds.isEmpty,
                    onSelected: (_) {
                      prefs.setSelectedCategoryIds(<int>{});
                    },
                  ),
                  ...categories.map((c) {
                    final selected = prefs.selectedCategoryIds.contains(c.id);
                    return FilterChip(
                      label: Text(c.name),
                      selected: selected,
                      onSelected: (_) {
                        prefs.toggleCategory(c.id);
                      },
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
