import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kDebugMode, debugPrint;

import '../firebase_options.dart';
import '../services/notification_service.dart';
import '../services/weather_push_service.dart';

/// يهيئ Firebase ويرجّع null لو نجح، أو نص الخطأ لو فشل (عشان يتعرض للمستخدم).
///
/// مشترك بين نقطة الدخول وشاشة إعادة المحاولة عند فشل التهيئة.
Future<String?> initFirebase() async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      debugPrint("Firebase initialization error: $e");
      return e.toString();
    }
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
    return e.toString();
  }

  try {
    await FirebaseAppCheck.instance.activate(
      providerAndroid: kDebugMode
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
    );
  } catch (e) {
    debugPrint("تحذير أثناء تفعيل App Check: $e");
  }

  try {
    WeatherPushService.initialize();
    await NotificationService.initialize();
  } catch (e) {
    debugPrint("خطأ في تهيئة الإشعارات: $e");
  }
  return null;
}
