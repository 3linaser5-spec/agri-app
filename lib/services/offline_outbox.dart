import 'dart:convert';

/// نوع عملية مكتوبة في طابور المزامنة.
enum OfflineOperationType { set, update, delete }

/// عملية كتابة مؤجلة تُنفَّذ عند رجوع الإنترنت.
class OfflineOperation {
  final String collection;
  final String docId;
  final OfflineOperationType type;
  final Map<String, dynamic>? data;
  final DateTime createdAt;

  const OfflineOperation({
    required this.collection,
    required this.docId,
    required this.type,
    this.data,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() => {
        'collection': collection,
        'doc_id': docId,
        'type': type.name,
        'data': data,
        'created_at': createdAt.toIso8601String(),
      };

  static OfflineOperation? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final collection = raw['collection']?.toString() ?? '';
    final docId = raw['doc_id']?.toString() ?? '';
    if (collection.isEmpty || docId.isEmpty) return null;
    final type = OfflineOperationType.values.firstWhere(
      (value) => value.name == raw['type']?.toString(),
      orElse: () => OfflineOperationType.set,
    );
    final data = raw['data'];
    return OfflineOperation(
      collection: collection,
      docId: docId,
      type: type,
      data: data is Map ? Map<String, dynamic>.from(data) : null,
      createdAt: DateTime.tryParse(raw['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// طابور كتابات محلي نقي (بدون Firebase) حتى يمكن اختباره مباشرة.
class OfflineOutbox {
  final List<OfflineOperation> operations;

  OfflineOutbox([Iterable<OfflineOperation> initial = const []])
      : operations = List.of(initial);

  int get length => operations.length;

  bool get isEmpty => operations.isEmpty;

  /// إضافة عملية؛ آخر كتابة لنفس المستند تستبدل السابقة، والحذف يلغي أي
  /// كتابة سابقة لنفس المستند.
  void add(OfflineOperation operation) {
    operations.removeWhere((item) =>
        item.collection == operation.collection &&
        item.docId == operation.docId);
    if (operation.type != OfflineOperationType.delete) {
      operations.add(operation);
    }
  }

  void removeAt(int index) {
    if (index >= 0 && index < operations.length) operations.removeAt(index);
  }

  void clear() => operations.clear();

  String encode() => jsonEncode(
        operations.map((item) => item.toMap()).toList(growable: false),
      );

  static OfflineOutbox decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return OfflineOutbox();
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return OfflineOutbox();
      return OfflineOutbox(
        decoded.map(OfflineOperation.fromMap).whereType<OfflineOperation>(),
      );
    } catch (_) {
      return OfflineOutbox();
    }
  }
}
