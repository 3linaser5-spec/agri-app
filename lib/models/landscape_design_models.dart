/// نماذج تصميم اللاندسكيب (تنسيق المواقع) وشبكة ريه.
///
/// تعتمد على إحداثيات محلية بالمتر (س، ص) لأن المهندس يرسم على لوحة مسطّحة،
/// ولا يشترط تحديد الموقع بالـ GPS. يمكن تحويل حدود الموقع من الخريطة إلى
/// نفس الإحداثيات إن رغب المستخدم.
library;

import 'dart:math' as math;

/// مصدر المساحة: إدخال يدوي أو رسم/تحديد على الخريطة.
enum LandscapeAreaSource { manual, drawn }

enum LandscapePlantKind { lawn, tree, shrub, flower, palm, cactus, groundcover }

/// طريقة الري المناسبة لكل نوع نبات.
enum IrrigationMethod { drip, microSpray, sprinkler, bubbler }

extension IrrigationMethodLabel on IrrigationMethod {
  String get labelAr => switch (this) {
        IrrigationMethod.drip => 'تنقيط',
        IrrigationMethod.microSpray => 'رشاش صغير',
        IrrigationMethod.sprinkler => 'رشاش',
        IrrigationMethod.bubbler => 'بابلر',
      };

  /// الضغط التصميمي عند النقّاطة بالمتر (عمود ماء).
  double get requiredPressureM => switch (this) {
        IrrigationMethod.drip => 10,
        IrrigationMethod.bubbler => 5,
        IrrigationMethod.microSpray => 15,
        IrrigationMethod.sprinkler => 25,
      };
}

/// نقطة على لوحة التصميم بالمتر.
class PlanPoint {
  final double xM;
  final double yM;
  const PlanPoint(this.xM, this.yM);

  double distanceTo(PlanPoint other) =>
      math.sqrt(math.pow(xM - other.xM, 2) + math.pow(yM - other.yM, 2));

  PlanPoint translate(double dx, double dy) => PlanPoint(xM + dx, yM + dy);

  Map<String, dynamic> toJson() => {'x': xM, 'y': yM};

  factory PlanPoint.fromJson(Map<String, dynamic> json) => PlanPoint(
        (json['x'] as num).toDouble(),
        (json['y'] as num).toDouble(),
      );

  @override
  String toString() => '(${xM.toStringAsFixed(1)}، ${yM.toStringAsFixed(1)})';
}

/// نوع نبات مع طبيعة ريه واحتياجه المائي.
class LandscapePlantType {
  final String id;
  final String nameAr;
  final LandscapePlantKind kind;
  final IrrigationMethod method;

  /// معامل المحصول (FAO-56) — يقود احتياج المياه اليومي.
  final double kc;
  final double canopyDiameterM;
  final double heightM;

  /// تصرف النقّاطة/الرشاش باللتر/دقيقة.
  final double emitterFlowLpm;

  /// المسافة بين صفوف النقاطات (أو صفوف الرشاشات) بالمتر.
  final double lateralSpacingM;

  /// المسافة بين النقاطات على نفس الخط (أو بين الرشاشات) بالمتر.
  final double spacingM;

  final int colorValue;

  const LandscapePlantType({
    required this.id,
    required this.nameAr,
    required this.kind,
    required this.method,
    required this.kc,
    required this.canopyDiameterM,
    required this.heightM,
    required this.emitterFlowLpm,
    required this.lateralSpacingM,
    required this.spacingM,
    required this.colorValue,
  });

  /// عدد النقّاطات/الرشاشات لكل متر مربع.
  double get devicesPerM2 =>
      lateralSpacingM <= 0 || spacingM <= 0 ? 0 : 1 / (lateralSpacingM * spacingM);

