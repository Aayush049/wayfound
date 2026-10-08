import 'package:cloud_firestore/cloud_firestore.dart';

class Suggestion {
  final String id;
  final String tripId;
  final String title;
  final String note;
  final int? estimatedCost;
  final String category;
  final String authorId;
  final int upCount;
  final int downCount;
  final String status;
  final int? dayIndex;
  final int? order;
  final DateTime createdAt;

  const Suggestion({
    required this.id,
    required this.tripId,
    required this.title,
    required this.note,
    this.estimatedCost,
    required this.category,
    required this.authorId,
    required this.upCount,
    required this.downCount,
    required this.status,
    this.dayIndex,
    this.order,
    required this.createdAt,
  });

  int get score => upCount - downCount;

  factory Suggestion.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
    String tripId,
  ) {
    final data = doc.data() ?? {};
    final createdAtRaw = data['createdAt'];
    DateTime parsedCreatedAt;
    if (createdAtRaw is Timestamp) {
      parsedCreatedAt = createdAtRaw.toDate();
    } else if (createdAtRaw is String) {
      parsedCreatedAt = DateTime.tryParse(createdAtRaw) ?? DateTime.now();
    } else {
      parsedCreatedAt = DateTime.now();
    }

    return Suggestion(
      id: doc.id,
      tripId: tripId,
      title: data['title'] as String? ?? '',
      note: data['note'] as String? ?? '',
      estimatedCost: (data['estimatedCost'] as num?)?.toInt(),
      category: data['category'] as String? ?? 'other',
      authorId: data['authorId'] as String? ?? '',
      upCount: (data['upCount'] as num?)?.toInt() ?? 0,
      downCount: (data['downCount'] as num?)?.toInt() ?? 0,
      status: data['status'] as String? ?? 'pending',
      dayIndex: (data['dayIndex'] as num?)?.toInt(),
      order: (data['order'] as num?)?.toInt(),
      createdAt: parsedCreatedAt,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'note': note,
      'estimatedCost': estimatedCost,
      'category': category,
      'authorId': authorId,
      'upCount': upCount,
      'downCount': downCount,
      'status': status,
      'dayIndex': dayIndex,
      'order': order,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Suggestion copyWith({
    String? id,
    String? tripId,
    String? title,
    String? note,
    int? estimatedCost,
    String? category,
    String? authorId,
    int? upCount,
    int? downCount,
    String? status,
    int? dayIndex,
    int? order,
    DateTime? createdAt,
  }) {
    return Suggestion(
      id: id ?? this.id,
      tripId: tripId ?? this.tripId,
      title: title ?? this.title,
      note: note ?? this.note,
      estimatedCost: estimatedCost ?? this.estimatedCost,
      category: category ?? this.category,
      authorId: authorId ?? this.authorId,
      upCount: upCount ?? this.upCount,
      downCount: downCount ?? this.downCount,
      status: status ?? this.status,
      dayIndex: dayIndex ?? this.dayIndex,
      order: order ?? this.order,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
