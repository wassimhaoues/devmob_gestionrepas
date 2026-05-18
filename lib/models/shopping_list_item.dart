class ShoppingListItem {
  const ShoppingListItem({
    required this.id,
    required this.canonicalName,
    required this.displayName,
    required this.totalQuantity,
    required this.unit,
    required this.isChecked,
    required this.sourceRecipeIds,
  });

  final String id;
  final String canonicalName;
  final String displayName;
  final double totalQuantity;
  final String unit;
  final bool isChecked;
  final List<String> sourceRecipeIds;

  ShoppingListItem copyWith({
    String? id,
    String? canonicalName,
    String? displayName,
    double? totalQuantity,
    String? unit,
    bool? isChecked,
    List<String>? sourceRecipeIds,
  }) {
    return ShoppingListItem(
      id: id ?? this.id,
      canonicalName: canonicalName ?? this.canonicalName,
      displayName: displayName ?? this.displayName,
      totalQuantity: totalQuantity ?? this.totalQuantity,
      unit: unit ?? this.unit,
      isChecked: isChecked ?? this.isChecked,
      sourceRecipeIds: sourceRecipeIds ?? this.sourceRecipeIds,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'canonicalName': canonicalName,
      'displayName': displayName,
      'totalQuantity': totalQuantity,
      'unit': unit,
      'isChecked': isChecked,
      'sourceRecipeIds': sourceRecipeIds,
    };
  }

  factory ShoppingListItem.fromMap(Map<String, dynamic> data) {
    return ShoppingListItem(
      id: (data['id'] as String? ?? '').trim(),
      canonicalName: (data['canonicalName'] as String? ?? '').trim(),
      displayName: (data['displayName'] as String? ?? '').trim(),
      totalQuantity: _readDouble(data['totalQuantity']),
      unit: (data['unit'] as String? ?? '').trim(),
      isChecked: data['isChecked'] as bool? ?? false,
      sourceRecipeIds: _readStringList(data['sourceRecipeIds']),
    );
  }

  static String buildId({required String canonicalName, required String unit}) {
    final normalizedName = canonicalName.trim().toLowerCase();
    final normalizedUnit = unit.trim().toLowerCase();
    return '${normalizedName}__$normalizedUnit';
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
}