  static const List<LandscapePlantType> catalog = [
    LandscapePlantType(
      id: 'lawn',
      nameAr: 'نجيل طبيعي',
      kind: LandscapePlantKind.lawn,
      method: IrrigationMethod.sprinkler,
      kc: 0.85,
      canopyDiameterM: 10,
      heightM: 0.1,
      emitterFlowLpm: 14,
      lateralSpacingM: 8,
      spacingM: 8,
      colorValue: 0xFF4CAF50,
    ),
    LandscapePlantType(
      id: 'olive',
      nameAr: 'زيتون',
      kind: LandscapePlantKind.tree,
      method: IrrigationMethod.drip,
      kc: 0.45,
      canopyDiameterM: 4,
      heightM: 5,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 4,
      spacingM: 3,
      colorValue: 0xFF6B8E4E,
    ),
    LandscapePlantType(
      id: 'ficus',
      nameAr: 'فيكس ظل',
      kind: LandscapePlantKind.tree,
      method: IrrigationMethod.drip,
      kc: 0.60,
      canopyDiameterM: 5,
      heightM: 7,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 5,
      spacingM: 4,
      colorValue: 0xFF2E7D32,
    ),
    LandscapePlantType(
      id: 'palm',
      nameAr: 'نخيل',
      kind: LandscapePlantKind.palm,
      method: IrrigationMethod.drip,
      kc: 0.50,
      canopyDiameterM: 4,
      heightM: 8,
      emitterFlowLpm: 0.133,
      lateralSpacingM: 5,
      spacingM: 5,
      colorValue: 0xFF558B2F,
    ),
    LandscapePlantType(
      id: 'lemon',
      nameAr: 'ليمون',
      kind: LandscapePlantKind.tree,
      method: IrrigationMethod.drip,
      kc: 0.55,
      canopyDiameterM: 3.5,
      heightM: 3.5,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 4,
      spacingM: 3.5,
      colorValue: 0xFF7CB342,
    ),
    LandscapePlantType(
      id: 'bougainvillea',
      nameAr: 'جهنمية',
      kind: LandscapePlantKind.shrub,
      method: IrrigationMethod.drip,
      kc: 0.40,
      canopyDiameterM: 2.5,
      heightM: 2.5,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 1.2,
      spacingM: 1.2,
      colorValue: 0xFFC2185B,
    ),
    LandscapePlantType(
      id: 'jasmine',
      nameAr: 'ياسمين',
      kind: LandscapePlantKind.shrub,
      method: IrrigationMethod.drip,
      kc: 0.55,
      canopyDiameterM: 1.5,
      heightM: 1.6,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 1,
      spacingM: 1,
      colorValue: 0xFFF8BBD0,
    ),
    LandscapePlantType(
      id: 'rose',
      nameAr: 'ورد',
      kind: LandscapePlantKind.flower,
      method: IrrigationMethod.drip,
      kc: 0.70,
      canopyDiameterM: 0.8,
      heightM: 0.8,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 0.6,
      spacingM: 0.5,
      colorValue: 0xFFE53935,
    ),
    LandscapePlantType(
      id: 'lavender',
      nameAr: 'لافندر',
      kind: LandscapePlantKind.groundcover,
      method: IrrigationMethod.microSpray,
      kc: 0.50,
      canopyDiameterM: 0.7,
      heightM: 0.6,
      emitterFlowLpm: 1.2,
      lateralSpacingM: 2,
      spacingM: 2,
      colorValue: 0xFF9C27B0,
    ),
    LandscapePlantType(
      id: 'cactus',
      nameAr: 'صبار وأجاف',
      kind: LandscapePlantKind.cactus,
      method: IrrigationMethod.drip,
      kc: 0.15,
      canopyDiameterM: 1,
      heightM: 1.2,
      emitterFlowLpm: 0.067,
      lateralSpacingM: 1.5,
      spacingM: 1.5,
      colorValue: 0xFF7E9B6B,
    ),
    LandscapePlantType(
      id: 'turf_bermuda',
      nameAr: 'نجيل برمودا',
      kind: LandscapePlantKind.lawn,
      method: IrrigationMethod.sprinkler,
      kc: 0.75,
      canopyDiameterM: 10,
      heightM: 0.08,
      emitterFlowLpm: 12,
      lateralSpacingM: 7,
      spacingM: 7,
      colorValue: 0xFF66BB6A,
    ),
    LandscapePlantType(
      id: 'paved',
      nameAr: 'ممر/أرضية صلبة (بدون ري)',
      kind: LandscapePlantKind.groundcover,
      method: IrrigationMethod.bubbler,
      kc: 0,
      canopyDiameterM: 0,
      heightM: 0,
      emitterFlowLpm: 0,
      lateralSpacingM: 0,
      spacingM: 0,
      colorValue: 0xFFBDBDBD,
    ),
  ];

  bool get needsIrrigation => kc > 0 && emitterFlowLpm > 0;

  static LandscapePlantType? tryById(String? id) {
    if (id == null) return null;
    for (final type in catalog) {
      if (type.id == id) return type;
    }
    return null;
  }

