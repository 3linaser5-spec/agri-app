import 'package:flutter_test/flutter_test.dart';

import 'package:agri_app/services/nutrient_calculator.dart';

void main() {
  const potassiumNitrate = FertilizerProduct(
    name: 'نترات بوتاسيوم',
    nitrogenPercent: 13,
    k2oPercent: 38,
  );

  test('converts oxide percentages to elemental P and K', () {
    const map = FertilizerProduct(name: 'MAP', p2o5Percent: 61);
    expect(map.percentFor(NutrientElement.phosphorus), closeTo(26.6, 0.1));
    const sulfate = FertilizerProduct(name: 'سلفات بوتاسيوم', k2oPercent: 50);
    expect(sulfate.percentFor(NutrientElement.potassium), closeTo(41.5, 0.1));
  });

  test('computes grams per 1000 L for a target ppm', () {
    // 180 ppm K من سماد 38% K2O (31.5% K) ⇒ 180 / 0.315 ≈ 571 جم.
    final grams =
        potassiumNitrate.gramsForTargetPer1000L(NutrientElement.potassium, 180);
    expect(grams, closeTo(571, 2));
  });

  test('returns zero for an impossible target', () {
    const product = FertilizerProduct(name: 'بدون تحليل');
    expect(product.gramsForTargetPer1000L(NutrientElement.nitrogen, 100), 0);
    expect(potassiumNitrate.gramsForTargetPer1000L(NutrientElement.nitrogen, 0),
        0);
  });

  test('computes ppm contributions for the actual tank volume', () {
    final contribution = NutrientCalculator.contribution(
      potassiumNitrate,
      1000,
      1000,
    );
    expect(contribution.nitrogenPpm, closeTo(130, 0.5));
    expect(contribution.potassiumPpm, closeTo(315.4, 1));
  });

  test('scales ppm down when the tank is larger', () {
    final small = NutrientCalculator.contribution(potassiumNitrate, 500, 1000);
    final large = NutrientCalculator.contribution(potassiumNitrate, 500, 2000);
    expect(large.nitrogenPpm, closeTo(small.nitrogenPpm / 2, 0.001));
  });

  test('estimates EC from total salts', () {
    expect(NutrientCalculator.estimateEcDsM(640), closeTo(1, 1e-9));
    expect(NutrientCalculator.estimateEcDsM(1280), closeTo(2, 1e-9));
    expect(NutrientCalculator.estimateEcDsM(0), 0);
    expect(NutrientCalculator.estimateEcDsM(double.nan), 0);
  });

  test('evaluates a solution and flags deficits and excesses', () {
    final result = NutrientCalculator.evaluate(
      liters: 1000,
      doses: [
        MapEntry(potassiumNitrate, 1000),
      ],
    );
    expect(result.nitrogenPpm, closeTo(130, 0.5));
    expect(result.statusFor(NutrientElement.nitrogen, 150), 'deficit');
    expect(result.statusFor(NutrientElement.potassium, 315), 'onTarget');
    expect(result.statusFor(NutrientElement.potassium, 100), 'excess');
    expect(result.estimatedEcDsM, greaterThan(0));
  });

  test('builds a recipe that covers the requested targets', () {
    final recipe = NutrientCalculator.recipeGramsPer1000L(
      targetsPpm: const {
        NutrientElement.nitrogen: 150,
        NutrientElement.potassium: 180,
      },
      products: NutrientCalculator.commonProducts,
    );
    expect(recipe, isNotEmpty);
    final doses = <MapEntry<FertilizerProduct, double>>[];
    for (final product in NutrientCalculator.commonProducts) {
      final grams = recipe[product.name];
      if (grams != null && grams > 0) {
        doses.add(MapEntry(product, grams));
      }
    }
    final result = NutrientCalculator.evaluate(liters: 1000, doses: doses);
    // الأسمدة تحتوي عناصر مشتركة، فالتغطية قد تزيد قليلًا لكن لا تنقص كثيرًا.
    expect(result.nitrogenPpm, greaterThan(140));
    expect(result.potassiumPpm, greaterThan(170));
  });

  test('acid dose neutralises alkalinity and is zero when pH is fine', () {
    final dose = NutrientCalculator.estimateAcidDose(
      alkalinityMgL: 100,
      currentPh: 7.8,
      targetPh: 6.0,
    );
    // 100 مجم/لتر CaCO3 = 2 meq/L × 27.2 مل لكل 1000 لتر.
    expect(dose.mlPer1000L, closeTo(54.4, 0.5));
    expect(dose.acidLabel, contains('كبريتيك'));

    final none = NutrientCalculator.estimateAcidDose(
      alkalinityMgL: 100,
      currentPh: 6.0,
      targetPh: 6.5,
    );
    expect(none.mlPer1000L, 0);
  });

  test('a zero tank volume produces zero ppm instead of infinity', () {
    final result = NutrientCalculator.evaluate(
      liters: 0,
      doses: [
        MapEntry(potassiumNitrate, 100),
      ],
    );
    expect(result.nitrogenPpm, 0);
    expect(result.estimatedEcDsM, 0);
  });

  test('a recipe without targets is empty', () {
    final recipe = NutrientCalculator.recipeGramsPer1000L(
      targetsPpm: const {},
      products: NutrientCalculator.commonProducts,
    );
    expect(recipe, isEmpty);
  });

  test('a magnesium target is covered by magnesium sulfate', () {
    final recipe = NutrientCalculator.recipeGramsPer1000L(
      targetsPpm: const {NutrientElement.magnesium: 32},
      products: NutrientCalculator.commonProducts,
    );
    expect(recipe['سلفات ماغنسيوم'], closeTo(200, 1));
  });

  test('nitric acid needs a larger volume than sulfuric for the same load', () {
    final sulfuric = NutrientCalculator.estimateAcidDose(
      alkalinityMgL: 80,
      currentPh: 7.5,
      targetPh: 6,
    );
    final nitric = NutrientCalculator.estimateAcidDose(
      alkalinityMgL: 80,
      currentPh: 7.5,
      targetPh: 6,
      acid: 'nitric',
    );
    expect(nitric.mlPer1000L, greaterThan(sulfuric.mlPer1000L));
  });
}
