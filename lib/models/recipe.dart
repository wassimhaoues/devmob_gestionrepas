import 'ingredient.dart';
import 'recipe_category.dart';
import 'recipe_step.dart';

class Recipe {
  const Recipe({
    required this.id,
    required this.ownerUid,
    required this.title,
    required this.description,
    required this.category,
    required this.isFavorite,
    required this.ingredients,
    required this.steps,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
    this.imageStoragePath,
  });

  final String id;
  final String ownerUid;
  final String title;
  final String description;
  final RecipeCategory category;
  final bool isFavorite;
  final List<Ingredient> ingredients;
  final List<RecipeStep> steps;
  final String? imageUrl;
  final String? imageStoragePath;
  final DateTime createdAt;
  final DateTime updatedAt;

  Recipe copyWith({
    String? id,
    String? ownerUid,
    String? title,
    String? description,
    RecipeCategory? category,
    bool? isFavorite,
    List<Ingredient>? ingredients,
    List<RecipeStep>? steps,
    String? imageUrl,
    String? imageStoragePath,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Recipe(
      id: id ?? this.id,
      ownerUid: ownerUid ?? this.ownerUid,
      title: title ?? this.title,
      description: description ?? this.description,
      category: category ?? this.category,
      isFavorite: isFavorite ?? this.isFavorite,
      ingredients: ingredients ?? this.ingredients,
      steps: steps ?? this.steps,
      imageUrl: imageUrl ?? this.imageUrl,
      imageStoragePath: imageStoragePath ?? this.imageStoragePath,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Recipe.fromMap({
    required String id,
    required String ownerUid,
    required Map<String, dynamic> data,
  }) {
    return Recipe(
      id: id,
      ownerUid: ownerUid,
      title: (data['title'] as String? ?? '').trim(),
      description: (data['description'] as String? ?? '').trim(),
      category: RecipeCategory.fromValue(
        (data['category'] as String? ?? '').trim(),
      ),
      isFavorite: data['isFavorite'] as bool? ?? false,
      ingredients: _readIngredients(data['ingredients']),
      steps: _readSteps(data['steps']),
      imageUrl: (data['imageUrl'] as String?)?.trim(),
      imageStoragePath: (data['imageStoragePath'] as String?)?.trim(),
      createdAt: _readDateTime(data['createdAt']),
      updatedAt: _readDateTime(data['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'category': category.value,
      'isFavorite': isFavorite,
      'ingredients': ingredients
          .map((ingredient) => ingredient.toMap())
          .toList(),
      'steps': steps.map((step) => step.toMap()).toList(),
      'imageUrl': imageUrl,
      'imageStoragePath': imageStoragePath,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  static List<Ingredient> _readIngredients(Object? value) {
    if (value is! List) {
      return const <Ingredient>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => Ingredient.fromMap(
            item.map(
              (key, dynamic itemValue) => MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList();
  }

  static List<RecipeStep> _readSteps(Object? value) {
    if (value is! List) {
      return const <RecipeStep>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => RecipeStep.fromMap(
            item.map(
              (key, dynamic itemValue) => MapEntry(key.toString(), itemValue),
            ),
          ),
        )
        .toList();
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
