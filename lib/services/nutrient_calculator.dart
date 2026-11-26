/// حسابات محلول التغذية (التسميد الورقي/المائي): تحويل أهداف ppm إلى جرامات
/// من الأسمدة المتاحة، وتقدير الملوحة (EC)، وجرعة الحمض لضبط pH.
///
/// كل الدوال نقية بلا Flutter حتى يمكن اختبارها، والافتراضات موثّقة حتى لا
/// تُقرأ النتائج كتحليل مخبري دقيق.
library;

/// عنصر غذائي مستهدف.
enum NutrientElement {
  nitrogen('N', 'النيتروجين', 1),
  phosphorus('P', 'الفوسفور', 1),
  potassium('K', 'البوتاسيوم', 1),
  magnesium('Mg', 'المغنيسيوم', 1);

  const NutrientElement(this.symbol, this.label, this.atomicFactor);
  final String symbol;
  final String label;

  /// معامل التحويل من الأكسيد إلى العنصر (P2O5 → P وK2O → K).
  final double atomicFactor;
}

/// سماد متاح بتحليل معروف (نسب مئوية للوزن).
class FertilizerProduct {
  final String name;
  final double nitrogenPercent;
  final double p2o5Percent;
  final double k2oPercent;
  final double magnesiumPercent;

  const FertilizerProduct({
    required this.name,
    this.nitrogenPercent = 0,
    this.p2o5Percent = 0,
    this.k2oPercent = 0,
    this.magnesiumPercent = 0,
  });

  double percentFor(NutrientElement element) {
    switch (element) {
      case NutrientElement.nitrogen:
        return nitrogenPercent;
      case NutrientElement.phosphorus:
        return p2o5Percent * 0.436; // P2O5 → P
      case NutrientElement.potassium:
        return k2oPercent * 0.83; // K2O → K
      case NutrientElement.magnesium:
        return magnesiumPercent;
    }
  }

  /// جرامات المنتج لكل 1000 لتر المطلوبة للوصول إلى [targetPpm] من العنصر.
  double gramsForTargetPer1000L(NutrientElement element, double targetPpm) {
    final percent = percentFor(element);
    if (percent <= 0 || targetPpm <= 0) return 0;
    // 1 جرام في 1000 لتر = 1 ppm من المادة الصافية.
    return targetPpm * 100 / percent;
  }
}

/// مساهمة سماد في المحلول.
class NutrientContribution {
  final String productName;
  final double grams;
  final double nitrogenPpm;
  final double phosphorusPpm;
  final double potassiumPpm;
  final double magnesiumPpm;

  const NutrientContribution({
    required this.productName,
    required this.grams,
    required this.nitrogenPpm,
    required this.phosphorusPpm,
    required this.potassiumPpm,
    required this.magnesiumPpm,
  });

  double get totalPpm =>
      nitrogenPpm + phosphorusPpm + potassiumPpm + magnesiumPpm;
}

/// نتيجة تقييم محلول كامل.
class NutrientSolutionResult {
  final double liters;
  final List<NutrientContribution> contributions;
  final double nitrogenPpm;
  final double phosphorusPpm;
  final double potassiumPpm;
  final double magnesiumPpm;

  /// تقدير تقريبي للملوحة (dS/m) من مجموع الأملاح الذائبة.
  final double estimatedEcDsM;

  const NutrientSolutionResult({
    required this.liters,
    required this.contributions,
    required this.nitrogenPpm,
    required this.phosphorusPpm,
    required this.potassiumPpm,
    required this.magnesiumPpm,
    required this.estimatedEcDsM,
  });

  double get totalSaltsPpm =>
      nitrogenPpm + phosphorusPpm + potassiumPpm + magnesiumPpm;

  /// وصف الهدف مقابل الناتج: `deficit` أو `excess` أو `onTarget`.
  String statusFor(NutrientElement element, double targetPpm) {
    final actual = switch (element) {
      NutrientElement.nitrogen => nitrogenPpm,
      NutrientElement.phosphorus => phosphorusPpm,
      NutrientElement.potassium => potassiumPpm,
      NutrientElement.magnesium => magnesiumPpm,
    };
    if (targetPpm <= 0) return 'onTarget';
    final ratio = actual / targetPpm;
    if (ratio < 0.9) return 'deficit';
    if (ratio > 1.1) return 'excess';
    return 'onTarget';
  }
}

/// جرعة حمض لضبط pH.
class AcidDose {
  /// ملليلتر لكل 1000 لتر من المحلول.
  final double mlPer1000L;
  final String acidLabel;
  final String note;

  const AcidDose({
    required this.mlPer1000L,
    required this.acidLabel,
    required this.note,
  });
}

class NutrientCalculator {
  const NutrientCalculator._();

  /// 1 dS/m ≈ 640 مجم/لتر من الأملاح الذائبة (تقدير شائع لمحاليل التغذية).
  static const double ppmPerEcUnit = 640;

  /// مساهمة جرعة سماد في محلول حجمه [liters] لتر.
  static NutrientContribution contribution(
    FertilizerProduct product,
    double grams,
    double liters,
  ) {
    final safeLiters = liters > 0 ? liters : 0.0;
    double ppm(double percent) =>
        safeLiters == 0 ? 0 : grams * (percent / 100) * 1000 / safeLiters;
    return NutrientContribution(
      productName: product.name,
      grams: grams,
      nitrogenPpm: ppm(product.nitrogenPercent),
      phosphorusPpm: ppm(product.percentFor(NutrientElement.phosphorus)),
      potassiumPpm: ppm(product.percentFor(NutrientElement.potassium)),
      magnesiumPpm: ppm(product.magnesiumPercent),
    );
  }

