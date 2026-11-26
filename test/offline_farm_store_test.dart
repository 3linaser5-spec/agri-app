import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/services/offline_outbox.dart';

void main() {
  OfflineOperation operation({
    String docId = 'doc-1',
    OfflineOperationType type = OfflineOperationType.set,
    Map<String, dynamic>? data,
  }) =>
      OfflineOperation(
        collection: 'farmTasks',
        docId: docId,
        type: type,
        data: data,
        createdAt: DateTime(2026, 11, 26, 10),
      );

  test('keeps the latest write for the same document', () {
    final outbox = OfflineOutbox()
      ..add(operation(data: {'title': 'قديم'}))
      ..add(operation(data: {'title': 'جديد'}));
    expect(outbox.length, 1);
    expect(outbox.operations.single.data!['title'], 'جديد');
  });

  test('a delete cancels any pending write for that document', () {
    final outbox = OfflineOutbox()
      ..add(operation())
      ..add(operation(type: OfflineOperationType.delete));
    expect(outbox.isEmpty, isTrue);
  });

  test('operations on different documents are all kept', () {
    final outbox = OfflineOutbox()
      ..add(operation(docId: 'a'))
      ..add(operation(docId: 'b'));
    expect(outbox.length, 2);
  });

  test('removeAt ignores out-of-range indexes', () {
    final outbox = OfflineOutbox()..add(operation());
    outbox.removeAt(5);
    expect(outbox.length, 1);
    outbox.removeAt(0);
    expect(outbox.isEmpty, isTrue);
  });

  test('encodes and decodes the queue, skipping corrupt entries', () {
    final outbox = OfflineOutbox()
      ..add(operation(data: {'title': 'ري'}))
      ..add(operation(
        docId: 'doc-2',
        type: OfflineOperationType.delete,
      ))
      ..add(operation(
        docId: 'doc-2',
        type: OfflineOperationType.update,
        data: {'done': true},
      ));
    final restored = OfflineOutbox.decode(outbox.encode());
    expect(restored.length, 2);
    expect(restored.operations.first.data!['title'], 'ري');
    expect(restored.operations.last.type, OfflineOperationType.update);
    expect(restored.operations.last.data!['done'], true);

    expect(OfflineOutbox.decode(null).isEmpty, isTrue);
    expect(OfflineOutbox.decode('not json').isEmpty, isTrue);
    expect(OfflineOutbox.decode('[{"doc_id":"x"}]').isEmpty, isTrue);
  });

  test('unknown operation types fall back to set', () {
    final restored = OfflineOutbox.decode(
      '[{"collection":"farmTasks","doc_id":"d","type":"weird"}]',
    );
    expect(restored.operations.single.type, OfflineOperationType.set);
  });
}
