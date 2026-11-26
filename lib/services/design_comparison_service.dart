import 'dart:math' as math;

import '../models/irrigation_design_models.dart';

/// أسعار تقديرية (بالجنيه) لمقارنة تكلفة تصميمين. القيم افتراضية للتوجيه
/// فقط، ويمكن تعديلها قبل المقارنة.
class DesignCostRates {
  final double pipeMeterPrice;
  final double valvePrice;
  final double equipmentPrice;
  final double plantPrice;
  final double pumpPrice;

  const DesignCostRates({
    this.pipeMeterPrice = 60,
    this.valvePrice = 350,
    this.equipmentPrice = 45,
    this.plantPrice = 25,
    this.pumpPrice = 15000,
  });
}

/// أرقام تصميم واحد المستخدمة في المقارنة.
class DesignSnapshot {
  final String projectId;
  final String name;
  final double areaM2;
  final int zones;
  final double totalFlowLpm;
  final double averageApplicationRateMmH;
  final double totalPipeMeters;
  final int valves;
  final int equipment;
  final int plants;
  final double pumpPowerKw;
  final double estimatedCost;
  final double dailyWaterM3;

  const DesignSnapshot({
    required this.projectId,
    required this.name,
    required this.areaM2,
    required this.zones,
    required this.totalFlowLpm,
    required this.averageApplicationRateMmH,
    required this.totalPipeMeters,
    required this.valves,
    required this.equipment,
    required this.plants,
    required this.pumpPowerKw,
    required this.estimatedCost,
    required this.dailyWaterM3,
  });

  double get costPerM2 => areaM2 <= 0 ? 0 : estimatedCost / areaM2;
}

/// صف مقارنة: قيمة كل تصميم والفرق وأيهما أفضل.
class ComparisonRow {
  final String label;
  final String unit;
  final double valueA;
  final double valueB;
  final bool higherIsBetter;

  const ComparisonRow({
    required this.label,
    required this.unit,
    required this.valueA,
    required this.valueB,
    this.higherIsBetter = true,
  });

  double get difference => valueB - valueA;

  double get percentDifference {
    if (valueA == 0) return valueB == 0 ? 0 : 100;
    return (valueB - valueA) / valueA * 100;
  }

  /// 'a' أو 'b' أو 'tie'.
  String get better {
    if (valueA == valueB) return 'tie';
    final aWins = higherIsBetter ? valueA > valueB : valueA < valueB;
    return aWins ? 'a' : 'b';
  }
}

/// نتيجة مقارنة تصميمين.
class DesignComparisonResult {
  final DesignSnapshot a;
  final DesignSnapshot b;
  final List<ComparisonRow> rows;

  const DesignComparisonResult({
    required this.a,
    required this.b,
    required this.rows,
  });
}

/// خدمات مقارنة تصميمين من حيث المساحة والتصرف والتكلفة التقديرية.
class DesignComparisonService {
  const DesignComparisonService();

  static const double designDailyMm = 5;

  DesignSnapshot snapshot(
    IrrigationDesignProject project, {
    DesignCostRates rates = const DesignCostRates(),
  }) {
    final area = project.siteBoundary.declaredArea ?? _polygonArea(project);
    var totalFlow = 0.0;
    var rateSum = 0.0;
    for (final zone in project.zones) {
      totalFlow += zone.designFlowLpm;
      rateSum += zone.applicationRateMmH;
    }
    final pipeMeters = project.pipes.fold<double>(0, (sum, p) => sum + p.lengthM);
    final routeMeters = project.pipeRoutes.fold<double>(0, (sum, route) {
      var length = 0.0;
      for (var i = 0; i < route.points.length - 1; i++) {
        length += _distanceM(route.points[i], route.points[i + 1]);
      }
      return sum + length;
    });
    final equipmentCount =
        project.equipment.fold<int>(0, (sum, item) => sum + item.quantity);
    final cost = pipeMeters * rates.pipeMeterPrice +
        routeMeters * rates.pipeMeterPrice +
        project.valves.length * rates.valvePrice +
        equipmentCount * rates.equipmentPrice +
        project.plants.length * rates.plantPrice +
        rates.pumpPrice;
    // مياه يومية تقديرية: الاحتياج الصافي × المساحة ÷ 1000.
    final dailyWater = area * designDailyMm / 1000;
    return DesignSnapshot(
      projectId: project.id,
      name: project.nameAr.isEmpty ? project.nameEn : project.nameAr,
      areaM2: area,
      zones: project.zones.length,
      totalFlowLpm: totalFlow,
      averageApplicationRateMmH:
          project.zones.isEmpty ? 0 : rateSum / project.zones.length,
      totalPipeMeters: pipeMeters + routeMeters,
      valves: project.valves.length,
      equipment: equipmentCount,
      plants: project.plants.length,
      pumpPowerKw: project.pump.powerKw,
      estimatedCost: cost,
      dailyWaterM3: dailyWater,
    );
  }

