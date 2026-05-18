import 'shopping_list_item.dart';

class ShoppingList {
  const ShoppingList({
    required this.ownerUid,
    required this.weekStartDate,
    required this.generatedAt,
    required this.items,
  });

  final String ownerUid;
  final DateTime weekStartDate;
  final DateTime generatedAt;
  final List<ShoppingListItem> items;

  ShoppingList copyWith({
    String? ownerUid,
    DateTime? weekStartDate,
    DateTime? generatedAt,
    List<ShoppingListItem>? items,
  }) {
    return ShoppingList(
      ownerUid: ownerUid ?? this.ownerUid,
      weekStartDate: weekStartDate ?? this.weekStartDate,
      generatedAt: generatedAt ?? this.generatedAt,
      items: items ?? this.items,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'ownerUid': ownerUid,
      'weekStartDate': weekStartDate.toIso8601String(),
      'generatedAt': generatedAt.toIso8601String(),
      'items': items.map((item) => item.toMap()).toList(),
    };
  }

  factory ShoppingList.fromMap(Map<String, dynamic> data) {
    return ShoppingList(
      ownerUid: (data['ownerUid'] as String? ?? '').trim(),
      weekStartDate: _readDateTime(data['weekStartDate']),
      generatedAt: _readDateTime(data['generatedAt']),
      items: _readItems(data['items']),
    );
  }

  static List<ShoppingListItem> _readItems(Object? value) {
    if (value is! List) {
      return const <ShoppingListItem>[];
    }

    return value
        .whereType<Map>()
        .map(
          (item) => ShoppingListItem.fromMap(
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
