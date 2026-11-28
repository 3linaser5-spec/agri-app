import 'dart:math' as math;

import '../models/irrigation_bom_models.dart';
import '../models/irrigation_design_models.dart';
import '../models/landscape_design_models.dart';
import 'landscape_hydraulic_design_service.dart';

/// يبني قائمة مشتريات (كميات بدون أسعار) من نتائج الحاسبة الهيدروليكية
/// للأنظمة الأربعة، أو من تصميم المستخدم المحفوظ، أو من تصميم اللاندسكيب.
///
/// الكميات مبنية على مخرجات [IrrigationCalc](../utils/irrigation_calc.dart)
/// والتصميم المحفوظ نفسه (النباتات، النقاطات، الرشاشات، أطوال الخطوط،
/// القطر المقترح، المحابس، المعدات…).
class IrrigationBomService {
  IrrigationBomService._();

  static const String _pipeCategory = 'مواسير';
  static const String _emitterCategory = 'نقاطات';
  static const String _sprinklerCategory = 'رشاشات';
  static const String _valveCategory = 'محابس';
  static const String _equipmentCategory = 'معدات';
  static const String _fittingCategory = 'ملحقات ووصلات';
  static const String _surfaceCategory = 'بوابات الري السطحي';

  /// نسبة هالك تقريبية في المواسير (قص ووصلات).
  static const double _pipeWaste = 0.05;

  // ───────────────────── الري بالتنقيط ─────────────────────

  static IrrigationBom buildDrip({
    required double areaM2,
    required double lateralTotalLengthM,
    required double totalEmitters,
    required double emitterLph,
    required double lateralLengthM,
    required double lateralDiameterMm,
    required double mainLengthM,
    required double mainDiameterMm,
    required int sectors,
    required double sectorFlowM3h,
    double? motorKw,
    double? motorHp,
    double? totalHeadM,
  }) {
    final items = <IrrigationBomItem>[];
    _add(items,
        code: 'main-pipe',
        category: _pipeCategory,
        name: 'ماسورة رئيسية',
        spec: 'Ø ${_n(mainDiameterMm)} مم PE',
        unit: 'م',
        quantity: mainLengthM * (1 + _pipeWaste));
    _add(items,
        code: 'lateral-pipe',
        category: _pipeCategory,
        name: 'خطوط فرعية (خراطيم/مواسير تنقيط)',
        spec: 'Ø ${_n(lateralDiameterMm)} مم × ${_n(lateralLengthM)} م للخط',
        unit: 'م',
        quantity: lateralTotalLengthM * (1 + _pipeWaste));
    _add(items,
        code: 'emitters',
        category: _emitterCategory,
        name: 'نقاطات',
        spec: '${_n(emitterLph)} لتر/ساعة',
        unit: 'عدد',
        quantity: totalEmitters * 1.02);
    _add(items,
        code: 'sector-valve',
        category: _valveCategory,
        name: 'محبس قطاع',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'عدد',
        quantity: sectors.toDouble());
    _add(items,
        code: 'main-valve',
        category: _valveCategory,
        name: 'محبس رئيسي (بوابة)',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'عدد',
        quantity: 1);
    _add(items,
        code: 'flush-valve',
        category: _valveCategory,
        name: 'محبس غسيل نهايات الخطوط',
        unit: 'عدد',
        quantity: sectors.toDouble());
    _add(items,
        code: 'filter',
        category: _equipmentCategory,
        name: 'فلتر (رملي/ديسكي)',
        spec: 'لتصرف ${_n(sectorFlowM3h)} م³/ساعة',
        unit: 'وحدة',
        quantity: _filterUnits(sectorFlowM3h, perUnitFlow: 30));
    _addPump(items,
        motorKw: motorKw,
        motorHp: motorHp,
        totalHeadM: totalHeadM,
        flowM3h: sectorFlowM3h);

    return _finish(
      IrrigationSystemKind.drip,
      areaM2 / 4200,
      items,
      notes: [
        'الكميات محسوبة من تصميم الحاسبة: ${_n(totalEmitters)} نقاطة و'
            '${_n(lateralTotalLengthM)} م خطوط فرعية.',
        if (sectorFlowM3h.isFinite && sectorFlowM3h > 0)
          'الفلتر مقاس على تصرف القطاع ${_n(sectorFlowM3h)} م³/ساعة؛ راجع '
              'مهندس الري لو حابب فلتر احتياطي.',
      ],
    );
  }

