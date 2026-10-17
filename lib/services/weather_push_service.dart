import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeatherPushPermissionDenied implements Exception {
  const WeatherPushPermissionDenied();
}

/// Registers this signed-in installation for server-generated farm weather alerts.
/// The FCM token is owner-scoped, unreadable by clients, and paired with a
/// rounded (~1 km) location only after the user explicitly opts in.
class WeatherPushService {
  WeatherPushService._();

  static const _timeout = Duration(seconds: 15);
  static StreamSubscription<String>? _tokenRefreshSubscription;

  static void initialize() {
    if (_tokenRefreshSubscription != null) return;
    _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_saveRefreshedToken(token)),
      onError: (Object error) {
        debugPrint('FCM token refresh failed: $error');
      },
    );
  }

  static String _enabledKey(String uid) => 'weather_push_enabled_$uid';
  static String _tokenKey(String uid) => 'weather_push_token_$uid';
  static String _latitudeKey(String uid) => 'weather_push_lat_$uid';
  static String _longitudeKey(String uid) => 'weather_push_lon_$uid';

  static CollectionReference<Map<String, dynamic>> _devices(String uid) =>
      FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('weather_push_devices');

  static double _roundedCoordinate(double value) =>
      double.parse(value.toStringAsFixed(2));

  static Future<bool> isEnabled(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_enabledKey(uid)) ?? false;
  }

  static Future<void> syncStoredLocation(String uid) async {
    if (!await isEnabled(uid)) return;
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;

    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble(_latitudeKey(uid));
    final longitude = prefs.getDouble(_longitudeKey(uid));
    if (latitude == null || longitude == null) return;

    await syncLocation(uid: uid, latitude: latitude, longitude: longitude);
  }

  static Future<void> enable({
    required String uid,
    required double latitude,
    required double longitude,
  }) async {
    _validateCoordinates(latitude, longitude);
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('سجّل الدخول من جديد لتفعيل تنبيهات الطقس.');
    }

    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      throw const WeatherPushPermissionDenied();
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) {
      throw StateError('تعذر تسجيل هذا الجهاز في خدمة الإشعارات.');
    }
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('تغير الحساب أثناء تفعيل التنبيهات؛ حاول مرة أخرى.');
    }

    final prefs = await SharedPreferences.getInstance();
    final oldToken = prefs.getString(_tokenKey(uid));
    final roundedLatitude = _roundedCoordinate(latitude);
    final roundedLongitude = _roundedCoordinate(longitude);

    if (oldToken != null && oldToken != token) {
      await _devices(uid).doc(oldToken).delete().timeout(_timeout);
    }
    await prefs.setString(_tokenKey(uid), token);
    await prefs.setDouble(_latitudeKey(uid), roundedLatitude);
    await prefs.setDouble(_longitudeKey(uid), roundedLongitude);
    await prefs.setBool(_enabledKey(uid), true);

    try {
      await _writeRegistration(
        uid: uid,
        token: token,
        latitude: roundedLatitude,
        longitude: roundedLongitude,
      );
    } catch (_) {
      await prefs.setBool(_enabledKey(uid), false);
      rethrow;
    }
  }

  /// Updates the server-side location only when the user opted in.
  static Future<void> syncLocation({
    required String uid,
    required double latitude,
    required double longitude,
  }) async {
    _validateCoordinates(latitude, longitude);
    if (!await isEnabled(uid)) return;
    if (FirebaseAuth.instance.currentUser?.uid != uid) return;

    final prefs = await SharedPreferences.getInstance();
    var token = prefs.getString(_tokenKey(uid));
    if (token == null || token.isEmpty) {
      token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        throw StateError('تعذر تسجيل هذا الجهاز في خدمة الإشعارات.');
      }
      await prefs.setString(_tokenKey(uid), token);
    }

    final roundedLatitude = _roundedCoordinate(latitude);
    final roundedLongitude = _roundedCoordinate(longitude);
    await prefs.setDouble(_latitudeKey(uid), roundedLatitude);
    await prefs.setDouble(_longitudeKey(uid), roundedLongitude);
    await _writeRegistration(
      uid: uid,
      token: token,
      latitude: roundedLatitude,
      longitude: roundedLongitude,
    );
  }

  /// Removes the remote registration before sign-out so the old account stops
  /// receiving weather messages. A network/rules failure is surfaced to caller.
  static Future<void> disable(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final wasEnabled = prefs.getBool(_enabledKey(uid)) ?? false;
    final token = prefs.getString(_tokenKey(uid));
    await prefs.setBool(_enabledKey(uid), false);

    try {
      if (token != null && token.isNotEmpty) {
        await _devices(uid).doc(token).delete().timeout(_timeout);
      }
      await prefs.remove(_tokenKey(uid));
      await prefs.remove(_latitudeKey(uid));
      await prefs.remove(_longitudeKey(uid));
    } catch (_) {
      if (wasEnabled) await prefs.setBool(_enabledKey(uid), true);
      rethrow;
    }
  }

  static Future<void> _saveRefreshedToken(String token) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || token.isEmpty || !await isEnabled(uid)) return;

    final prefs = await SharedPreferences.getInstance();
    final latitude = prefs.getDouble(_latitudeKey(uid));
    final longitude = prefs.getDouble(_longitudeKey(uid));
    if (latitude == null || longitude == null) return;

    final previousToken = prefs.getString(_tokenKey(uid));
    if (previousToken == token) return;
    if (previousToken != null && previousToken.isNotEmpty) {
      try {
        await _devices(uid).doc(previousToken).delete().timeout(_timeout);
      } catch (error) {
        debugPrint('Could not remove stale weather token registration: $error');
      }
    }
    await prefs.setString(_tokenKey(uid), token);
    try {
      await _writeRegistration(
        uid: uid,
        token: token,
        latitude: latitude,
        longitude: longitude,
      );
    } catch (error) {
      debugPrint('Could not refresh weather token registration: $error');
    }
  }

  static Future<void> _writeRegistration({
    required String uid,
    required String token,
    required double latitude,
    required double longitude,
  }) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('تغير الحساب أثناء تسجيل إشعارات الطقس.');
    }
    await _devices(uid).doc(token).set({
      'token': token,
      'latitude': latitude,
      'longitude': longitude,
      'enabled': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }).timeout(_timeout);
  }

  static void _validateCoordinates(double latitude, double longitude) {
    if (!latitude.isFinite || latitude < -90 || latitude > 90) {
      throw ArgumentError.value(latitude, 'latitude', 'Invalid coordinate');
    }
    if (!longitude.isFinite || longitude < -180 || longitude > 180) {
      throw ArgumentError.value(longitude, 'longitude', 'Invalid coordinate');
    }
  }
}
