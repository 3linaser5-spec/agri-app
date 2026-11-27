import '../models/farm_workspace_models.dart';

/// مؤشرات موسم واحد بعد تحويل الإنتاج والتكاليف لكل فدان، حتى تُقارن المواسم
/// بمساحات مختلفة بعدل.
class SeasonMetrics {
  final double areaFeddan;
  final double yieldKg;
  final double yieldPerFeddan;
  final double revenue;
  final double expenses;
  final double costPerFeddan;
  final double netProfit;
  final double profitPerFeddan;
  final double marginRatio;
  final int daysInSeason;

  const SeasonMetrics({
    required this.areaFeddan,
    required this.yieldKg,
    required this.yieldPerFeddan,
    required this.revenue,
    required this.expenses,
    required this.costPerFeddan,
    required this.netProfit,
    required this.profitPerFeddan,
    required this.marginRatio,
    required this.daysInSeason,
  });

  factory SeasonMetrics.fromSeason(CropSeason season, {DateTime? now}) {
    return SeasonMetrics(
      areaFeddan: season.safeAreaFeddan,
      yieldKg: season.effectiveYieldKg,
      yieldPerFeddan: season.yieldPerFeddan,
      revenue: season.revenue,
      expenses: season.totalExpenses,
      costPerFeddan: season.costPerFeddan,
      netProfit: season.netProfit,
      profitPerFeddan: season.profitPerFeddan,
      marginRatio: season.marginRatio,
      daysInSeason: season.daysInSeason(now ?? DateTime.now()),
    );
  }
}

/// نتيجة مقارنة موسمين لنفس المحصول (أو أي موسمين اختارهما المستخدم).
class SeasonComparison {
  final CropSeason first;
  final CropSeason second;
  final SeasonMetrics firstMetrics;
  final SeasonMetrics secondMetrics;

  const SeasonComparison({
    required this.first,
    required this.second,
    required this.firstMetrics,
    required this.secondMetrics,
  });

  double get yieldDelta => secondMetrics.yieldPerFeddan - firstMetrics.yieldPerFeddan;

  double get profitDelta => secondMetrics.netProfit - firstMetrics.netProfit;

  double get profitPerFeddanDelta =>
      secondMetrics.profitPerFeddan - firstMetrics.profitPerFeddan;

  double get costPerFeddanDelta =>
      secondMetrics.costPerFeddan - firstMetrics.costPerFeddan;

  double get marginDelta => secondMetrics.marginRatio - firstMetrics.marginRatio;

  /// نسبة تغيّر الربح؛ صفر لو كان الأساس صفرًا.
  double get profitChangeRatio {
    final base = firstMetrics.netProfit.abs();
    if (base == 0) return 0;
    return profitDelta / base;
  }

  /// الموسم الأفضل ماليًا لكل فدان (عدل بين المساحات المختلفة).
  CropSeason get betterSeason =>
      secondMetrics.profitPerFeddan >= firstMetrics.profitPerFeddan
          ? second
          : first;

  /// جملة عربية واحدة تشرح النتيجة.
  String get verdict {
    final diff = profitPerFeddanDelta;
    if (diff.abs() < 1) {
      return 'الموسمان متقاربان في الربح لكل فدان.';
    }
    final betterLabel = diff > 0 ? 'الثاني' : 'الأول';
    final ratio = firstMetrics.profitPerFeddan == 0
        ? null
        : (diff.abs() / firstMetrics.profitPerFeddan.abs()) * 100;
    final ratioText = ratio == null ? '' : ' (${ratio.toStringAsFixed(0)}٪)';
    return 'الموسم $betterLabel أفضل بـ ${diff.abs().toStringAsFixed(0)} '
        'جنيه لكل فدان$ratioText.';
  }
}

/// خدمات مقارنة المواسم، نقية بالكامل وقابلة للاختبار.
class SeasonComparisonService {
  const SeasonComparisonService();

  static String seasonLabel(CropSeason season) =>
      '${season.crop}${season.variety.trim().isEmpty ? '' : ' — ${season.variety}'} '
      '(${season.plantingDate.year})';