  // ───────────────────── الري بالرش ─────────────────────

  static IrrigationBom buildSprinkler({
    required double areaM2,
    required double fieldWidthM,
    required double fieldLengthM,
    required double spacingAcrossM,
    required double spacingAlongM,
    required double sprinklerFlowM3h,
    required int sprinklers,
    required int sectors,
    required double sectorFlowM3h,
    required double mainLengthM,
    required double mainDiameterMm,
    required double lateralDiameterMm,
    double? motorKw,
    double? motorHp,
    double? totalHeadM,
  }) {
    final items = <IrrigationBomItem>[];
    final lateralLines = spacingAcrossM > 0
        ? (fieldWidthM / spacingAcrossM).ceil() + 1
        : 1;
    _add(items,
        code: 'main-pipe',
        category: _pipeCategory,
        name: 'ماسورة رئيسية',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'م',
        quantity: mainLengthM * (1 + _pipeWaste));
    _add(items,
        code: 'lateral-pipe',
        category: _pipeCategory,
        name: 'خطوط الرش الفرعية',
        spec: 'Ø ${_n(lateralDiameterMm)} مم × $lateralLines خط',
        unit: 'م',
        quantity: lateralLines * fieldLengthM * (1 + _pipeWaste));
    _add(items,
        code: 'sprinklers',
        category: _sprinklerCategory,
        name: 'رشاشات',
        spec: '${_n(sprinklerFlowM3h)} م³/ساعة × ${_n(spacingAlongM)} م',
        unit: 'عدد',
        quantity: sprinklers.toDouble());
    _add(items,
        code: 'risers',
        category: _sprinklerCategory,
        name: 'حوامل/أعمدة الرشاشات',
        unit: 'عدد',
        quantity: sprinklers.toDouble());
    _add(items,
        code: 'sector-valve',
        category: _valveCategory,
        name: 'محبس قطاع',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'عدد',
        quantity: sectors.toDouble());
    _add(items,
        code: 'main-valve',
        category: _valveCategory,
        name: 'محبس رئيسي (بوابة)',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'عدد',
        quantity: 1);
    _add(items,
        code: 'filter',
        category: _equipmentCategory,
        name: 'فلتر (رملي/ديسكي)',
        spec: 'لتصرف ${_n(sectorFlowM3h)} م³/ساعة',
        unit: 'وحدة',
        quantity: _filterUnits(sectorFlowM3h, perUnitFlow: 40));
    _addPump(items,
        motorKw: motorKw,
        motorHp: motorHp,
        totalHeadM: totalHeadM,
        flowM3h: sectorFlowM3h);

    return _finish(
      IrrigationSystemKind.sprinkler,
      areaM2 / 4200,
      items,
      notes: [
        '$lateralLines خط فرعي بطول ${_n(fieldLengthM)} م و$sprinklers رشاش.',
        'الكميات لا تشمل أعمال الحفر والمد والتركيب — تُقدَّر منفصلة مع المقاول.',
      ],
    );
  }

  // ───────────────────── الري السطحي ─────────────────────

