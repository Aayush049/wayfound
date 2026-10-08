import 'package:flutter/material.dart';

/// Categories for trip suggestions in Wayfound V1.
/// Must match security rules category list.
const List<String> kSuggestionCategories = [
  'food',
  'sightseeing',
  'stay',
  'transport',
  'other',
];

class SuggestionCategoryInfo {
  final String key;
  final String label;
  final IconData icon;

  const SuggestionCategoryInfo({
    required this.key,
    required this.label,
    required this.icon,
  });
}

const Map<String, SuggestionCategoryInfo> kSuggestionCategoryDetails = {
  'food': SuggestionCategoryInfo(
    key: 'food',
    label: 'Food & Drink',
    icon: Icons.restaurant,
  ),
  'sightseeing': SuggestionCategoryInfo(
    key: 'sightseeing',
    label: 'Sightseeing',
    icon: Icons.attractions,
  ),
  'stay': SuggestionCategoryInfo(key: 'stay', label: 'Stay', icon: Icons.hotel),
  'transport': SuggestionCategoryInfo(
    key: 'transport',
    label: 'Transport',
    icon: Icons.directions_bus,
  ),
  'other': SuggestionCategoryInfo(
    key: 'other',
    label: 'Other',
    icon: Icons.category,
  ),
};

SuggestionCategoryInfo getCategoryInfo(String category) {
  return kSuggestionCategoryDetails[category.toLowerCase().trim()] ??
      kSuggestionCategoryDetails['other']!;
}
