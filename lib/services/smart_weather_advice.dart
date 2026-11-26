import '../models/weather_forecast.dart';

/// نوع النصيحة الزراعية المبنية على الطقس.
enum FarmAdviceKind { irrigation, heat, cold, fungal, spray, harvest }

/// نصيحة واحدة قابلة للعرض، مع قدرة على ترتيبها بالأهمية.
class FarmAdvice {
  final FarmAdviceKind kind;
  final String title;
  final String message;
  final int severity; // 1 = معلومة، 2 = مهم، 3 = عاجل
  final double? waterSavingMm;

  const FarmAdvice({
    required this.kind,
    required this.title,
    required this.message,
    this.severity = 1,
    this.waterSavingMm,
  });
}

/// قواعد تحويل توقعات الطقس إلى قرارات ري ووقاية.
///
/// الدالة نقية بلا Flutter، وتعمل على [WeatherSnapshot] الموجود أصلًا، وتضيف
/// توصيات تشغيلية (أجّل الري، زوّد الري، رش وقائي) فوق التنبيهات العامة في
/// [buildWeatherAlerts].
class SmartWeatherAdvisor {
  const SmartWeatherAdvisor._();

  static const double rainMmThreshold = 4;
  static const int rainProbabilityThreshold = 55;
  static const double heatThresholdC = 38;
  static const double coldThresholdC = 5;
  static const double highHumidityPercent = 85;
  static const int lookAheadDays = 3;

  /// إجمالي البخر-نتح المرجعي المتوقع خلال [days] أيام.
  static double referenceEtMm(WeatherSnapshot snapshot, {int days = 3}) {
    var total = 0.0;
    for (final day in snapshot.days.take(days)) {
      total += day.et0Mm ?? 0;
    }
    return total;
  }

  /// أفضل قرار ري خلال الأيام القادمة، مع كمية المياه الموفَّرة بالمليمتر.
  static FarmAdvice? irrigationDecision(WeatherSnapshot snapshot) {
    final upcoming = snapshot.days.take(lookAheadDays).toList(growable: false);
    if (upcoming.isEmpty) return null;

    WeatherForecastDay? wettest;
    for (final day in upcoming) {
      final probability = day.precipitationProbability ?? 0;
      final isRainy = day.precipitationMm >= rainMmThreshold ||
          probability >= rainProbabilityThreshold;
      if (!isRainy) continue;
      if (wettest == null || day.precipitationMm > wettest.precipitationMm) {
        wettest = day;
      }
    }
    if (wettest != null) {
      final saved = wettest.precipitationMm.clamp(0, 60).toDouble();
      return FarmAdvice(
        kind: FarmAdviceKind.irrigation,
        title: 'أجّل الري — أمطار قادمة',
        message:
            'متوقع ${wettest.precipitationMm.toStringAsFixed(1)} مم مطر'
            '${wettest.precipitationProbability == null ? '' : ' (احتمال ${wettest.precipitationProbability}٪)'}'
            '. أوقف/أجّل الري لتوفير المياه وتقليل رطوبة التربة الزائدة.',
        severity: 3,
        waterSavingMm: saved,
      );
    }

    final et = referenceEtMm(snapshot);
    if (et <= 0) return null;
    return FarmAdvice(
      kind: FarmAdviceKind.irrigation,
      title: 'احتياج الري التقديري',
      message:
          'إجمالي البخر-نتح لثلاثة أيام ≈ ${et.toStringAsFixed(1)} مم. '
          'احسب زمن التشغيل = (الاحتياج ÷ معدل تطبيق الشبكة) مع مراجعة رطوبة التربة.',
      severity: 1,
    );
  }

  /// كل النصائح مرتبة بالأهمية، بدون تكرار.
  static List<FarmAdvice> build(
    WeatherSnapshot snapshot, {
    String? cropName,
  }) {
    if (snapshot.days.isEmpty) return const [];
    final advice = <FarmAdvice>[];
    final cropLabel = (cropName == null || cropName.trim().isEmpty)
        ? 'المحصول'
        : cropName.trim();

    final irrigation = irrigationDecision(snapshot);
    if (irrigation != null) advice.add(irrigation);

    final upcoming = snapshot.days.take(lookAheadDays).toList(growable: false);

    WeatherForecastDay? hottest;
    for (final day in upcoming) {
      if (day.maximumTemperatureC >= heatThresholdC &&
          (hottest == null ||
              day.maximumTemperatureC > hottest.maximumTemperatureC)) {
        hottest = day;
      }
    }
    if (hottest != null) {
      advice.add(FarmAdvice(
        kind: FarmAdviceKind.heat,
        title: 'موجة حرارة على $cropLabel',
        message:
            'العظمى ${hottest.maximumTemperatureC.toStringAsFixed(0)}°م. '
            'زوّد الري 10-15٪ في الصباح الباكر، وأجّل الرش والأسمدة الورقية للعصر.',
        severity: 2,
      ));
    }

    WeatherForecastDay? coldest;
    for (final day in upcoming) {
      if (day.minimumTemperatureC <= coldThresholdC &&
          (coldest == null ||
              day.minimumTemperatureC < coldest.minimumTemperatureC)) {
        coldest = day;
      }
    }
    if (coldest != null) {
      advice.add(FarmAdvice(
        kind: FarmAdviceKind.cold,
        title: 'برودة قد تضر $cropLabel',
        message:
            'الصغرى ${coldest.minimumTemperatureC.toStringAsFixed(0)}°م. '
            'قلّل الري الليلي وغطِّ الشتلات الحساسة، وراقب الأوراق صباحًا.',
        severity: 2,
      ));
    }

    for (final day in upcoming) {
      final humidity = day.meanRelativeHumidityPercent;
      if (humidity == null) continue;
      final mildTemperature = day.maximumTemperatureC <= 30 &&
          day.minimumTemperatureC >= 12;
      if (humidity >= highHumidityPercent && mildTemperature) {
        advice.add(FarmAdvice(
          kind: FarmAdviceKind.fungal,
          title: 'خطر أمراض فطرية مرتفع',
          message:
              'رطوبة متوسطة ${humidity.toStringAsFixed(0)}٪ مع حرارة معتدلة. '
              'قلّل ترطيب الأوراق، وحسّن التهوية، وراقب البياض/اللفحة.',
          severity: 2,
        ));
        break;
      }
    }

    // الرش: نتجنبه لو أمطار قريبة أو حرارة عالية.
    final hasRainAdvice =
        advice.any((a) => a.kind == FarmAdviceKind.irrigation && a.severity == 3);
    if (!hasRainAdvice && hottest == null) {
      advice.add(const FarmAdvice(
        kind: FarmAdviceKind.spray,
        title: 'نافذة رش مناسبة',
        message: 'لا أمطار قريبة ولا حرارة شديدة متوقعة؛ الرش في الصباح الباكر أفضل.',
        severity: 1,
      ));
    }

    advice.sort((a, b) => b.severity.compareTo(a.severity));
    return List.unmodifiable(advice);
  }

  /// ملخص قصير لاستخدامه في الإشعار.
  static String notificationBody(List<FarmAdvice> advice) {
    if (advice.isEmpty) return 'لا توجد توصيات طارئة اليوم.';
    final top = advice.first;
    return '${top.title}: ${top.message}';
  }
}