  static IrrigationBom buildSurface({
    required double areaM2,
    required double fieldWidthM,
    required double furrowSpacingM,
    required double streamLps,
  }) {
    final items = <IrrigationBomItem>[];
    final furrows = furrowSpacingM > 0
        ? (fieldWidthM / furrowSpacingM).ceil()
        : 0;
    _add(items,
        code: 'surface-gates',
        category: _surfaceCategory,
        name: 'بوابات/سيفونات الأتلام',
        spec: 'تصرف ${_n(streamLps)} لتر/ث لكل مجرى',
        unit: 'عدد',
        quantity: furrows.toDouble());
    _add(items,
        code: 'main-valve',
        category: _valveCategory,
        name: 'محبس رئيسي للتحكم في الري',
        unit: 'عدد',
        quantity: 1);

    return _finish(
      IrrigationSystemKind.surface,
      areaM2 / 4200,
      items,
      notes: [
        'الري السطحي غالبًا بدون شبكة مواسير: البنود هنا للبوابات فقط.',
        'أعمال التسوية والأحواض والقنوات تُقدَّر منفصلة، وكذلك المضخة لو '
            'المصدر محتاج رفع.',
      ],
    );
  }

  // ───────────────────── الري المحوري ─────────────────────

  static IrrigationBom buildPivot({
    required double radiusM,
    required double flowM3h,
    required double mainLengthM,
    required double mainDiameterMm,
    double? motorKw,
    double? motorHp,
    double? totalHeadM,
  }) {
    final items = <IrrigationBomItem>[];
    final spans = radiusM > 0 ? (radiusM / 55).ceil() : 0;
    _add(items,
        code: 'pivot-machine',
        category: _equipmentCategory,
        name: 'بيفوت محوري كامل',
        unit: 'م',
        spec: 'ذراع ${_n(radiusM)} م ($spans برج)',
        quantity: radiusM);
    _add(items,
        code: 'end-gun',
        category: _equipmentCategory,
        name: 'رشاش نهاية الذراع (End Gun)',
        unit: 'عدد',
        quantity: 1);
    _add(items,
        code: 'main-pipe',
        category: _pipeCategory,
        name: 'ماسورة تغذية البيفوت',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'م',
        quantity: mainLengthM * (1 + _pipeWaste));
    _add(items,
        code: 'main-valve',
        category: _valveCategory,
        name: 'محبس رئيسي',
        spec: 'Ø ${_n(mainDiameterMm)} مم',
        unit: 'عدد',
        quantity: 1);
    _add(items,
        code: 'filter',
        category: _equipmentCategory,
        name: 'فلتر رئيسي',
        spec: 'لتصرف ${_n(flowM3h)} م³/ساعة',
        unit: 'وحدة',
        quantity: _filterUnits(flowM3h, perUnitFlow: 60));
    _addPump(items,
        motorKw: motorKw,
        motorHp: motorHp,
        totalHeadM: totalHeadM,
        flowM3h: flowM3h);

    return _finish(
      IrrigationSystemKind.pivot,
      math.pi * radiusM * radiusM / 4200,
      items,
      notes: [
        'البيفوت محسوب بالمتر الطولي للذراع؛ اطلب عرض سعر من المورد لأنه '
            'بيتغير حسب عدد الأبراج ونظام التعليق.',
      ],
    );
  }

  // ───────────────────── تصميم المستخدم المحفوظ ─────────────────────

