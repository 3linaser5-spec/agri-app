import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import '../utils/safe_parse.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  // ═══════════════════════════════════════════
  // تهيئة الإشعارات
  // ═══════════════════════════════════════════
  static Future<void> initialize() async {
    // 0. تهيئة الـ timezone (مهمة للجدولة)
    tz.initializeTimeZones();
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
      debugPrint("✅ Timezone: $timeZoneName");
    } catch (e) {
      debugPrint("⚠️ فشل ضبط التوقيت، استخدام القاهرة: $e");
      tz.setLocalLocation(tz.getLocation('Africa/Cairo'));
    }

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

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(const AndroidNotificationChannel(
          'weather_alerts',
          'تنبيهات الطقس',
          description: 'تنبيهات الطقس الزراعية المرسلة عبر Firebase',
          importance: Importance.high,
        ));

    // 3. طلب صلاحيات الإشعارات
    await _requestPermissions();

    // 4. الاستماع للإشعارات من Firebase
    _listenToFirebaseMessages();
  }

  // ═══════════════════════════════════════════
  // طلب الصلاحيات
  // ═══════════════════════════════════════════
  static Future<void> _requestPermissions() async {
    // أندرويد 13+
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();

    // ✅ صلاحية الإشعارات المجدولة الدقيقة (أندرويد 12+)
    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestExactAlarmsPermission();

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

  // ═══════════════════════════════════════════
  // الاستماع للإشعارات
  // ═══════════════════════════════════════════
  static void _listenToFirebaseMessages() {
    // الإشعارات اللي بتيجي والتطبيق مفتوح
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("📩 إشعار جديد (التطبيق مفتوح): ${message.notification?.title}");
      if (message.notification != null) {
        final title = message.notification!.title ?? 'تنبيه';
        final body = message.notification!.body ?? '';
        if (message.data['type'] == 'weather_alert') {
          showWeatherNotification(title: title, body: body);
        } else {
          showLocalNotification(title: title, body: body);
        }
      }
    });

    // الإشعارات اللي بتيجي والتطبيق في الخلفية
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint("📩 تم فتح التطبيق من الإشعار: ${message.notification?.title}");
    });
  }

  // ═══════════════════════════════════════════
  // عرض إشعار محلي (فوري)
  // ═══════════════════════════════════════════
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

  static Future<void> showWeatherNotification({
    required String title,
    required String body,
  }) async {
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'weather_alerts',
        'تنبيهات الطقس',
        channelDescription: 'تنبيهات الطقس الزراعية المرسلة عبر Firebase',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(),
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
    );
  }

  // ═══════════════════════════════════════════
  // معرّفات الإشعارات
  // ═══════════════════════════════════════════
  // كل برنامج له "حصة" من 500 رقم متتالي. الـ hash نفسه ثابت (FNV-1a) عشان
  // String.hashCode مش مضمون يفضل ثابت بين إصدارات Dart، وبالتالي الإلغاء
  // كان ممكن يفوّت إشعارات اتجدولت قبل كده.
  static const int _idStride = 500;
  static const int _idBuckets = 4000;

  static int _stableHash(String input) {
    int hash = 0x811C9DC5;
    for (final unit in input.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return hash;
  }

  static int _baseIdFor(String programId) =>
      (_stableHash(programId) % _idBuckets) * _idStride;

  // الطريقة القديمة (قبل الإصلاح) - بنفضل نلغي بيها برضه للبرامج القديمة
  static int _legacyBaseIdFor(String programId) =>
      programId.hashCode.abs() % 100000;

  // ═══════════════════════════════════════════
  // ✅ جدولة إشعارات مهام البرنامج
  // ═══════════════════════════════════════════
  /// [programId] معرّف البرنامج (بيتحول لـ int كـ base ID)
  /// [programName] اسم البرنامج (اختياري - للعرض في الإشعار)
  /// [startDate] تاريخ بداية البرنامج
  /// [tasks] قائمة المهام، كل مهمة فيها `day_from_start`
  ///
  /// Returns: عدد الإشعارات اللي اتجدولت بنجاح
  static Future<int> scheduleProgramNotifications({
    required String programId,
    String? programName,
    required DateTime startDate,
    required List<Map<String, dynamic>> tasks,
  }) async {
    // base ID ثابت لكل برنامج (عشان نتجنب التعارض)
    final int baseId = _baseIdFor(programId);
    int scheduledCount = 0;

    // لو صلاحية المنبّه الدقيق مرفوضة (أندرويد 12+) الجدولة الدقيقة بترمي خطأ،
    // فنستخدم الجدولة غير الدقيقة بدل ما نفقد كل التذكيرات.
    final androidImpl = _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    bool canExact = true;
    try {
      canExact = await androidImpl?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      canExact = true;
    }
    final scheduleMode = canExact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;

    for (int i = 0; i < tasks.length && i < _idStride; i++) {
      final task = tasks[i];
      final int dayFromStart = SafeParse.integer(task['day_from_start']);
      final String title = task['title']?.toString() ?? 'مهمة';
      final String description =
          task['description']?.toString() ?? 'موعد مهمة في مزرعتك';

      // موعد الإشعار = تاريخ البداية + عدد الأيام (الساعة 8 صباحًا)
      final DateTime scheduledDate = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + dayFromStart,
        8,
        0,
      );

      // تجاهل المهام اللي فات موعدها
      if (scheduledDate.isBefore(DateTime.now())) continue;

      try {
        await _localNotifications.zonedSchedule(
          baseId + i,
          '🌱 $title',
          description,
          tz.TZDateTime.from(scheduledDate, tz.local),
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'farm_tasks',
              'مهام المزرعة',
              channelDescription: 'تذكيرات بمهام المزرعة',
              importance: Importance.high,
              priority: Priority.high,
              icon: '@mipmap/ic_launcher',
            ),
            iOS: DarwinNotificationDetails(),
          ),
          androidScheduleMode: scheduleMode,
        );
        scheduledCount++;
        debugPrint("✅ تم جدولة: $title (يوم $dayFromStart)");
      } catch (e) {
        debugPrint("❌ فشل جدولة $title:$e");
      }
    }

    debugPrint("📊 إجمالي المجدول: $scheduledCount من ${tasks.length}");
    return scheduledCount;
  }

  // ═══════════════════════════════════════════
  // ✅ إلغاء إشعارات برنامج معيّن
  // ═══════════════════════════════════════════
  static Future<void> cancelProgramNotifications(
    String programId,
    int tasksCount,
  ) async {
    final int baseId = _baseIdFor(programId);
    final int legacyBaseId = _legacyBaseIdFor(programId);

    for (int i = 0; i < tasksCount && i < _idStride; i++) {
      await _localNotifications.cancel(baseId + i);
      // برامج اتجدولت بالنظام القديم
      await _localNotifications.cancel(legacyBaseId + i);
    }
    debugPrint("✅ تم إلغاء $tasksCount إشعار للبرنامج: $programId");
  }

  // ═══════════════════════════════════════════
  // إلغاء كل الإشعارات
  // ═══════════════════════════════════════════
  static Future<void> cancelAll() async {
    await _localNotifications.cancelAll();
    debugPrint("✅ تم إلغاء كل الإشعارات");
  }

  // ═══════════════════════════════════════════
  // Firebase Topics
  // ═══════════════════════════════════════════
  static Future<void> subscribeToPestAlerts() async {
    await FirebaseMessaging.instance.subscribeToTopic('pest_alerts');
    debugPrint("✅ تم الاشتراك في تنبيهات الآفات");
  }

  static Future<void> unsubscribeFromPestAlerts() async {
    await FirebaseMessaging.instance.unsubscribeFromTopic('pest_alerts');
    debugPrint("❌ تم إلغاء الاشتراك من تنبيهات الآفات");
  }

}
