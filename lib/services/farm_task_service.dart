import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../models/farm_workspace_models.dart';
import 'notification_service.dart';
import 'offline_farm_store.dart';
import 'offline_outbox.dart';

/// مهام المزرعة وتذكيراتها.
///
/// التخزين في مجموعة `farmTasks` (المستند مملوك لصاحبه عبر `owner_id`)،
/// والتذكيرات تُجدول محليًا على الجهاز. العمل بدون إنترنت مدعوم: القراءة
/// ترجع لآخر نسخة محفوظة، والكتابة تُؤجَّل في طابور حتى رجوع الشبكة.
class FarmTaskService {
  FarmTaskService._();

  static const String collectionName = 'farmTasks';
  static String get _cacheKey =>
      'tasks_${FirebaseAuth.instance.currentUser?.uid ?? 'guest'}';

  static CollectionReference<Map<String, dynamic>> get _collection =>
      FirebaseFirestore.instance.collection(collectionName);

  static String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  /// تحميل كل مهام المستخدم (الأحدث موعدًا أولًا)، مع مزامنة أي عمليات مؤجلة.
  static Future<List<FarmTask>> loadTasks() async {
    final uid = _uid;
    if (uid == null) return const [];
    await OfflineFarmStore.flush();
    return OfflineFarmStore.cachedList<FarmTask>(
      key: _cacheKey,
      fetch: () async {
        final snapshot =
            await _collection.where('owner_id', isEqualTo: uid).get();
        final tasks = snapshot.docs
            .map((doc) => FarmTask.fromMap(doc.id, doc.data()))
            .toList(growable: false);
        tasks.sort((a, b) => a.dueAt.compareTo(b.dueAt));
        return tasks;
      },
      toJson: (task) => {'id': task.id, ...task.toMap()},
      fromJson: (json) => FarmTask.fromMap(
        json['id']?.toString() ?? '',
        json,
      ),
    );
  }

  /// إضافة مهمة، وجدولة تذكيرها لو كان مفعّلًا وموعدها في المستقبل.
  static Future<FarmTask?> addTask(FarmTask task) async {
    final uid = _uid;
    if (uid == null) return null;
    final reference = _collection.doc();
    final stored = FarmTask(
      id: reference.id,
      ownerId: uid,
      plotId: task.plotId,
      title: task.title,
      notes: task.notes,
      dueAt: task.dueAt,
      repeat: task.repeat,
      reminderEnabled: task.reminderEnabled,
    );
    final written = await OfflineFarmStore.write(
      collection: collectionName,
      docId: reference.id,
      type: OfflineOperationType.set,
      data: {...stored.toMap(), 'created_at': DateTime.now().toIso8601String()},
    );
    if (written && stored.reminderEnabled) {
      await scheduleReminder(stored);
    }
    return stored;
  }

  /// تعليم مهمة كمنجزة. المهمة المتكررة تنتقل لموعدها التالي بدل أن تختفي.
  static Future<FarmTask> completeTask(FarmTask task) async {
    final now = DateTime.now();
    final next = task.nextOccurrenceAfter(now);
    final updated = next == null
        ? task.copyWith(done: true, lastCompletedAt: now)
        : task.copyWith(
            dueAt: next,
            done: false,
            lastCompletedAt: now,
          );
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: task.id,
      type: OfflineOperationType.update,
      data: {
        'done': updated.done,
        'due_at': updated.dueAt.toIso8601String(),
        'last_completed_at': now.toIso8601String(),
      },
    );
    await NotificationService.cancelFarmTaskReminder(task.id);
    if (updated.reminderEnabled) await scheduleReminder(updated);
    return updated;
  }

  /// إرجاع مهمة منجزة إلى قائمة المهام.
  static Future<FarmTask> reopenTask(FarmTask task) async {
    final updated = task.copyWith(done: false);
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: task.id,
      type: OfflineOperationType.update,
      data: {'done': false},
    );
    if (updated.reminderEnabled) await scheduleReminder(updated);
    return updated;
  }

  static Future<void> deleteTask(FarmTask task) async {
    await OfflineFarmStore.write(
      collection: collectionName,
      docId: task.id,
      type: OfflineOperationType.delete,
    );
    await NotificationService.cancelFarmTaskReminder(task.id);
  }

  /// جدولة تذكير المهمة (الساعة 8 صباحًا افتراضيًا أو وقت الموعد).
  static Future<void> scheduleReminder(FarmTask task) async {
    if (!task.reminderEnabled || task.done) return;
    final at = task.dueAt.isBefore(DateTime.now())
        ? DateTime.now().add(const Duration(minutes: 1))
        : task.dueAt;
    await NotificationService.scheduleFarmTaskReminder(
      taskId: task.id,
      title: task.title,
      body: task.notes.isEmpty ? 'مهمة مزرعة مستحقة اليوم' : task.notes,
      at: at,
    );
  }

  /// إعادة جدولة كل المهام القادمة (تُستدعى بعد تسجيل الدخول أو فتح الشاشة).
  static Future<int> rescheduleAll() async {
    try {
      final tasks = await loadTasks();
      var count = 0;
      for (final task in tasks) {
        if (task.done || !task.reminderEnabled) continue;
        if (task.dueAt.isBefore(DateTime.now())) continue;
        await scheduleReminder(task);
        count++;
      }
      return count;
    } catch (error) {
      debugPrint('تعذر إعادة جدولة تذكيرات المهام: $error');
      return 0;
    }
  }

  /// نسخة محلية نقية من قائمة المهام للاختبار والعرض السريع.
  static List<FarmTask> sortForToday(List<FarmTask> tasks, DateTime now) {
    final copy = List<FarmTask>.of(tasks);
    copy.sort((a, b) {
      final aDone = a.done ? 1 : 0;
      final bDone = b.done ? 1 : 0;
      if (aDone != bDone) return aDone.compareTo(bDone);
      return a.dueAt.compareTo(b.dueAt);
    });
    return copy;
  }
}