  /// قائمة كاملة لكل خامات تصميم الري المحفوظ اللي عمله المستخدم:
  /// المضخة، كل المواسير (مجمّعة بالقطر والمادة)، المحابس، المعدات،
  /// الشتلات الموضوعة على المخطط، والملحقات.
  static IrrigationBom buildFromProject(
    IrrigationDesignProject project, {
    String name = '',
  }) {
    final items = <IrrigationBomItem>[];

    _add(items,
        code: 'pump-set',
        category: _equipmentCategory,
        name: 'طقم مضخة ومحرك',
        spec: '${_n(project.pump.powerKw, 1)} كيلوواط — '
            '${_n(project.pump.flowRateLpm, 0)} لتر/دقيقة × '
            '${_n(project.pump.headM, 1)} م',
        unit: 'طقم',
        quantity: 1);

    // المواسير المحددة في التصميم، مجمّعة بالقطر والمادة.
    final pipeGroups = <String, List<Pipe>>{};
    for (final pipe in project.pipes) {
      final key = '${pipe.material}|${_n(pipe.diameter)}|${pipe.diameterUnit}';
      pipeGroups.putIfAbsent(key, () => <Pipe>[]).add(pipe);
    }
    for (final entry in pipeGroups.entries) {
      final first = entry.value.first;
      final lengthM = entry.value.fold<double>(0, (sum, pipe) => sum + pipe.lengthM);
      _add(items,
          code: 'pipe-${entry.key}',
          category: _pipeCategory,
          name: 'ماسورة ${first.material}',
          spec: 'Ø ${_n(first.diameter)} '
              '${first.diameterUnit == 'in' ? 'بوصة' : 'مم'}',
          unit: 'م',
          quantity: lengthM * (1 + _pipeWaste));
    }

    // لو المصمم رسم مسارات بس ومفيش مواسير مسجلة، نحسب الطول من المسارات.
    if (project.pipes.isEmpty && project.pipeRoutes.isNotEmpty) {
      final routeGroups = <String, List<IrrigationPipeRoute>>{};
      for (final route in project.pipeRoutes) {
        final key = '${route.material}|${_n(route.diameterMm)}';
        routeGroups.putIfAbsent(key, () => <IrrigationPipeRoute>[]).add(route);
      }
      for (final entry in routeGroups.entries) {
        final first = entry.value.first;
        final lengthM = entry.value
            .fold<double>(0, (sum, route) => sum + _polylineLengthM(route.points));
        _add(items,
            code: 'route-${entry.key}',
            category: _pipeCategory,
            name: 'ماسورة ${first.material}',
            spec: 'Ø ${_n(first.diameterMm)} مم — من مسارات المخطط',
            unit: 'م',
            quantity: lengthM * (1 + _pipeWaste));
      }
    }

    final valveGroups = <String, List<Valve>>{};
    for (final valve in project.valves) {
      final key = '${valve.type}|${_n(valve.diameterMm)}';
      valveGroups.putIfAbsent(key, () => <Valve>[]).add(valve);
    }
    for (final entry in valveGroups.entries) {
      final first = entry.value.first;
      _add(items,
          code: 'valve-${entry.key}',
          category: _valveCategory,
          name: 'محبس ${first.type}',
          spec: 'Ø ${_n(first.diameterMm)} مم',
          unit: 'عدد',
          quantity: entry.value.length.toDouble());
    }

    final equipmentGroups = <String, List<IrrigationEquipment>>{};
    for (final equipment in project.equipment) {
      final key = '${equipment.type}|${equipment.nameAr}|${equipment.nameEn}';
      equipmentGroups.putIfAbsent(key, () => <IrrigationEquipment>[]).add(equipment);
    }
    for (final entry in equipmentGroups.entries) {
      final first = entry.value.first;
      final quantity =
          entry.value.fold<int>(0, (sum, equipment) => sum + equipment.quantity);
      _add(items,
          code: 'equipment-${entry.key}',
          category: _equipmentCategory,
          name: first.nameAr.isNotEmpty
              ? first.nameAr
              : (first.nameEn.isNotEmpty ? first.nameEn : first.type),
          spec: 'تصرف ${_n(first.flowRateLpm, 0)} لتر/دقيقة — '
              'ضغط ${_n(first.operatingPressureBar, 1)} بار',
          unit: 'عدد',
          quantity: quantity.toDouble());
    }

    // الشتلات: كل نبات موضوع على المخطط بند.
    final plantCounts = <String, int>{};
    for (final placement in project.placements) {
      final plantId = placement.plantId;
      if (plantId == null || plantId.isEmpty) continue;
      plantCounts[plantId] = (plantCounts[plantId] ?? 0) + 1;
    }
    if (plantCounts.isEmpty) {
      for (final plant in project.plants) {
        _add(items,
            code: 'plant-${plant.id}',
            category: 'شتلات',
            name: plant.nameAr.isNotEmpty ? plant.nameAr : plant.id,
            spec: 'نبات محدد في التصميم بدون عدد على المخطط',
            unit: 'عدد',
            quantity: 1);
      }
    } else {
      for (final entry in plantCounts.entries) {
        final plant = project.plants
            .where((item) => item.id == entry.key)
            .toList(growable: false);
        _add(items,
            code: 'plant-${entry.key}',
            category: 'شتلات',
            name: plant.isNotEmpty && plant.first.nameAr.isNotEmpty
                ? plant.first.nameAr
                : entry.key,
            spec: 'عدد النباتات على المخطط',
            unit: 'عدد',
            quantity: entry.value.toDouble());
      }
    }

    return _finish(
      IrrigationSystemKind.mixed,
      (project.siteBoundary.declaredArea ?? 0),
      items,
      name: name.isNotEmpty ? name : project.nameAr,
      notes: [
        'القائمة دي فيها كل خامات التصميم: ${project.pipes.length} ماسورة، '
            '${project.valves.length} محبس، ${project.equipment.length} معدة، '
            '${project.zones.length} منطقة.',
        'الكميات محسوبة من التصميم نفسه — راجعها على الطبيعة قبل الشراء.',
      ],
    );
  }

