class RecipeStep {
  const RecipeStep({
    required this.order,
    required this.text,
  });

  final int order;
  final String text;

  RecipeStep copyWith({
    int? order,
    String? text,
  }) {
    return RecipeStep(
      order: order ?? this.order,
      text: text ?? this.text,
    );
  }

  factory RecipeStep.fromMap(Map<String, dynamic> data) {
    return RecipeStep(
      order: _readInt(data['order']),
      text: (data['text'] as String? ?? '').trim(),
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'order': order,
      'text': text,
    };
  }

  static int _readInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    if (value is String) {
      return int.tryParse(value) ?? 0;
    }
    return 0;
  }
}