  /// تقدير الملوحة من مجموع الأملاح بالـ ppm.
  static double estimateEcDsM(double totalSaltsPpm) {
    if (!totalSaltsPpm.isFinite || totalSaltsPpm <= 0) return 0;
    return totalSaltsPpm / ppmPerEcUnit;
  }

  /// تقييم محلول مكوّن من عدة أسمدة بجرعات بالجرام.
  static NutrientSolutionResult evaluate({
    required double liters,
    required Iterable<MapEntry<FertilizerProduct, double>> doses,
  }) {
    final contributions = <NutrientContribution>[];
    var n = 0.0, p = 0.0, k = 0.0, mg = 0.0;
    for (final entry in doses) {
      if (entry.value <= 0) continue;
      final item = contribution(entry.key, entry.value, liters);
      contributions.add(item);
      n += item.nitrogenPpm;
      p += item.phosphorusPpm;
      k += item.potassiumPpm;
      mg += item.magnesiumPpm;
    }
    return NutrientSolutionResult(
      liters: liters,
      contributions: List.unmodifiable(contributions),
      nitrogenPpm: n,
      phosphorusPpm: p,
      potassiumPpm: k,
      magnesiumPpm: mg,
      estimatedEcDsM: estimateEcDsM(n + p + k + mg),
    );
  }

  /// وصفة جاهزة: يوزّع الهدف على الأسمدة بالترتيب، وكل سماد يغطي ما تبقّى من
  /// العنصر المرتبط به. النتيجة جرامات لكل 1000 لتر.
  static Map<String, double> recipeGramsPer1000L({
    required Map<NutrientElement, double> targetsPpm,
    required List<FertilizerProduct> products,
  }) {
    final remaining = <NutrientElement, double>{
      for (final entry in targetsPpm.entries)
        if (entry.value > 0) entry.key: entry.value,
    };
    final grams = <String, double>{};
    for (final product in products) {
      var bestElement = NutrientElement.nitrogen;
      var bestShare = 0.0;
      for (final entry in remaining.entries) {
        final coverable = product.gramsForTargetPer1000L(
          entry.key,
          entry.value,
        );
        final share = coverable == 0 ? 0.0 : entry.value;
        if (share > bestShare) {
          bestShare = share;
          bestElement = entry.key;
        }
      }
      if (bestShare <= 0) continue;
      final needed = remaining[bestElement]!;
      final productGrams =
          product.gramsForTargetPer1000L(bestElement, needed);
      if (productGrams <= 0) continue;
      grams[product.name] = (grams[product.name] ?? 0) + productGrams;
      // خصم ما يغطيه هذا السماد من بقية العناصر التي يحتويها.
      for (final element in remaining.keys.toList()) {
        final percent = product.percentFor(element);
        if (percent <= 0) continue;
        final supplied = productGrams * (percent / 100);
        final left = remaining[element]! - supplied;
        if (left <= 0.001) {
          remaining.remove(element);
        } else {
          remaining[element] = left;
        }
      }
    }
    return grams;
  }

  /// جرعة حمض تقريبية لمعادلة القلوية (بيكربونات الكالسيوم).
  ///
  /// المعادلة: meq/L = القلوية (مجم/لتر CaCO3) ÷ 50، ثم تُحوَّل إلى الحمض
  /// حسب وزنه المكافئ وكثافته وتركيزه.
  static AcidDose estimateAcidDose({
    required double alkalinityMgL,
    required double currentPh,
    required double targetPh,
    String acid = 'sulfuric',
  }) {
    if (alkalinityMgL <= 0 || currentPh <= targetPh) {
      return AcidDose(
        mlPer1000L: 0,
        acidLabel: _acidLabel(acid),
        note: 'لا حاجة لخفض الحموضة بناءً على المدخلات الحالية.',
      );
    }
    final meqPerLiter = alkalinityMgL / 50;
    final factor = switch (acid) {
      'nitric' => 49.0, // 68% HNO3
      'phosphoric' => 15.0, // 85% H3PO4
      _ => 27.2, // 98% H2SO4
    };
    final mlPer1000L = meqPerLiter * factor;
    return AcidDose(
      mlPer1000L: mlPer1000L,
      acidLabel: _acidLabel(acid),
      note:
          'تقدير تقريبي لمعادلة البيكربونات فقط؛ أضف الحمض تدريجيًا وقس pH قبل الري.',
    );
  }

  static String _acidLabel(String acid) => switch (acid) {
        'nitric' => 'حمض نيتريك 68%',
        'phosphoric' => 'حمض فوسفوريك 85%',
        _ => 'حمض كبريتيك 98%',
      };

  /// الأسمدة الشائعة بقيم تحليل نموذجية للاستخدام السريع في الشاشة.
  static const List<FertilizerProduct> commonProducts = [
    FertilizerProduct(
      name: 'نترات كالسيوم',
      nitrogenPercent: 15.5,
      // يحتوي كالسيوم 19% لكن شاشتنا تحسب العناصر الأربعة الأساسية.
    ),
    FertilizerProduct(
      name: 'نترات بوتاسيوم',
      nitrogenPercent: 13,
      k2oPercent: 38,
    ),
    FertilizerProduct(
      name: 'مونو فوسفات بوتاسيوم (MAP)',
      nitrogenPercent: 12,
      p2o5Percent: 61,
    ),
    FertilizerProduct(
      name: 'سلفات بوتاسيوم',
      k2oPercent: 50,
    ),
    FertilizerProduct(
      name: 'سلفات ماغنسيوم',
      magnesiumPercent: 16,
    ),
  ];
}
