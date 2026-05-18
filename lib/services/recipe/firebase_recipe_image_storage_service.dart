import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

import '../../models/recipe_image_upload_result.dart';
import 'recipe_image_storage_service.dart';

class FirebaseRecipeImageStorageService implements RecipeImageStorageService {
  FirebaseRecipeImageStorageService({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  final FirebaseStorage _storage;

  @override
  String buildStoragePath({
    required String uid,
    required String recipeId,
    String fileName = 'cover.webp',
  }) {
    return 'users/$uid/recipes/$recipeId/$fileName';
  }

  @override
  Future<RecipeImageUploadResult> uploadRecipeImage({
    required String uid,
    required String recipeId,
    required Uint8List bytes,
    required String mimeType,
    String fileName = 'cover.webp',
  }) async {
    final storagePath = buildStoragePath(
      uid: uid,
      recipeId: recipeId,
      fileName: fileName,
    );
    final ref = _storage.ref(storagePath);

    final metadata = SettableMetadata(
      contentType: mimeType,
      customMetadata: <String, String>{'ownerUid': uid, 'recipeId': recipeId},
    );

    await ref.putData(bytes, metadata);
    final downloadUrl = await ref.getDownloadURL();

    return RecipeImageUploadResult(
      downloadUrl: downloadUrl,
      storagePath: storagePath,
      mimeType: mimeType,
      sizeBytes: bytes.lengthInBytes,
    );
  }

  @override
  Future<void> deleteRecipeImage(String storagePath) async {
    if (storagePath.trim().isEmpty) {
      return;
    }

    await _storage.ref(storagePath).delete();
  }
}