  static LandscapePlantType byId(String id) =>
      tryById(id) ?? (throw ArgumentError.value(id, 'id', 'نوع نبات غير معروف'));

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'kind': kind.name,
        'method': method.name,
        'kc': kc,
        'canopy_diameter_m': canopyDiameterM,
        'height_m': heightM,
        'emitter_flow_lpm': emitterFlowLpm,
        'lateral_spacing_m': lateralSpacingM,
        'spacing_m': spacingM,
        'color': colorValue,
      };
}

/// شكل/مسطح مرسوم على لوحة اللاندسكيب (حديقة، نجيلة، حوض ورد، ممر).
class LandscapeShape {
  final String id;
  final String nameAr;
  final String? plantTypeId;
  final List<PlanPoint> points;

  LandscapeShape({
    required this.id,
    required this.nameAr,
    this.plantTypeId,
    required List<PlanPoint> points,
  }) : points = List<PlanPoint>.unmodifiable(points) {
    if (this.points.length < 3) {
      throw ArgumentError.value(points, 'points', 'يجب أن يحتوي الشكل على 3 نقاط على الأقل');
    }
  }

  /// المساحة بطريقة Shoelace (متر مربع).
  double get areaM2 => polygonArea(points);

  double get widthM {
    final xs = points.map((p) => p.xM);
    return xs.reduce(math.max) - xs.reduce(math.min);
  }

  double get heightM {
    final ys = points.map((p) => p.yM);
    return ys.reduce(math.max) - ys.reduce(math.min);
  }

  PlanPoint get centroid => polygonCentroid(points);

  /// متوسط أبعد مسافة أفقية داخل الشكل (يُستخدم لتقدير طول الخط الفرعي).
  double get longestSpanM {
    var longest = 0.0;
    for (var i = 0; i < points.length; i++) {
      for (var j = i + 1; j < points.length; j++) {
        longest = math.max(longest, points[i].distanceTo(points[j]));
      }
    }
    return longest;
  }

  LandscapePlantType? get plantType => LandscapePlantType.tryById(plantTypeId);

  LandscapeShape copyWith({String? nameAr, String? plantTypeId, List<PlanPoint>? points}) =>
      LandscapeShape(
        id: id,
        nameAr: nameAr ?? this.nameAr,
        plantTypeId: plantTypeId ?? this.plantTypeId,
        points: points ?? this.points,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'plant_type_id': plantTypeId,
        'points': points.map((p) => p.toJson()).toList(growable: false),
      };

  factory LandscapeShape.fromJson(Map<String, dynamic> json) => LandscapeShape(
        id: json['id'].toString(),
        nameAr: json['name_ar']?.toString() ?? 'مسطح',
        plantTypeId: json['plant_type_id']?.toString(),
        points: (json['points'] as List)
            .map((item) => PlanPoint.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
      );

  static double polygonArea(List<PlanPoint> points) {
    if (points.length < 3) return 0;
    var sum = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      sum += a.xM * b.yM - b.xM * a.yM;
    }
    return sum.abs() / 2;
  }

  static PlanPoint polygonCentroid(List<PlanPoint> points) {
    if (points.isEmpty) return const PlanPoint(0, 0);
    if (points.length < 3) {
      final x = points.fold<double>(0, (s, p) => s + p.xM) / points.length;
      final y = points.fold<double>(0, (s, p) => s + p.yM) / points.length;
      return PlanPoint(x, y);
    }
    var areaTwice = 0.0, cx = 0.0, cy = 0.0;
    for (var i = 0; i < points.length; i++) {
      final a = points[i];
      final b = points[(i + 1) % points.length];
      final cross = a.xM * b.yM - b.xM * a.yM;
      areaTwice += cross;
      cx += (a.xM + b.xM) * cross;
      cy += (a.yM + b.yM) * cross;
    }
    if (areaTwice.abs() < 1e-9) {
      final x = points.fold<double>(0, (s, p) => s + p.xM) / points.length;
      final y = points.fold<double>(0, (s, p) => s + p.yM) / points.length;
      return PlanPoint(x, y);
    }
    return PlanPoint(cx / (3 * areaTwice), cy / (3 * areaTwice));
  }
}

/// خطة اللاندسكيب الكاملة التي يرسمها المهندس.
class LandscapePlan {
  final String id;
  final String nameAr;

