import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/recipe.dart';
import '../../models/recipe_category.dart';
import 'recipe_service.dart';

class FirestoreRecipeService implements RecipeService {
  FirestoreRecipeService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> _recipes(String uid) {
    return _firestore.collection('users').doc(uid).collection('recipes');
  }

  @override
  Stream<List<Recipe>> watchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) {
    Query<Map<String, dynamic>> query = _recipes(uid);
    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }
    if (favoritesOnly) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    query = query.orderBy('updatedAt', descending: true);

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => _mapDocToRecipe(ownerUid: uid, doc: doc))
          .toList(),
    );
  }

  @override
  Future<List<Recipe>> fetchRecipes({
    required String uid,
    RecipeCategory? category,
    bool favoritesOnly = false,
  }) async {
    Query<Map<String, dynamic>> query = _recipes(uid);
    if (category != null) {
      query = query.where('category', isEqualTo: category.value);
    }
    if (favoritesOnly) {
      query = query.where('isFavorite', isEqualTo: true);
    }

    query = query.orderBy('updatedAt', descending: true);
    final snapshot = await query.get();
    return snapshot.docs
        .map((doc) => _mapDocToRecipe(ownerUid: uid, doc: doc))
        .toList();
  }

  @override
  Future<Recipe?> fetchRecipeById({
    required String uid,
    required String recipeId,
  }) async {
    final snapshot = await _recipes(uid).doc(recipeId).get();
    if (!snapshot.exists) {
      return null;
    }

    final data = snapshot.data();
    if (data == null) {
      return null;
    }

    return Recipe.fromMap(
      id: snapshot.id,
      ownerUid: uid,
      data: _normalizeRecipeMap(data),
    );
  }

  @override
  Future<String> createRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    final docRef = _recipes(uid).doc();
    await docRef.set(<String, dynamic>{
      ...recipe.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  @override
  Future<void> updateRecipe({
    required String uid,
    required Recipe recipe,
  }) async {
    final recipeId = recipe.id.trim();
    if (recipeId.isEmpty) {
      throw ArgumentError('Recipe id is required for update.');
    }

    await _recipes(uid).doc(recipeId).update(<String, dynamic>{
      ...recipe.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> deleteRecipe({
    required String uid,
    required String recipeId,
  }) async {
    await _recipes(uid).doc(recipeId).delete();
  }

  @override
  Future<void> setFavorite({
    required String uid,
    required String recipeId,
    required bool isFavorite,
  }) async {
    await _recipes(uid).doc(recipeId).update(<String, dynamic>{
      'isFavorite': isFavorite,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Recipe _mapDocToRecipe({
    required String ownerUid,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    return Recipe.fromMap(
      id: doc.id,
      ownerUid: ownerUid,
      data: _normalizeRecipeMap(doc.data()),
    );
  }

  Map<String, dynamic> _normalizeRecipeMap(Map<String, dynamic> data) {
    return <String, dynamic>{
      ...data,
      'createdAt': _readDateTime(data['createdAt']),
      'updatedAt': _readDateTime(data['updatedAt']),
    };
  }

  DateTime _readDateTime(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}
