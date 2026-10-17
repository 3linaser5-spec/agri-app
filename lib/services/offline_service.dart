import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static Database? _db;

  static String? get _currentUid => FirebaseAuth.instance.currentUser?.uid;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    final dbPath = join(await getDatabasesPath(), 'agri_offline.db');
    return openDatabase(
      dbPath,
      version: 3,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diagnoses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ownerUid TEXT NOT NULL,
            userName TEXT,
            userPhone TEXT,
            question TEXT,
            imagePath TEXT,
            diagnosis TEXT,
            analysisPending INTEGER NOT NULL DEFAULT 0,
            isSynced INTEGER DEFAULT 0,
            createdAt TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // السجلات السابقة لا تحتوي هوية مالك موثوقة؛ تظل معزولة وغير قابلة
          // للعرض أو المزامنة بدلاً من نسبها إلى أول حساب يسجل الدخول.
          await db.execute('ALTER TABLE diagnoses ADD COLUMN ownerUid TEXT');
        }
        if (oldVersion < 3) {
          await db.execute(
            'ALTER TABLE diagnoses ADD COLUMN analysisPending INTEGER NOT NULL DEFAULT 0',
          );
        }
      },
    );
  }

  static Future<int> saveDiagnosis({
    required String userName,
    required String userPhone,
    required String question,
    String? imagePath,
    required String diagnosis,
    bool analysisPending = false,
  }) async {
    final uid = _currentUid;
    if (uid == null) {
      throw StateError('يجب تسجيل الدخول قبل حفظ التشخيص.');
    }
    final db = await database;
    return db.insert('diagnoses', {
      'ownerUid': uid,
      'userName': userName,
      'userPhone': userPhone,
      'question': question,
      'imagePath': imagePath,
      'diagnosis': diagnosis,
      'analysisPending': analysisPending ? 1 : 0,
      'isSynced': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllDiagnoses() async {
    final uid = _currentUid;
    if (uid == null) return [];
    final db = await database;
    return db.query(
      'diagnoses',
      where: 'ownerUid = ?',
      whereArgs: [uid],
      orderBy: 'createdAt DESC',
    );
  }

  static Future<List<Map<String, dynamic>>> getUnsyncedDiagnoses() async {
    final uid = _currentUid;
    if (uid == null) return [];
    final db = await database;
    return db.query(
      'diagnoses',
      where: 'ownerUid = ? AND isSynced = ? AND analysisPending = ?',
      whereArgs: [uid, 0, 0],
      orderBy: 'createdAt ASC',
    );
  }

  static Future<void> markAsSynced(int id) async {
    final uid = _currentUid;
    if (uid == null) return;
    final db = await database;
    await db.update(
      'diagnoses',
      {'isSynced': 1},
      where: 'id = ? AND ownerUid = ?',
      whereArgs: [id, uid],
    );
  }

  static Future<void> deleteDiagnosis(int id) async {
    final uid = _currentUid;
    if (uid == null) return;
    final db = await database;
    await db.delete(
      'diagnoses',
      where: 'id = ? AND ownerUid = ?',
      whereArgs: [id, uid],
    );
  }

  static bool _syncing = false;

  static Future<int> syncPendingDiagnoses() async {
    if (_syncing) return 0;
    _syncing = true;
    try {
      final uid = _currentUid;
      if (uid == null) {
        debugPrint('⚠️ لا يوجد مستخدم مسجّل، لن تتم المزامنة');
        return 0;
      }
      if (!await hasInternet()) {
        debugPrint('⚠️ لا يوجد إنترنت، لن تتم المزامنة');
        return 0;
      }

      // getUnsyncedDiagnoses يقصر الصفوف على مالكها ويستبعد الطلبات
      // التي لم تُحلّل بعد، كي لا تُرفع رسالة placeholder كتشخيص نهائي.
      final pending = await getUnsyncedDiagnoses();
      if (pending.isEmpty) return 0;

      var successCount = 0;
      for (final item in pending) {
        try {
          if (item['ownerUid'] != uid) continue;
          final stamp = (item['createdAt'] ?? '')
              .toString()
              .replaceAll(RegExp(r'[^0-9]'), '');
          final docId = '${uid}_${item['id']}_$stamp';

          await FirebaseFirestore.instance
              .collection('diagnoses')
              .doc(docId)
              .set({
            'uid': uid,
            'userName': item['userName'],
            'userPhone': item['userPhone'],
            'question': item['question'],
            'diagnosis': item['diagnosis'],
            'createdAt': item['createdAt'],
            'syncedAt': FieldValue.serverTimestamp(),
          });

          await markAsSynced(item['id'] as int);
          successCount++;
        } catch (e) {
          debugPrint('❌ فشلت مزامنة التشخيص رقم ${item['id']}: $e');
        }
      }
      return successCount;
    } catch (e) {
      debugPrint('❌ خطأ في المزامنة: $e');
      return 0;
    } finally {
      _syncing = false;
    }
  }

  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  static Future<void> clearAll() async {
    final uid = _currentUid;
    if (uid == null) return;
    final db = await database;
    await db.delete('diagnoses', where: 'ownerUid = ?', whereArgs: [uid]);
  }
}
