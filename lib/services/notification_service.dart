import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // تهيئة الإشعارات
  static Future<void> initialize() async {
    // 1. إعدادات الأندرويد
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 2. إعدادات iOS
    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const InitializationSettings settings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings,
      onDidReceiveNotificationResponse: (response) {
        debugPrint("📩 تم الضغط على الإشعار: ${response.payload}");
      },
    );

    // 3. طلب صلاحيات الإشعارات
    await _requestPermissions();

    // 4. الاستماع للإشعارات من Firebase
    _listenToFirebaseMessages();
  }

  // طلب الصلاحيات
  static Future<void> _requestPermissions() async {
    // أندرويد 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // Firebase Messaging
    NotificationSettings firebaseSettings =
        await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (firebaseSettings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint("✅ صلاحيات الإشعارات مفعلة");
    }
  }

  // الاستماع للإشعارات
  static void _listenToFirebaseMessages() {
    // الإشعارات اللي بتيجي والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 إشعار جديد (التطبيق مفتوح): ${message.notification?.title}");
      if (message.notification != null) {
        showLocalNotification(
          title: message.notification!.title ?? 'تنبيه',
          body: message.notification!.body ?? '',
        );
      }
    });

    // الإشعارات اللي بتيجي والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📩 تم فتح التطبيق من الإشعار: ${message.notification?.title}");
    });
  }

  // عرض إشعار محلي
  static Future<void> showLocalNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'pest_alerts',
      'تنبيهات الآفات',
      channelDescription: 'إشعارات لتنبيه المزارع بظهور آفات في منطقته',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // الاشتراك في موضوع (Topic) لاستقبال تنبيهات الآفات
  static Future<void> subscribeToPestAlerts() async {
    await FirebaseMessaging.instance.subscribeToTopic('pest_alerts');
    debugPrint("✅ تم الاشتراك في تنبيهات الآفات");
  }

  // إلغاء الاشتراك
  static Future<void> unsubscribeFromPestAlerts() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic('pest_alerts');
    debugPrint("❌ تم إلغاء الاشتراك من تنبيهات الآفات");
  }

  // الحصول على التوكن
  static Future<String?> getToken() async {
    return await FirebaseMessaging.instance.getToken();
  }
}