  /// أبعاد لوحة الرسم بالمتر (تُشتق من مساحة الموقع أو تُدخل يدويًا).
  final double plotWidthM;
  final double plotHeightM;

  final LandscapeAreaSource areaSource;

  /// المساحة عند الإدخال اليدوي (متر مربع) — لا يشترط رسم حدود.
  final double manualAreaM2;

  final List<LandscapeShape> shapes;

  /// مكان مصدر المياه/المضخة على اللوحة.
  final PlanPoint waterSourcePoint;

  /// فرق المنسوب بين مصدر المياه وأعلى نقطة ري (متر).
  final double staticLiftM;

  /// أقصى تصرف متاح للمصدر (لتر/دقيقة) — يقود تقسيم المناطق.
  final double availableFlowLpm;

  LandscapePlan({
    required this.id,
    required this.nameAr,
    required this.plotWidthM,
    required this.plotHeightM,
    this.areaSource = LandscapeAreaSource.drawn,
    this.manualAreaM2 = 0,
    List<LandscapeShape> shapes = const [],
    this.waterSourcePoint = const PlanPoint(0, 0),
    this.staticLiftM = 5,
    this.availableFlowLpm = 120,
  }) : shapes = List<LandscapeShape>.unmodifiable(shapes) {
    if (manualAreaM2 < 0) {
      throw ArgumentError.value(manualAreaM2, 'manualAreaM2', 'المساحة لا تكون سالبة');
    }
  }

  double get drawnAreaM2 =>
      shapes.fold<double>(0, (sum, shape) => sum + shape.areaM2);

  /// المساحة المعتمدة: المكتوبة يدويًا أو المحسوبة من الرسم.
  double get areaM2 =>
      areaSource == LandscapeAreaSource.manual ? manualAreaM2 : drawnAreaM2;

  bool get readyForDesign => areaM2 > 0 && shapes.any((s) => s.plantType?.needsIrrigation == true);

  LandscapePlan copyWith({
    String? nameAr,
    double? plotWidthM,
    double? plotHeightM,
    LandscapeAreaSource? areaSource,
    double? manualAreaM2,
    List<LandscapeShape>? shapes,
    PlanPoint? waterSourcePoint,
    double? staticLiftM,
    double? availableFlowLpm,
  }) =>
      LandscapePlan(
        id: id,
        nameAr: nameAr ?? this.nameAr,
        plotWidthM: plotWidthM ?? this.plotWidthM,
        plotHeightM: plotHeightM ?? this.plotHeightM,
        areaSource: areaSource ?? this.areaSource,
        manualAreaM2: manualAreaM2 ?? this.manualAreaM2,
        shapes: shapes ?? this.shapes,
        waterSourcePoint: waterSourcePoint ?? this.waterSourcePoint,
        staticLiftM: staticLiftM ?? this.staticLiftM,
        availableFlowLpm: availableFlowLpm ?? this.availableFlowLpm,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name_ar': nameAr,
        'plot_width_m': plotWidthM,
        'plot_height_m': plotHeightM,
        'area_source': areaSource.name,
        'manual_area_m2': manualAreaM2,
        'shapes': shapes.map((s) => s.toJson()).toList(growable: false),
        'water_source': waterSourcePoint.toJson(),
        'static_lift_m': staticLiftM,
        'available_flow_lpm': availableFlowLpm,
      };

  factory LandscapePlan.fromJson(Map<String, dynamic> json) => LandscapePlan(
        id: json['id'].toString(),
        nameAr: json['name_ar']?.toString() ?? 'تصميم',
        plotWidthM: (json['plot_width_m'] as num).toDouble(),
        plotHeightM: (json['plot_height_m'] as num).toDouble(),
        areaSource: LandscapeAreaSource.values
            .firstWhere((v) => v.name == json['area_source'], orElse: () => LandscapeAreaSource.drawn),
        manualAreaM2: (json['manual_area_m2'] as num?)?.toDouble() ?? 0,
        shapes: (json['shapes'] as List? ?? const [])
            .map((item) => LandscapeShape.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(growable: false),
        waterSourcePoint: PlanPoint.fromJson(
          Map<String, dynamic>.from(json['water_source'] as Map? ?? const {'x': 0, 'y': 0}),
        ),
        staticLiftM: (json['static_lift_m'] as num?)?.toDouble() ?? 5,
        availableFlowLpm: (json['available_flow_lpm'] as num?)?.toDouble() ?? 120,
      );
}
