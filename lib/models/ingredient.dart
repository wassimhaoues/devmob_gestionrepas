class Ingredient {
  const Ingredient({
    required this.displayName,
    required this.canonicalName,
    required this.quantity,
    required this.unit,
  });

  final String displayName;
  final String canonicalName;
  final double quantity;
  final String unit;

  Ingredient copyWith({
    String? displayName,
    String? canonicalName,
    double? quantity,
    String? unit,
  }) {
    return Ingredient(
      displayName: displayName ?? this.displayName,
      canonicalName: canonicalName ?? this.canonicalName,
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
    );
  }

  factory Ingredient.fromMap(Map<String, dynamic> data) {
    return Ingredient(
      displayName: (data['displayName'] as String? ?? '').trim(),
      canonicalName: (data['canonicalName'] as String? ?? '').trim(),
      quantity: _readDouble(data['quantity']),
      unit: (data['unit'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'displayName': displayName,
      'canonicalName': canonicalName,
      'quantity': quantity,
      'unit': unit,
    };
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
}
