enum ShoppingListItemStatus { pending, completed }

enum ShoppingListItemOrigin { generated, reopened }

class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.ingredientKey,
    required this.canonicalName,
    required this.displayName,
    required this.totalQuantity,
    required this.unit,
    required this.status,
    required this.origin,
    required this.isNewBatch,
    required this.sourceRecipeIds,
    required this.createdAt,
    this.completedAt,
  });

  final String id;
  final String ingredientKey;
  final String canonicalName;
  final String displayName;
  final double totalQuantity;
  final String unit;
  final ShoppingListItemStatus status;
  final ShoppingListItemOrigin origin;
  final bool isNewBatch;
  final List<String> sourceRecipeIds;
  final DateTime createdAt;
  final DateTime? completedAt;

  bool get isChecked => status == ShoppingListItemStatus.completed;
  bool get isGenerated => origin == ShoppingListItemOrigin.generated;

  ShoppingListItem copyWith({
    String? id,
    String? ingredientKey,
    String? canonicalName,
    String? displayName,
    double? totalQuantity,
    String? unit,
    ShoppingListItemStatus? status,
    ShoppingListItemOrigin? origin,
    bool? isNewBatch,
    List<String>? sourceRecipeIds,
    DateTime? createdAt,
    Object? completedAt = _sentinel,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      ingredientKey: ingredientKey ?? this.ingredientKey,
      canonicalName: canonicalName ?? this.canonicalName,
      displayName: displayName ?? this.displayName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      unit: unit ?? this.unit,
      status: status ?? this.status,
      origin: origin ?? this.origin,
      isNewBatch: isNewBatch ?? this.isNewBatch,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
      createdAt: createdAt ?? this.createdAt,
      completedAt: identical(completedAt, _sentinel)
          ? this.completedAt
          : completedAt as DateTime?,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'ingredientKey': ingredientKey,
      'canonicalName': canonicalName,
      'displayName': displayName,
      'totalQuantity': totalQuantity,
      'unit': unit,
      'status': status.name,
      'origin': origin.name,
      'isNewBatch': isNewBatch,
      'sourceRecipeIds': sourceRecipeIds,
      'createdAt': createdAt.toIso8601String(),
      'completedAt': completedAt?.toIso8601String(),
    };
  }

  factory ShoppingListItem.fromMap(Map<String, dynamic> data) {
    final id = (data['id'] as String? ?? '').trim();
    final ingredientKey = (data['ingredientKey'] as String?)?.trim();
    final canonicalName = (data['canonicalName'] as String? ?? '').trim();
    final unit = (data['unit'] as String? ?? '').trim();

    return ShoppingListItem(
      id: id,
      ingredientKey: ingredientKey == null || ingredientKey.isEmpty
          ? _fallbackIngredientKey(
              id: id,
              canonicalName: canonicalName,
              unit: unit,
            )
          : ingredientKey,
      canonicalName: canonicalName,
      displayName: (data['displayName'] as String? ?? '').trim(),
      totalQuantity: _readDouble(data['totalQuantity']),
      unit: unit,
      status: _readStatus(data['status'], data['isChecked']),
      origin: _readOrigin(data['origin']),
      isNewBatch: data['isNewBatch'] as bool? ?? false,
      sourceRecipeIds: _readStringList(data['sourceRecipeIds']),
      createdAt: _readDateTime(data['createdAt']),
      completedAt: _readNullableDateTime(data['completedAt']),
    );
  }

  static String buildIngredientKey({
    required String canonicalName,
    required String unit,
  }) {
    final normalizedName = canonicalName.trim().toLowerCase();
    final normalizedUnit = unit.trim().toLowerCase();
    return '${normalizedName}__$normalizedUnit';
  }

  static String buildId({required String canonicalName, required String unit}) {
    return buildIngredientKey(canonicalName: canonicalName, unit: unit);
  }

  static String buildBatchId({
    required String ingredientKey,
    required ShoppingListItemStatus status,
    required ShoppingListItemOrigin origin,
    required DateTime timestamp,
  }) {
    final millis = timestamp.millisecondsSinceEpoch;
    return '${status.name}_${origin.name}_${ingredientKey}_$millis';
  }

  static ShoppingListItemStatus _readStatus(Object? value, Object? isChecked) {
    final normalized = (value as String? ?? '').trim();
    if (normalized == ShoppingListItemStatus.completed.name) {
      return ShoppingListItemStatus.completed;
    }
    if (normalized == ShoppingListItemStatus.pending.name) {
      return ShoppingListItemStatus.pending;
    }
    return isChecked == true
        ? ShoppingListItemStatus.completed
        : ShoppingListItemStatus.pending;
  }

  static ShoppingListItemOrigin _readOrigin(Object? value) {
    final normalized = (value as String? ?? '').trim();
    if (normalized == ShoppingListItemOrigin.reopened.name) {
      return ShoppingListItemOrigin.reopened;
    }
    return ShoppingListItemOrigin.generated;
  }

  static String _fallbackIngredientKey({
    required String id,
    required String canonicalName,
    required String unit,
  }) {
    if (canonicalName.isNotEmpty && unit.isNotEmpty) {
      return buildIngredientKey(canonicalName: canonicalName, unit: unit);
    }
    return id;
  }

  static double _readDouble(Object? value) {
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      return double.tryParse(value) ?? 0;
    }
    return 0;
  }

  static List<String> _readStringList(Object? value) {
    if (value is! List) {
      return const <String>[];
    }

    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
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

  static DateTime? _readNullableDateTime(Object? value) {
    if (value == null) {
      return null;
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }
}

const Object _sentinel = Object();
