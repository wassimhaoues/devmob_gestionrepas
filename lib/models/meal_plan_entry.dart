import 'meal_slot_type.dart';
import 'recipe_category.dart';

class MealPlanEntry {
  const MealPlanEntry({
    required this.id,
    required this.ownerUid,
    required this.date,
    required this.slotType,
    required this.recipeId,
    required this.recipeTitle,
    required this.createdAt,
    required this.updatedAt,
    this.recipeImageUrl,
    this.recipeCategory,
  });

  final String id;
  final String ownerUid;
  final DateTime date;
  final MealSlotType slotType;
  final String recipeId;
  final String recipeTitle;
  final String? recipeImageUrl;
  final RecipeCategory? recipeCategory;
  final DateTime createdAt;
  final DateTime updatedAt;

  MealPlanEntry copyWith({
    String? id,
    String? ownerUid,
    DateTime? date,
    MealSlotType? slotType,
    String? recipeId,
    String? recipeTitle,
    Object? recipeImageUrl = _sentinel,
    Object? recipeCategory = _sentinel,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MealPlanEntry(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      date: date ?? this.date,
      slotType: slotType ?? this.slotType,
      recipeId: recipeId ?? this.recipeId,
      recipeTitle: recipeTitle ?? this.recipeTitle,
      recipeImageUrl: identical(recipeImageUrl, _sentinel)
          ? this.recipeImageUrl
          : recipeImageUrl as String?,
      recipeCategory: identical(recipeCategory, _sentinel)
          ? this.recipeCategory
          : recipeCategory as RecipeCategory?,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'date': DateTime.utc(date.year, date.month, date.day).toIso8601String(),
      'slotType': slotType.value,
      'recipeId': recipeId,
      'recipeTitle': recipeTitle,
      'recipeImageUrl': recipeImageUrl,
      'recipeCategory': recipeCategory?.value,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static String buildId({
    required DateTime date,
    required MealSlotType slotType,
    required String recipeId,
  }) {
    final normalized = DateTime(date.year, date.month, date.day);
    final y = normalized.year.toString().padLeft(4, '0');
    final m = normalized.month.toString().padLeft(2, '0');
    final d = normalized.day.toString().padLeft(2, '0');
    return '$y$m${d}_${slotType.value}_${recipeId.trim()}';
  }

  factory MealPlanEntry.fromMap({
    required String id,
    required String ownerUid,
    required Map<String, dynamic> data,
  }) {
    final recipeId = (data['recipeId'] as String? ?? '').trim();
    final recipeTitle = (data['recipeTitle'] as String? ?? '').trim();
    if (recipeId.isEmpty) {
      throw const FormatException(
        'Meal plan entry is missing a valid recipeId field.',
      );
    }
    if (recipeTitle.isEmpty) {
      throw const FormatException(
        'Meal plan entry is missing a valid recipeTitle field.',
      );
    }

    final categoryValue = (data['recipeCategory'] as String?)?.trim();

    return MealPlanEntry(
      id: id,
      ownerUid: ownerUid,
      date: _readDateOnly(data['date']),
      slotType: MealSlotType.fromValue(data['slotType'] as String? ?? ''),
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      recipeImageUrl: (data['recipeImageUrl'] as String?)?.trim(),
      recipeCategory: categoryValue == null || categoryValue.isEmpty
          ? null
          : RecipeCategory.fromValue(categoryValue),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  static DateTime _readDateOnly(Object? value) {
    final date = _readDateTime(value);
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _readDateTime(Object? value) {
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

const Object _sentinel = Object();
