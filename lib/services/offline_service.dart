import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

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

  static Future<bool> hasInternet() async {
    final result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  static Future<void> clearAll() async {
    final db = await database;
    await db.delete('diagnoses');
  }
}
