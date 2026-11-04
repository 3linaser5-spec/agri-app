import '../models/weather_forecast.dart';

/// مرحلة نمو يختارها المستخدم لأن التطبيق لا يستنتجها بدقة من اسم البرنامج وحده.
enum IrrigationGrowthStage { initial, midSeason, lateSeason }

extension IrrigationGrowthStageLabel on IrrigationGrowthStage {
  String get label => switch (this) {
        IrrigationGrowthStage.initial => 'بداية النمو',
        IrrigationGrowthStage.midSeason => 'منتصف الموسم',
        IrrigationGrowthStage.lateSeason => 'نهاية الموسم',
      };
}

/// معاملات نموذجية مرجعية مستندة إلى FAO-56؛ يجب مراجعتها محليًا حسب الصنف
/// وطريقة الزراعة والظروف الحقلية.
class IrrigationCropProfile {
  const IrrigationCropProfile({
    required this.id,
    required this.name,
    required this.kcInitial,
    required this.kcMidSeason,
    required this.kcLateSeason,
    required this.searchTerms,
  });

  final String id;
  final String name;
  final double kcInitial;
  final double kcMidSeason;
  final double kcLateSeason;
  final List<String> searchTerms;

  double kcFor(IrrigationGrowthStage stage) => switch (stage) {
        IrrigationGrowthStage.initial => kcInitial,
        IrrigationGrowthStage.midSeason => kcMidSeason,
        IrrigationGrowthStage.lateSeason => kcLateSeason,
      };

  static const profiles = <IrrigationCropProfile>[
    IrrigationCropProfile(
      id: 'wheat',
      name: 'قمح',
      kcInitial: 0.70,
      kcMidSeason: 1.15,
      kcLateSeason: 0.30,
      searchTerms: ['قمح', 'wheat'],
    ),
    IrrigationCropProfile(
      id: 'maize',
      name: 'ذرة',
      kcInitial: 0.30,
      kcMidSeason: 1.20,
      kcLateSeason: 0.50,
      searchTerms: ['ذره', 'ذرة', 'maize', 'corn'],
    ),
    IrrigationCropProfile(
      id: 'tomato',
      name: 'طماطم',
      kcInitial: 0.60,
      kcMidSeason: 1.15,
      kcLateSeason: 0.80,
      searchTerms: ['طماطم', 'tomato'],
    ),
    IrrigationCropProfile(
      id: 'potato',
      name: 'بطاطس',
      kcInitial: 0.50,
      kcMidSeason: 1.15,
      kcLateSeason: 0.75,
      searchTerms: ['بطاطس', 'potato'],
    ),
    IrrigationCropProfile(
      id: 'rice',
      name: 'أرز',
      kcInitial: 1.05,
      kcMidSeason: 1.20,
      kcLateSeason: 0.75,
      searchTerms: ['ارز', 'أرز', 'rice'],
    ),
    IrrigationCropProfile(
      id: 'cotton',
      name: 'قطن',
      kcInitial: 0.35,
      kcMidSeason: 1.15,
      kcLateSeason: 0.60,
      searchTerms: ['قطن', 'cotton'],
    ),
    IrrigationCropProfile(
      id: 'beans',
      name: 'فول أو فاصوليا',
      kcInitial: 0.40,
      kcMidSeason: 1.15,
      kcLateSeason: 0.50,
      searchTerms: ['فول', 'فاصوليا', 'beans'],
    ),
    IrrigationCropProfile(
      id: 'other',
      name: 'محصول آخر (أدخل Kc يدويًا)',
      kcInitial: 0.50,
      kcMidSeason: 1.00,
      kcLateSeason: 0.70,
      searchTerms: [],
    ),
  ];

  static IrrigationCropProfile? guess(String text) {
    final normalized = _normalize(text);
    for (final profile in profiles) {
      if (profile.searchTerms.any((term) => normalized.contains(_normalize(term)))) {
        return profile;
      }
    }
    return null;
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي')
      .trim();
}

class IrrigationDayEstimate {
  const IrrigationDayEstimate({
    required this.date,
    required this.et0Mm,
    required this.rainMm,
    required this.effectiveRainMm,
    required this.cropEtMm,
    required this.netNeedMm,
    required this.grossNeedMm,
    required this.volumeM3,
  });

  final DateTime date;
  final double et0Mm;
  final double rainMm;
  final double effectiveRainMm;
  final double cropEtMm;
  final double netNeedMm;
  final double grossNeedMm;
  final double volumeM3;

  Map<String, dynamic> toMap() => {
        'date': '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'et0_mm': et0Mm,
        'rain_mm': rainMm,
        'effective_rain_mm': effectiveRainMm,
        'crop_et_mm': cropEtMm,
        'net_need_mm': netNeedMm,
        'gross_need_mm': grossNeedMm,
        'volume_m3': volumeM3,
      };
}

class IrrigationPlannerService {
  IrrigationPlannerService._();

  /// تقدير الاحتياج اليومي الإجمالي للمياه للأيام المتاحة في التوقع.
  /// يخصم 70% من المطر المتوقع كقيمة إرشادية مبسطة؛ لا يمثل ميزان رطوبة
  /// التربة ولا يحدد توقيت الري الفعلي.
  static List<IrrigationDayEstimate> estimateWeek({
    required List<WeatherForecastDay> forecast,
    required double areaM2,
    required double kc,
    required double efficiencyPercent,
    double effectiveRainFraction = 0.7,
  }) {
    if (!areaM2.isFinite || areaM2 <= 0) {
      throw ArgumentError.value(areaM2, 'areaM2', 'يجب أن تكون المساحة موجبة');
    }
    if (!kc.isFinite || kc <= 0 || kc > 2.5) {
      throw ArgumentError.value(kc, 'kc', 'معامل Kc خارج النطاق المقبول');
    }
    if (!efficiencyPercent.isFinite || efficiencyPercent <= 0 || efficiencyPercent > 100) {
      throw ArgumentError.value(efficiencyPercent, 'efficiencyPercent', 'كفاءة الري يجب أن تكون بين 0 و100');
    }
    if (!effectiveRainFraction.isFinite || effectiveRainFraction < 0 || effectiveRainFraction > 1) {
      throw ArgumentError.value(effectiveRainFraction, 'effectiveRainFraction');
    }

    final result = <IrrigationDayEstimate>[];
    for (final day in forecast.take(7)) {
      final et0 = day.et0Mm;
      if (et0 == null || !et0.isFinite || et0 < 0) continue;
      final rain = day.precipitationMm.isFinite && day.precipitationMm > 0
          ? day.precipitationMm
          : 0.0;
      final cropEt = et0 * kc;
      final effectiveRain = rain * effectiveRainFraction;
      final netNeed = (cropEt - effectiveRain).clamp(0.0, double.infinity).toDouble();
      final grossNeed = netNeed / (efficiencyPercent / 100);
      result.add(IrrigationDayEstimate(
        date: day.date,
        et0Mm: et0,
        rainMm: rain,
        effectiveRainMm: effectiveRain,
        cropEtMm: cropEt,
        netNeedMm: netNeed,
        grossNeedMm: grossNeed,
        volumeM3: grossNeed * areaM2 / 1000,
      ));
    }
    return result;
  }
}
