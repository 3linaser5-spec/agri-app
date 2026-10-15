import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class OfflineService {
  static Database? _db;

  static Future<Database> get database async {
    if (_db != null) return _db!;
    _db = await _initDB();
    return _db!;
  }

  static Future<Database> _initDB() async {
    String dbPath = join(await getDatabasesPath(), 'agri_offline.db');
    return await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE diagnoses (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            userName TEXT,
            userPhone TEXT,
            question TEXT,
            imagePath TEXT,
            diagnosis TEXT,
            isSynced INTEGER DEFAULT 0,
            createdAt TEXT
          )
        ''');
      },
    );
  }

  static Future<int> saveDiagnosis({
    required String userName,
    required String userPhone,
    required String question,
    String? imagePath,
    required String diagnosis,
  }) async {
    final db = await database;
    return await db.insert('diagnoses', {
      'userName': userName,
      'userPhone': userPhone,
      'question': question,
      'imagePath': imagePath,
      'diagnosis': diagnosis,
      'isSynced': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Map<String, dynamic>>> getAllDiagnoses() async {
    final db = await database;
    return await db.query('diagnoses', orderBy: 'createdAt DESC');
  }

  // ✅ دالة جديدة: جلب التشخيصات اللي لسه متزامنتش
  static Future<List<Map<String, dynamic>>> getUnsyncedDiagnoses() async {
    final db = await database;
    return await db.query('diagnoses',
        where: 'isSynced = ?', whereArgs: [0]);
  }

  // ✅ دالة جديدة: تحديث حالة التشخيص لـ "متزامن"
  static Future<void> markAsSynced(int id) async {
    final db = await database;
    await db.update('diagnoses', {'isSynced': 1},
        where: 'id = ?', whereArgs: [id]);
  }

  // ✅ دالة جديدة: مسح تشخيص واحد بالـ id
  static Future<void> deleteDiagnosis(int id) async {
    final db = await database;
    await db.delete('diagnoses', where: 'id = ?', whereArgs: [id]);
  }

  // ✅ دالة جديدة: مزامنة كل التشخيصات المعلقة مع Firestore
  static bool _syncing = false;

  static Future<int> syncPendingDiagnoses() async {
    // قفل: مستمع الاتصال ممكن يشغّل المزامنة أكتر من مرة في نفس الوقت
    // وده كان بيرفع نفس التشخيص مرتين لـ Firestore
    if (_syncing) return 0;
    _syncing = true;
    try {
      // 1. نتأكد إن في نت
      final hasNet = await hasInternet();
      if (!hasNet) {
        debugPrint("⚠️ لا يوجد إنترنت، لن تتم المزامنة");
        return 0;
      }

      // 2. نجيب كل التشخيصات اللي لسه متزامنتش
      final pending = await getUnsyncedDiagnoses();
      if (pending.isEmpty) {
        debugPrint("✅ لا يوجد تشخيصات معلقة");
        return 0;
      }

      debugPrint("🔄 جاري مزامنة ${pending.length} تشخيص...");

      int successCount = 0;

      // لازم مستخدم مسجّل: قواعد Firestore بتربط كل تشخيص بصاحبه
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        debugPrint("⚠️ لا يوجد مستخدم مسجّل، لن تتم المزامنة");
        return 0;
      }

      // 3. نرفع كل واحد لـ Firestore
      for (var item in pending) {
        try {
          // معرّف ثابت للمستند: لو الرفع نجح لكن markAsSynced فشل، إعادة
          // المحاولة بتكتب نفس المستند بدل ما تعمل نسخة مكررة.
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
            // imagePath اتشال: مسار محلي على الجهاز ملوش قيمة على السيرفر
            'diagnosis': item['diagnosis'],
            'createdAt': item['createdAt'],
            'syncedAt': FieldValue.serverTimestamp(),
          });

          // 4. نحدّث حالته لـ "متزامن"
          await markAsSynced(item['id'] as int);
          successCount++;
          debugPrint("✅ تمت مزامنة تشخيص رقم ${item['id']}");
        } catch (e) {
          debugPrint("❌ فشلت مزامنة التشخيص رقم ${item['id']}: $e");
        }
      }

      debugPrint("🎉 تمت مزامنة $successCount من ${pending.length}");
      return successCount;
    } catch (e) {
      debugPrint("❌ خطأ في المزامنة: $e");
      return 0;
    } finally {
      _syncing = false;
    }
  }

  static Future<bool> hasInternet() async {
    // connectivity_plus 6.x يرجّع List<ConnectivityResult> وليس قيمة واحدة
    final result = await Connectivity().checkConnectivity();
    return result.isNotEmpty && !result.contains(ConnectivityResult.none);
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('diagnoses');
  }
}
