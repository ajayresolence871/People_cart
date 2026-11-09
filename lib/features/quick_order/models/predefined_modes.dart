import 'package:flutter/material.dart';
import '../../../models/product.dart';
import 'quick_order_mode.dart';

class PredefinedModeTemplate {
  final String id;
  final String name;
  final String iconName;
  final IconData iconData;
  final String tagline;
  final List<String> targetKeywords;
  final Map<String, int> keywordQuantities;

  const PredefinedModeTemplate({
    required this.id,
    required this.name,
    required this.iconName,
    required this.iconData,
    required this.tagline,
    required this.targetKeywords,
    this.keywordQuantities = const {},
  });

  /// Resolves this predefined template against the real Supabase products catalog
  QuickOrderMode resolve(List<Product> catalog) {
    final List<QuickOrderItem> matchedItems = [];
    final Set<String> addedProductIds = {};

    for (final keyword in targetKeywords) {
      final lowerKey = keyword.toLowerCase();
      // Find real matching products in catalog
      final matches = catalog.where((p) {
        if (addedProductIds.contains(p.id)) return false;
        final nameMatch = p.name.toLowerCase().contains(lowerKey);
        final descMatch = p.description?.toLowerCase().contains(lowerKey) ?? false;
        return nameMatch || descMatch;
      }).toList();

      if (matches.isNotEmpty) {
        final chosen = matches.first;
        addedProductIds.add(chosen.id);
        final defaultQty = keywordQuantities[lowerKey] ?? 1;

        matchedItems.add(
          QuickOrderItem(
            productId: chosen.id,
            quantity: defaultQty,
            product: chosen,
            customTitle: chosen.name,
          ),
        );
      }
    }

    return QuickOrderMode(
      id: id,
      name: name,
      iconName: iconName,
      tagline: tagline,
      isPredefined: true,
      items: matchedItems,
      targetKeywords: targetKeywords,
    );
  }
}

class PredefinedModesCatalog {
  static const List<PredefinedModeTemplate> templates = [
    PredefinedModeTemplate(
      id: 'predefined_essentials',
      name: 'Essentials',
      iconName: 'essentials',
      iconData: Icons.shopping_basket_rounded,
      tagline: 'Atta, cooking oil, potato, onion & kitchen staples',
      targetKeywords: ['potato', 'tomato', 'oil', 'atta', 'rice', 'coriander', 'chilli'],
      keywordQuantities: {'potato': 1, 'tomato': 1, 'atta': 1, 'oil': 1},
    ),
    PredefinedModeTemplate(
      id: 'predefined_breakfast',
      name: 'Breakfast',
      iconName: 'breakfast',
      iconData: Icons.breakfast_dining_rounded,
      tagline: 'Fresh milk, brown bread, bananas & morning fuel',
      targetKeywords: ['milk', 'bread', 'banana', 'egg', 'tea', 'butter'],
      keywordQuantities: {'milk': 2, 'bread': 1, 'banana': 1},
    ),
    PredefinedModeTemplate(
      id: 'predefined_snacks',
      name: 'Snacks',
      iconName: 'snacks',
      iconData: Icons.fastfood_rounded,
      tagline: 'Crispy curly turns, chips, party mix & chilled sips',
      targetKeywords: ['turns', 'chip', 'mix', 'juice', 'cookie', 'biscuit'],
      keywordQuantities: {'turns': 2, 'chip': 2, 'juice': 1},
    ),
    PredefinedModeTemplate(
      id: 'predefined_emergency',
      name: 'Emergency Top-up',
      iconName: 'emergency',
      iconData: Icons.bolt_rounded,
      tagline: 'Ran out of milk or bread? Quick 1-tap re-stock',
      targetKeywords: ['milk', 'bread', 'curd', 'egg'],
      keywordQuantities: {'milk': 1, 'bread': 1},
    ),
    PredefinedModeTemplate(
      id: 'predefined_gym',
      name: 'Gym Protein',
      iconName: 'gym',
      iconData: Icons.fitness_center_rounded,
      tagline: 'Bananas, fresh milk, peanut butter & healthy bites',
      targetKeywords: ['banana', 'milk', 'egg', 'paneer', 'oats'],
      keywordQuantities: {'banana': 2, 'milk': 2},
    ),
    PredefinedModeTemplate(
      id: 'predefined_movie',
      name: 'Movie Time',
      iconName: 'movie',
      iconData: Icons.movie_creation_rounded,
      tagline: 'Ice cream cups, chips, snacks & cold beverages',
      targetKeywords: ['ice cream', 'cup', 'turns', 'chip', 'orange'],
      keywordQuantities: {'ice cream': 2, 'turns': 1, 'chip': 1},
    ),
  ];

  static List<QuickOrderMode> resolveAll(List<Product> catalog) {
    final List<QuickOrderMode> resolved = [];
    for (final template in templates) {
      final mode = template.resolve(catalog);
      // Only include mode if it contains at least 1 real product from the store
      if (mode.items.isNotEmpty) {
        resolved.add(mode);
      }
    }
    return resolved;
  }
}
