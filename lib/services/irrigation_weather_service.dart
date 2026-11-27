import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/weather_forecast.dart';
import 'weather_service.dart';

/// جلب توقعات الطقس لشاشات المزرعة من نفس الكاش الذي تستخدمه الصفحة الرئيسية،
/// مع تحديث الشبكة عند الحاجة. يحافظ على الموقع الذي اختاره المستخدم حتى لا
/// تُحسب توصيات الري على مدينة أخرى.
class IrrigationWeatherService {
  IrrigationWeatherService._();

  static const String cacheKey = 'weather_data';
  static const String locationKey = 'selected_weather_location';
  static const Duration maxAge = Duration(minutes: 45);

  /// النسخة المحفوظة إن كانت حديثة، وإلا `null`.
  static Future<WeatherSnapshot?> cached({Duration? maxAge}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(cacheKey);
    if (raw == null) return null;
    try {
      final data = json.decode(raw);
      if (data is! Map) return null;
      final savedAt = int.tryParse('${data['saved_at'] ?? ''}');
      final allowed = maxAge ?? IrrigationWeatherService.maxAge;
      if (savedAt != null) {
        final age = DateTime.now().millisecondsSinceEpoch - savedAt;
        if (age > allowed.inMilliseconds) return null;
      }
      final forecast = data['forecast'];
      if (forecast is! Map) return null;
      return WeatherSnapshot.fromJson(Map<String, dynamic>.from(forecast));
    } catch (error) {
      debugPrint('تعذر قراءة توقعات الطقس المحفوظة: $error');
      return null;
    }
  }

  /// أحدث توقعات متاحة: الكاش الحديث أولًا، ثم الشبكة، ثم كاش قديم كحل أخير.
  static Future<WeatherSnapshot?> load({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final fresh = await cached();
      if (fresh != null) return fresh;
    }

    final prefs = await SharedPreferences.getInstance();
    final coordinates = _coordinates(prefs);
    if (coordinates == null) return cached(maxAge: const Duration(days: 3));

    try {
      final snapshot = await WeatherService.fetch(
        latitude: coordinates.$1,
        longitude: coordinates.$2,
      );
      await _store(snapshot, prefs, coordinates);
      return snapshot;
    } catch (error) {
      debugPrint('تعذر تحديث الطقس لشاشة المزرعة: $error');
      return cached(maxAge: const Duration(days: 3));
    }
  }

  static (double, double)? _coordinates(SharedPreferences prefs) {
    final raw = prefs.getString(cacheKey);
    if (raw != null) {
      try {
        final data = json.decode(raw);
        if (data is Map) {
          final latitude = (data['latitude'] as num?)?.toDouble();
          final longitude = (data['longitude'] as num?)?.toDouble();
          if (latitude != null && longitude != null) {
            return (latitude, longitude);
          }
        }
      } catch (_) {}
    }
    final rawLocation = prefs.getString(locationKey);
    if (rawLocation == null) return null;
    try {
      final location = json.decode(rawLocation);
      if (location is! Map) return null;
      final latitude = (location['latitude'] as num?)?.toDouble();
      final longitude = (location['longitude'] as num?)?.toDouble();
      if (latitude == null || longitude == null) return null;
      return (latitude, longitude);
    } catch (_) {
      return null;
    }
  }

  static Future<void> _store(
    WeatherSnapshot snapshot,
    SharedPreferences prefs,
    (double, double) coordinates,
  ) async {
    Map<String, dynamic> data = {};
    final raw = prefs.getString(cacheKey);
    if (raw != null) {
      try {
        final decoded = json.decode(raw);
        if (decoded is Map) data = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    data['forecast'] = snapshot.toJson();
    data['latitude'] = coordinates.$1;
    data['longitude'] = coordinates.$2;
    data['saved_at'] = DateTime.now().millisecondsSinceEpoch;
    data['loaded'] = true;
    await prefs.setString(cacheKey, json.encode(data));
  }
}
