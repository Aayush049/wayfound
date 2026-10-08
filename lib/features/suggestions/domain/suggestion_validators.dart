import '../../../core/money.dart';
import 'suggestion_category.dart';

class SuggestionValidators {
  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter a title.';
    }
    final trimmed = value.trim();
    if (trimmed.length > 80) {
      return 'Title must be 80 characters or fewer.';
    }
    return null;
  }

  static String? validateNote(String? value) {
    if (value == null) return null;
    if (value.length > 500) {
      return 'Note must be 500 characters or fewer.';
    }
    return null;
  }

  static String? validateCategory(String? value) {
    if (value == null ||
        !kSuggestionCategories.contains(value.toLowerCase().trim())) {
      return 'Please select a valid category.';
    }
    return null;
  }

  static String? validateCostInput(String? value, String currencyCode) {
    if (value == null || value.trim().isEmpty) return null;
    try {
      parseMinorUnits(value, currencyCode);
      return null;
    } on FormatException catch (e) {
      return e.message;
    }
  }
}