  DesignComparisonResult compare(
    IrrigationDesignProject a,
    IrrigationDesignProject b, {
    DesignCostRates rates = const DesignCostRates(),
  }) {
    final snapshotA = snapshot(a, rates: rates);
    final snapshotB = snapshot(b, rates: rates);
    return DesignComparisonResult(
      a: snapshotA,
      b: snapshotB,
      rows: [
        ComparisonRow(
          label: 'المساحة',
          unit: 'م²',
          valueA: snapshotA.areaM2,
          valueB: snapshotB.areaM2,
        ),
        ComparisonRow(
          label: 'التكلفة التقديرية',
          unit: 'ج.م',
          valueA: snapshotA.estimatedCost,
          valueB: snapshotB.estimatedCost,
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'تكلفة المتر المربع',
          unit: 'ج.م/م²',
          valueA: snapshotA.costPerM2,
          valueB: snapshotB.costPerM2,
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'التصرف الكلي',
          unit: 'لتر/دقيقة',
          valueA: snapshotA.totalFlowLpm,
          valueB: snapshotB.totalFlowLpm,
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'معدل التطبيق',
          unit: 'مم/ساعة',
          valueA: snapshotA.averageApplicationRateMmH,
          valueB: snapshotB.averageApplicationRateMmH,
        ),
        ComparisonRow(
          label: 'طول المواسير',
          unit: 'م',
          valueA: snapshotA.totalPipeMeters,
          valueB: snapshotB.totalPipeMeters,
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'عدد المناطق',
          unit: 'منطقة',
          valueA: snapshotA.zones.toDouble(),
          valueB: snapshotB.zones.toDouble(),
        ),
        ComparisonRow(
          label: 'المحابس',
          unit: 'قطعة',
          valueA: snapshotA.valves.toDouble(),
          valueB: snapshotB.valves.toDouble(),
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'المياه اليومية',
          unit: 'م³',
          valueA: snapshotA.dailyWaterM3,
          valueB: snapshotB.dailyWaterM3,
          higherIsBetter: false,
        ),
        ComparisonRow(
          label: 'قدرة المضخة',
          unit: 'كيلوواط',
          valueA: snapshotA.pumpPowerKw,
          valueB: snapshotB.pumpPowerKw,
          higherIsBetter: false,
        ),
      ],
    );
  }

  /// مساحة الحدود بأمتار مربعة (إسقاط تقريبي للمساحات الصغيرة).
  static double _polygonArea(IrrigationDesignProject project) {
    final points = project.siteBoundary.points;
    if (points.length < 3) return 0;
    var total = 0.0;
    for (var i = 0; i < points.length; i++) {
      final p1 = points[i];
      final p2 = points[(i + 1) % points.length];
      total += p1.longitude * p2.latitude - p2.longitude * p1.latitude;
    }
    final meanLat = points.map((p) => p.latitude).reduce((a, b) => a + b) /
        points.length;
    const metersPerDegree = 111320.0;
    final cosLat = math.cos(meanLat * math.pi / 180);
    return (total.abs() / 2) * metersPerDegree * metersPerDegree * cosLat;
  }

  static double _distanceM(GeoCoordinate a, GeoCoordinate b) {
    const metersPerDegree = 111320.0;
    final lat = (a.latitude + b.latitude) / 2 * math.pi / 180;
    final dx = (b.longitude - a.longitude) * metersPerDegree * math.cos(lat);
    final dy = (b.latitude - a.latitude) * metersPerDegree;
    return math.sqrt(dx * dx + dy * dy);
  }
}