  /// قائمة خامات تصميم اللاندسكيب (نباتات + مواسير + محابس + مضخة).
  static IrrigationBom buildFromLandscape({
    required LandscapePlan plan,
    required LandscapeHydraulicDesign design,
  }) {
    final items = <IrrigationBomItem>[];
    var index = 0;
    for (final line in design.billOfMaterials) {
      index++;
      _add(items,
          code: 'landscape-$index',
          category: _landscapeCategory(line.itemAr),
          name: line.itemAr,
          unit: line.unitAr,
          quantity: line.quantity);
    }

    return _finish(
      IrrigationSystemKind.landscape,
      design.totalAreaM2 / 4200,
      items,
      name: plan.nameAr,
      notes: [
        'الكميات جاية من التصميم الهيدروليكي للاندسكيب (${design.zones.length} منطقة).',
        'لو ضفت نباتات أو مسطحات بعد التصميم، أعد توليد القائمة عشان الكميات تتحدّث.',
      ],
    );
  }

  static String _landscapeCategory(String item) {
    if (item.contains('ماسورة') || item.contains('خط')) return _pipeCategory;
    if (item.contains('محبس')) return _valveCategory;
    if (item.contains('شتل') || item.contains('نبات')) return 'شتلات';
    if (item.contains('نقّاط') || item.contains('رشاش')) return _emitterCategory;
    return _equipmentCategory;
  }

  static double _polylineLengthM(List<GeoCoordinate> points) {
    var total = 0.0;
    for (var i = 0; i < points.length - 1; i++) {
      total += _distanceM(points[i], points[i + 1]);
    }
    return total;
  }