  /// مقارنة موسمين؛ تُعيد `null` لو كانا نفس الموسم.
  static SeasonComparison? compare(CropSeason first, CropSeason second) {
    if (first.id == second.id) return null;
    return SeasonComparison(
      first: first,
      second: second,
      firstMetrics: SeasonMetrics.fromSeason(first),
      secondMetrics: SeasonMetrics.fromSeason(second),
    );
  }

  /// كل مواسم محصول معيّن، الأقدم أولًا (مفيدة للخط الزمني).
  static List<CropSeason> seasonsForCrop(
    Iterable<CropSeason> seasons,
    String crop,
  ) {
    final list = seasons
        .where((season) => season.crop.trim() == crop.trim())
        .toList(growable: false);
    list.sort((a, b) => a.plantingDate.compareTo(b.plantingDate));
    return list;
  }

  /// أحدث موسمين في القائمة (الأحدث أولًا في النتيجة).
  static List<CropSeason> latestTwo(Iterable<CropSeason> seasons) {
    final list = List<CropSeason>.of(seasons);
    list.sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
    return list.take(2).toList(growable: false);
  }

  /// مقارنة تلقائية: أحدث موسمين لنفس المحصول، وإلا أحدث موسمين عمومًا.
  static SeasonComparison? automatic(Iterable<CropSeason> seasons) {
    final list = List<CropSeason>.of(seasons);
    if (list.length < 2) return null;
    list.sort((a, b) => b.plantingDate.compareTo(a.plantingDate));
    final newest = list.first;
    final sameCrop = list
        .skip(1)
        .where((season) => season.crop.trim() == newest.crop.trim())
        .toList(growable: false);
    final other = sameCrop.isNotEmpty ? sameCrop.first : list[1];
    return compare(other, newest);
  }

  static Map<int, List<CropSeason>> byYear(Iterable<CropSeason> seasons) {
    final groups = <int, List<CropSeason>>{};
    for (final season in seasons) {
      groups.putIfAbsent(season.plantingDate.year, () => []).add(season);
    }
    return groups;
  }

  /// ملخص كل سنة: الإيراد والتكلفة والربح لكل فدان.
  static List<YearlySeasonSummary> yearlySummaries(
    Iterable<CropSeason> seasons,
  ) {
    final groups = byYear(seasons);
    final years = groups.keys.toList()..sort();
    return [
      for (final year in years)
        YearlySeasonSummary(
          year: year,
          summary: CropProfitSummary.fromSeasons(groups[year]!),
        ),
    ];
  }

  /// أفضل موسم لكل محصول (الأعلى ربحًا لكل فدان).
  static Map<String, CropSeason> bestPerCrop(Iterable<CropSeason> seasons) {
    final best = <String, CropSeason>{};
    for (final season in seasons) {
      final current = best[season.crop];
      if (current == null ||
          season.profitPerFeddan > current.profitPerFeddan) {
        best[season.crop] = season;
      }
    }
    return best;
  }

  /// نص جاهز للمشاركة يلخّص المقارنة.
  static String shareText(SeasonComparison comparison) {
    final first = comparison.first;
    final second = comparison.second;
    final firstMetrics = comparison.firstMetrics;
    final secondMetrics = comparison.secondMetrics;
    String line(String label, double a, double b, {String unit = 'جنيه'}) =>
        '• $label: ${a.toStringAsFixed(0)} ← ${b.toStringAsFixed(0)} $unit';

    return 'نباتي — مقارنة المواسم\n'
        '${seasonLabel(first)} مقابل ${seasonLabel(second)}\n'
        '${line('الربح لكل فدان', firstMetrics.profitPerFeddan, secondMetrics.profitPerFeddan)}\n'
        '${line('الإنتاج لكل فدان', firstMetrics.yieldPerFeddan, secondMetrics.yieldPerFeddan, unit: 'كجم')}\n'
        '${line('التكلفة لكل فدان', firstMetrics.costPerFeddan, secondMetrics.costPerFeddan)}\n'
        '${line('هامش الربح', firstMetrics.marginRatio * 100, secondMetrics.marginRatio * 100, unit: '٪')}\n'
        '${comparison.verdict}';
  }
}

/// ملخص سنة كاملة من المواسم.
class YearlySeasonSummary {
  final int year;
  final CropProfitSummary summary;

  const YearlySeasonSummary({required this.year, required this.summary});

  double get profitPerFeddan => summary.profitPerFeddan;
  int get seasons => summary.seasons;
}
