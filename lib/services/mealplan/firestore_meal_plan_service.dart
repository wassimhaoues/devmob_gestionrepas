import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/meal_plan_entry.dart';
import '../../models/meal_slot_type.dart';
import 'firebase_meal_plan_error_mapper.dart';
import 'meal_plan_exception.dart';
import 'meal_plan_service.dart';

class FirestoreMealPlanService implements MealPlanService {
  FirestoreMealPlanService({
    FirebaseFirestore? firestore,
    FirebaseMealPlanErrorMapper? errorMapper,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _errorMapper = errorMapper ?? DefaultFirebaseMealPlanErrorMapper();

  final FirebaseFirestore _firestore;
  final FirebaseMealPlanErrorMapper _errorMapper;

  CollectionReference<Map<String, dynamic>> _entries(String uid) {
    return _firestore.collection('users').doc(uid).collection('mealPlanEntries');
  }

  @override
  Stream<List<MealPlanEntry>> watchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    try {
      return _buildRangeQuery(
        uid: uid,
        startDate: startDate,
        endDate: endDate,
      ).snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => _mapDocToEntry(ownerUid: uid, doc: doc))
            .toList(),
      );
    } catch (error) {
      throw MealPlanException(_errorMapper.map(error));
    }
  }

  @override
  Future<List<MealPlanEntry>> fetchEntries({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final snapshot = await _buildRangeQuery(
        uid: uid,
        startDate: startDate,
        endDate: endDate,
      ).get();

      return snapshot.docs
          .map((doc) => _mapDocToEntry(ownerUid: uid, doc: doc))
          .toList();
    } catch (error) {
      throw MealPlanException(_errorMapper.map(error));
    }
  }

  @override
  Future<void> upsertEntry({
    required String uid,
    required MealPlanEntry entry,
  }) async {
    try {
      if (entry.id.trim().isEmpty) {
        throw ArgumentError('Meal plan entry id is required.');
      }

      await _entries(uid).doc(entry.id).set(<String, dynamic>{
        ...entry.toMap(),
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (error) {
      throw MealPlanException(_errorMapper.map(error));
    }
  }

  @override
  Future<void> deleteEntry({
    required String uid,
    required String entryId,
  }) async {
    try {
      await _entries(uid).doc(entryId).delete();
    } catch (error) {
      throw MealPlanException(_errorMapper.map(error));
    }
  }

  String buildEntryId({
    required DateTime date,
    required MealSlotType slotType,
  }) {
    final normalized = DateTime(date.year, date.month, date.day);
    final y = normalized.year.toString().padLeft(4, '0');
    final m = normalized.month.toString().padLeft(2, '0');
    final d = normalized.day.toString().padLeft(2, '0');
    return '$y$m${d}_${slotType.value}';
  }

  Query<Map<String, dynamic>> _buildRangeQuery({
    required String uid,
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final normalizedStart = _normalizeDate(startDate);
    final normalizedEnd = _normalizeDate(endDate);

    return _entries(uid)
        .where(
          'date',
          isGreaterThanOrEqualTo: normalizedStart.toIso8601String(),
        )
        .where(
          'date',
          isLessThanOrEqualTo: normalizedEnd.toIso8601String(),
        )
        .orderBy('date')
        .orderBy('slotType');
  }

  MealPlanEntry _mapDocToEntry({
    required String ownerUid,
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
  }) {
    return MealPlanEntry.fromMap(
      id: doc.id,
      ownerUid: ownerUid,
      data: _normalizeMap(doc.data()),
    );
  }

  Map<String, dynamic> _normalizeMap(Map<String, dynamic> data) {
    return <String, dynamic>{
      ...data,
      'date': _readDateTime(data['date']).toIso8601String(),
      'createdAt': _readDateTime(data['createdAt']),
      'updatedAt': _readDateTime(data['updatedAt']),
    };
  }

  DateTime _normalizeDate(DateTime value) {
    return DateTime(value.year, value.month, value.day);
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
