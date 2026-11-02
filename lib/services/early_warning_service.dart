import '../models/my_farm_model.dart';
import '../models/weather_forecast.dart';

enum CropWeatherRiskLevel { watch, elevated }

class CropWeatherWarning {
  const CropWeatherWarning({
    required this.date,
    required this.level,
    required this.title,
    required this.message,
    required this.crops,
  });

  final DateTime date;
  final CropWeatherRiskLevel level;
  final String title;
  final String message;
  final List<String> crops;
}

/// يستخدم مؤشرات الرطوبة المتوقعة لتوجيه فحص الحقل فقط، وليس نموذجًا لتشخيص
/// الأمراض؛ فالتطبيق لا يقيس بلل الأوراق ولا يملك نموذج إصابة خاصًا بالمحصول.
class EarlyWarningService {
  EarlyWarningService._();

  static const int forecastWindowDays = 3;
  static const double humidityWatchPercent = 80;
  static const double rainWatchMm = 1;
  static const int rainProbabilityWatchPercent = 50;
  static const double highHumidityPercent = 90;
  static const double heavyRainMm = 5;
  static const int highRainProbabilityPercent = 70;

  static List<CropWeatherWarning> evaluate({
    required List<WeatherForecastDay> forecast,
    required List<MyFarmProgram> programs,
  }) {
    final activePrograms = programs.where((program) =>
        program.status == 'active' && !program.isCompleted);
    if (activePrograms.isEmpty) return const [];

    final crops = _activeCropLabels(activePrograms.toList(growable: false));
    final warnings = <CropWeatherWarning>[];
    for (final day in forecast.take(forecastWindowDays)) {
      final humidity = day.meanRelativeHumidityPercent;
      if (humidity == null || humidity < humidityWatchPercent) continue;

      final probability = day.precipitationProbability ?? 0;
      final wetWeather = day.precipitationMm >= rainWatchMm ||
          probability >= rainProbabilityWatchPercent;
      if (!wetWeather) continue;

      final elevated = humidity >= highHumidityPercent &&
          (day.precipitationMm >= heavyRainMm ||
              probability >= highRainProbabilityPercent);
      final cropText = crops.isEmpty
          ? 'المحاصيل المسجلة في مزرعتك'
          : crops.take(3).join('، ');
      final dayLabel = _dateLabel(day.date);
      final humidityText = humidity.round();
      final rainText = day.precipitationMm.toStringAsFixed(1);
      final chanceText = day.precipitationProbability == null
          ? ''
          : ' واحتمال المطر ${day.precipitationProbability}٪';

      warnings.add(CropWeatherWarning(
        date: day.date,
        level: elevated
            ? CropWeatherRiskLevel.elevated
            : CropWeatherRiskLevel.watch,
        title: elevated
            ? 'إنذار متابعة مرتفع: افحص الحقول'
            : 'تنبيه متابعة: أجواء رطبة',
        message:
            'توقعات $dayLabel تشير إلى رطوبة جوية تقارب $humidityText٪ وأمطار $rainText مم$chanceText حول $cropText. كثّف فحص الأوراق بعد البلل وسجّل أي أعراض. هذا مؤشر متابعة عام، وليس تشخيصًا أو توصية رش أو تعديل ري.',
        crops: crops,
      ));
    }
    return warnings;
  }

  static List<String> _activeCropLabels(List<MyFarmProgram> programs) {
    const aliases = <String, List<String>>{
      'قمح': ['قمح', 'wheat'],
      'ذرة': ['ذرة', 'ذره', 'maize', 'corn'],
      'أرز': ['أرز', 'ارز', 'rice'],
      'طماطم': ['طماطم', 'بندورة', 'tomato'],
      'بطاطس': ['بطاطس', 'بطاطا', 'potato'],
      'عنب': ['عنب', 'grape'],
      'تفاح': ['تفاح', 'apple'],
      'فلفل': ['فلفل', 'pepper'],
      'فراولة': ['فراولة', 'strawberry'],
      'قطن': ['قطن', 'cotton'],
      'حمضيات': ['حمضيات', 'برتقال', 'موالح', 'citrus', 'orange'],
      'خيار': ['خيار', 'cucumber'],
      'بصل': ['بصل', 'onion'],
      'فول': ['فول', 'fava', 'bean'],
    };

    final result = <String>{};
    for (final program in programs) {
      final candidates = <String>[
        program.templateName,
        program.sectionName,
        for (final entry in program.inputValues.entries)
          if (_isCropField(entry.key)) entry.value?.toString() ?? '',
      ];
      for (final candidate in candidates) {
        final normalized = _normalize(candidate);
        if (normalized.isEmpty) continue;
        for (final entry in aliases.entries) {
          if (entry.value.any((alias) =>
              _normalize(alias).split(' ').every(normalized.contains))) {
            result.add(entry.key);
          }
        }
      }
    }
    return result.toList(growable: false);
  }

  static bool _isCropField(String key) {
    final normalized = _normalize(key);
    return normalized.contains('crop') ||
        normalized.contains('plant') ||
        normalized.contains('variety') ||
        normalized.contains('محصول') ||
        normalized.contains('نبات') ||
        normalized.contains('صنف');
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
      .replaceAll('أ', 'ا')
      .replaceAll('إ', 'ا')
      .replaceAll('آ', 'ا')
      .replaceAll('ى', 'ي')
      .replaceAll('ة', 'ه')
      .replaceAll(RegExp(r'[^a-z0-9\u0600-\u06FF]+'), ' ')
      .trim();

  static String _dateLabel(DateTime date) {
    final local = date.toLocal();
    final now = DateTime.now();
    if (local.year == now.year && local.month == now.month && local.day == now.day) {
      return 'اليوم';
    }
    final tomorrow = now.add(const Duration(days: 1));
    if (local.year == tomorrow.year &&
        local.month == tomorrow.month &&
        local.day == tomorrow.day) {
      return 'غدًا';
    }
    const weekdays = [
      'الاثنين',
      'الثلاثاء',
      'الأربعاء',
      'الخميس',
      'الجمعة',
      'السبت',
      'الأحد',
    ];
    return weekdays[local.weekday - 1];
  }
}