  /// مسافة تقريبية بالمتر بين نقطتين (haversine).
  static double _distanceM(GeoCoordinate a, GeoCoordinate b) {
    const earthRadius = 6371000.0;
    final dLat = _radians(b.latitude - a.latitude);
    final dLon = _radians(b.longitude - a.longitude);
    final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(a.latitude)) *
            math.cos(_radians(b.latitude)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * earthRadius * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _radians(double degrees) => degrees * math.pi / 180;

  // ───────────────────── أدوات مشتركة ─────────────────────

  static void _add(
    List<IrrigationBomItem> items, {
    required String code,
    required String category,
    required String name,
    String spec = '',
    required String unit,
    required double quantity,
  }) {
    if (!quantity.isFinite || quantity <= 0) return;
    items.add(IrrigationBomItem(
      code: code,
      category: category,
      name: name,
      spec: spec,
      unit: unit,
      quantity: _round(quantity, 0),
    ));
  }

  static void _addPump(
    List<IrrigationBomItem> items, {
    required double? motorKw,
    required double? motorHp,
    required double? totalHeadM,
    required double flowM3h,
  }) {
    final kw = motorKw;
    if (kw == null || !kw.isFinite || kw <= 0) return;
    final head = totalHeadM != null && totalHeadM.isFinite
        ? ' — TDH ${_n(totalHeadM)} م'
        : '';
    _add(items,
        code: 'pump-set',
        category: _equipmentCategory,
        name: 'طقم مضخة ومحرك',
        spec: '${_n(kw, 1)} كيلوواط'
            '${motorHp != null && motorHp.isFinite ? ' ≈ ${_n(motorHp, 1)} حصان' : ''}'
            ' — تصرف ${_n(flowM3h)} م³/س$head',
        unit: 'طقم',
        quantity: 1);
  }

  static double _filterUnits(double flowM3h, {required double perUnitFlow}) {
    if (!flowM3h.isFinite || flowM3h <= 0 || perUnitFlow <= 0) return 1;
    return math.max(1, (flowM3h / perUnitFlow).ceil()).toDouble();
  }

  static IrrigationBom _finish(
    IrrigationSystemKind system,
    double areaFeddan,
    List<IrrigationBomItem> items, {
    List<String> notes = const [],
    String name = '',
  }) {
    // بند الملحقات مقطوعية: كميته تتحدد من تفاصيل التركيب عند المورد.
    if (items.isNotEmpty) {
      items.add(IrrigationBomItem(
        code: 'fittings',
        category: _fittingCategory,
        name: 'وصلات وملحقات تركيب',
        spec: 'تُحسب حسب تفاصيل التركيب',
        unit: 'مقطوعية',
        quantity: 1,
      ));
    }
    return IrrigationBom(
      system: system,
      name: name,
      areaFeddan: areaFeddan.isFinite && areaFeddan > 0 ? areaFeddan : 0,
      items: List<IrrigationBomItem>.unmodifiable(items),
      notes: notes,
    );
  }

  // ───────────────────── التصدير ─────────────────────

  /// CSV يفتح في Excel — نفس ترتيب الأعمدة في كل الأنواع.
  static String toCsv(IrrigationBom bom) {
    String cell(Object? value) =>
        '"${(value ?? '').toString().replaceAll('"', '""')}"';
    final rows = <List<Object?>>[
      ['الفئة', 'الصنف', 'المواصفات', 'الوحدة', 'الكمية'],
      for (final item in bom.items)
        [item.category, item.name, item.spec, item.unit, _num(item.quantity)],
    ];
    return rows.map((row) => row.map(cell).join(',')).join('\n');
  }

  /// ملخص نصي للمشاركة السريعة على واتساب.
  static String summaryText(IrrigationBom bom) {
    final title = bom.name.isEmpty ? bom.systemLabel : bom.name;
    final buffer = StringBuffer()
      ..writeln('قائمة مشتريات ($title) — تطبيق نباتي')
      ..writeln('المساحة: ${_n(bom.areaFeddan)} فدان')
      ..writeln('');
    for (final item in bom.items) {
      buffer.writeln('• ${item.name}: ${_n(item.quantity)} ${item.unit}');
    }
    buffer
      ..writeln('')
      ..writeln('القائمة بدون أسعار — تُطلب عروض أسعار من الموردين.');
    return buffer.toString();
  }

  static String _n(double value, [int digits = 2]) {
    if (!value.isFinite) return '-';
    var text = value.toStringAsFixed(digits);
    if (text.contains('.')) {
      text = text.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '');
    }
    return text;
  }

  static String _num(double value) {
    if (!value.isFinite) return '0';
    return value.toStringAsFixed(2);
  }

  static double _round(double value, int digits) {
    final factor = math.pow(10, digits).toDouble();
    return (value * factor).round() / factor;
  }
}
