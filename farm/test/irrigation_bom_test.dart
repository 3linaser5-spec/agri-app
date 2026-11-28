import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:agri_app/models/irrigation_bom_models.dart';
import 'package:agri_app/models/irrigation_design_models.dart';
import 'package:agri_app/models/landscape_design_models.dart';
import 'package:agri_app/screens/calculators/irrigation_bom_screen.dart';
import 'package:agri_app/services/irrigation_bom_service.dart';
import 'package:agri_app/services/landscape_hydraulic_design_service.dart';

const _boundary = <GeoCoordinate>[
  GeoCoordinate(latitude: 30.000, longitude: 31.000),
  GeoCoordinate(latitude: 30.001, longitude: 31.000),
  GeoCoordinate(latitude: 30.000, longitude: 31.001),
];

IrrigationDesignProject _project({
  List<Pipe> pipes = const [],
  List<Valve> valves = const [],
  List<IrrigationEquipment> equipment = const [],
  List<PlantSpecies> plants = const [],
  List<IrrigationMapPlacement> placements = const [],
  List<IrrigationPipeRoute> routes = const [],
}) =>
    IrrigationDesignProject(
      id: 'proj',
      nameAr: 'مزرعة النخيل',
      siteBoundary: SiteBoundary(
        id: 'boundary',
        points: _boundary,
        declaredArea: 2,
      ),
      pipes: pipes,
      valves: valves,
      equipment: equipment,
      plants: plants,
      placements: placements,
      pipeRoutes: routes,
      pump: Pump(
        id: 'pump',
        type: 'centrifugal',
        flowRateLpm: 500,
        headM: 40,
        powerKw: 11,
        efficiency: 0.7,
      ),
      version: DesignVersion(
        major: 1,
        minor: 0,
        patch: 0,
        createdAt: DateTime(2026, 1, 1),
      ),
    );

IrrigationMapPlacement _placement(String id, String plantId) =>
    IrrigationMapPlacement(
      id: id,
      kind: 'tree',
      coordinate: const GeoCoordinate(latitude: 30.0005, longitude: 31.0005),
      plantId: plantId,
    );

PlantSpecies _species(String id, String nameAr) => PlantSpecies(
      id: id,
      nameAr: nameAr,
      kc: 0.5,
      salinityResistance: 0.5,
      droughtResistance: 0.5,
    );

void main() {
  group('قائمة التنقيط', () {
    final bom = IrrigationBomService.buildDrip(
      areaM2: 4200,
      lateralTotalLengthM: 4200,
      totalEmitters: 8400,
      emitterLph: 4,
      lateralLengthM: 50,
      lateralDiameterMm: 16,
      mainLengthM: 200,
      mainDiameterMm: 90,
      sectors: 4,
      sectorFlowM3h: 20,
      motorKw: 7.5,
      motorHp: 10,
      totalHeadM: 32,
    );

    test('فيه بنود المواسير والنقاطات والمحابس والمضخة والملحقات', () {
      final codes = bom.items.map((item) => item.code).toList();
      expect(codes, containsAll(<String>[
        'main-pipe',
        'lateral-pipe',
        'emitters',
        'sector-valve',
        'flush-valve',
        'filter',
        'pump-set',
        'fittings',
      ]));
      expect(bom.system, IrrigationSystemKind.drip);
      expect(bom.systemLabel, 'تنقيط');
    });

    test('الكميات مبنية على نتائج الحاسبة مع هالك المواسير', () {
      final main = bom.items.firstWhere((item) => item.code == 'main-pipe');
      final lateral =
          bom.items.firstWhere((item) => item.code == 'lateral-pipe');
      final emitters = bom.items.firstWhere((item) => item.code == 'emitters');
      final sectorValve =
          bom.items.firstWhere((item) => item.code == 'sector-valve');

      expect(main.quantity, 210); // 200 م + 5% هالك
      expect(lateral.quantity, 4410); // 4200 م + 5%
      expect(emitters.quantity, 8568); // 8400 × 1.02
      expect(sectorValve.quantity, 4);
      expect(main.unit, 'م');
      expect(emitters.unit, 'عدد');
    });

    test('المضخة بتتحول لبنط بطقم واحد وبمواصفات القدرة', () {
      final pump = bom.items.firstWhere((item) => item.code == 'pump-set');
      expect(pump.quantity, 1);
      expect(pump.spec, contains('كيلوواط'));
      expect(pump.spec, contains('حصان'));
    });

    test('من غير مضخة مفيش بند طقم مضخة', () {
      final noPump = IrrigationBomService.buildDrip(
        areaM2: 4200,
        lateralTotalLengthM: 100,
        totalEmitters: 100,
        emitterLph: 4,
        lateralLengthM: 50,
        lateralDiameterMm: 16,
        mainLengthM: 50,
        mainDiameterMm: 50,
        sectors: 1,
        sectorFlowM3h: 5,
      );
      expect(noPump.items.any((item) => item.code == 'pump-set'), isFalse);
    });

    test('الكميات غير الصالحة بتتجاهل', () {
      final bom = IrrigationBomService.buildDrip(
        areaM2: 4200,
        lateralTotalLengthM: 0,
        totalEmitters: 0,
        emitterLph: 4,
        lateralLengthM: 0,
        lateralDiameterMm: 16,
        mainLengthM: 0,
        mainDiameterMm: 50,
        sectors: 1,
        sectorFlowM3h: 0,
      );
      expect(bom.items.any((item) => item.code == 'lateral-pipe'), isFalse);
      expect(bom.items.any((item) => item.code == 'emitters'), isFalse);
      expect(bom.items.any((item) => item.code == 'main-pipe'), isFalse);
      // المحابس والفلتر بيفضلوا موجودين لأنهم مش مرتبطين بطول خط.
      expect(bom.items.any((item) => item.code == 'main-valve'), isTrue);
      expect(bom.items.any((item) => item.code == 'pump-set'), isFalse);
    });
  });

  group('قائمة الرش', () {
    test('عدد الرشاشات والحوامل وخطوط الرش', () {
      final bom = IrrigationBomService.buildSprinkler(
        areaM2: 4200,
        fieldWidthM: 60,
        fieldLengthM: 70,
        spacingAcrossM: 12,
        spacingAlongM: 12,
        sprinklerFlowM3h: 1.2,
        sprinklers: 35,
        sectors: 3,
        sectorFlowM3h: 14,
        mainLengthM: 100,
        mainDiameterMm: 75,
        lateralDiameterMm: 50,
      );
      final sprinklers =
          bom.items.firstWhere((item) => item.code == 'sprinklers');
      final risers = bom.items.firstWhere((item) => item.code == 'risers');
      final lateral =
          bom.items.firstWhere((item) => item.code == 'lateral-pipe');

      expect(sprinklers.quantity, 35);
      expect(risers.quantity, 35);
      // 6 خطوط (60/12 + 1) × 70 م × 1.05
      expect(lateral.quantity, closeTo(6 * 70 * 1.05, 0.01));
      expect(bom.system, IrrigationSystemKind.sprinkler);
    });

    test('الفلتر بيكبر لو تصرف القطاع كبير', () {
      final bom = IrrigationBomService.buildSprinkler(
        areaM2: 4200,
        fieldWidthM: 60,
        fieldLengthM: 70,
        spacingAcrossM: 12,
        spacingAlongM: 12,
        sprinklerFlowM3h: 1.2,
        sprinklers: 35,
        sectors: 1,
        sectorFlowM3h: 90,
        mainLengthM: 100,
        mainDiameterMm: 110,
        lateralDiameterMm: 50,
      );
      final filter = bom.items.firstWhere((item) => item.code == 'filter');
      expect(filter.quantity, 3); // 90 / 40
    });
  });

  group('قائمة الري السطحي', () {
    final bom = IrrigationBomService.buildSurface(
      areaM2: 4200,
      fieldWidthM: 56,
      furrowSpacingM: 0.75,
      streamLps: 20,
    );

    test('بوابات بعدد الأتلام مع ملاحظة عدم وجود مواسير', () {
      final gates =
          bom.items.firstWhere((item) => item.code == 'surface-gates');
      expect(gates.quantity, (56 / 0.75).ceil());
      expect(bom.system, IrrigationSystemKind.surface);
      expect(bom.notes.join(' '), contains('بوابات'));
      expect(bom.items.any((item) => item.code == 'pump-set'), isFalse);
    });
  });

  group('قائمة البيفوت', () {
    test('الذراع بالطول والمساحة من نصف القطر', () {
      final bom = IrrigationBomService.buildPivot(
        radiusM: 400,
        flowM3h: 180,
        mainLengthM: 80,
        mainDiameterMm: 160,
        motorKw: 75,
        motorHp: 100,
        totalHeadM: 55,
      );
      final machine =
          bom.items.firstWhere((item) => item.code == 'pivot-machine');
      expect(machine.quantity, 400);
      expect(machine.spec, contains('برج'));
      expect(bom.areaFeddan, closeTo(3.1415926 * 400 * 400 / 4200, 0.01));
      expect(bom.items.any((item) => item.code == 'end-gun'), isTrue);
      expect(bom.items.any((item) => item.code == 'pump-set'), isTrue);
    });
  });

  group('قائمة تصميم المستخدم المحفوظ', () {
    final project = _project(
      pipes: [
        Pipe(id: 'p1', material: 'PE', diameter: 90, lengthM: 10),
        Pipe(id: 'p2', material: 'PE', diameter: 90, lengthM: 20),
        Pipe(id: 'p3', material: 'PVC', diameter: 160, lengthM: 5),
      ],
      valves: [
        Valve(id: 'v1', type: 'gate', diameterMm: 90),
        Valve(id: 'v2', type: 'gate', diameterMm: 90),
        Valve(id: 'v3', type: 'solenoid', diameterMm: 32),
      ],
      equipment: [
        IrrigationEquipment(
            id: 'e1',
            type: 'rotor',
            flowRateLpm: 20,
            operatingPressureBar: 3,
            quantity: 4),
        IrrigationEquipment(
            id: 'e2',
            type: 'rotor',
            flowRateLpm: 20,
            operatingPressureBar: 3,
            quantity: 3),
      ],
      plants: [_species('olive', 'زيتون'), _species('palm', 'نخيل')],
      placements: [
        _placement('m1', 'olive'),
        _placement('m2', 'olive'),
        _placement('m3', 'olive'),
        _placement('m4', 'palm'),
      ],
    );
    final bom =
        IrrigationBomService.buildFromProject(project, name: 'مزرعة النخيل');

    test('القائمة فيها كل خامات التصميم مجمّعة', () {
      final codes = bom.items.map((item) => item.code).toList();
      expect(codes, contains('pump-set'));
      expect(codes.where((code) => code.startsWith('pipe-')).length, 2);
      expect(codes.where((code) => code.startsWith('valve-')).length, 2);
      expect(codes.where((code) => code.startsWith('equipment-')).length, 1);
      expect(codes.where((code) => code.startsWith('plant-')).length, 2);
      expect(bom.name, 'مزرعة النخيل');
      expect(bom.systemLabel, 'تصميم متكامل');
    });

    test('أطوال المواسير والمعدات والشتلات متجمعة صح', () {
      final pe = bom.items.firstWhere((item) => item.code.contains('PE|90'));
      expect(pe.quantity, 32); // (10 + 20) × 1.05 = 31.5 → 32
      final rotor =
          bom.items.firstWhere((item) => item.code.startsWith('equipment-'));
      expect(rotor.quantity, 7);
      final olive = bom.items.firstWhere((item) => item.code == 'plant-olive');
      expect(olive.quantity, 3);
      expect(olive.name, 'زيتون');
    });

    test('المسارات بتحسب الطول لو مفيش مواسير مسجلة', () {
      final routed = IrrigationBomService.buildFromProject(_project(
        routes: [
          IrrigationPipeRoute(
            id: 'r1',
            points: const [
              GeoCoordinate(latitude: 30.000, longitude: 31.000),
              GeoCoordinate(latitude: 30.001, longitude: 31.000),
            ],
            diameterMm: 110,
            material: 'PE',
          ),
        ],
      ));
      final line =
          routed.items.firstWhere((item) => item.code.startsWith('route-'));
      expect(line.quantity, greaterThan(100)); // 0.001 درجة عرض ≈ 111 م
      expect(line.spec, contains('مسارات'));
    });

    test('نباتات مذكورة من غير أماكن بتتضاف بكمية 1', () {
      final noPlacements = IrrigationBomService.buildFromProject(
        _project(plants: [_species('ficus', 'فيكس')]),
      );
      final ficus =
          noPlacements.items.firstWhere((item) => item.code == 'plant-ficus');
      expect(ficus.quantity, 1);
      expect(ficus.spec, contains('بدون عدد'));
    });
  });

  test('قائمة اللاندسكيب بتاخد كميات التصميم الهيدروليكي', () {
    final plan = LandscapePlan(
      id: 'l1',
      nameAr: 'حديقة الفيلا',
      plotWidthM: 30,
      plotHeightM: 20,
      shapes: [
        LandscapeShape(
          id: 's1',
          nameAr: 'نجيل',
          plantTypeId: 'lawn',
          points: const [
            PlanPoint(0, 0),
            PlanPoint(20, 0),
            PlanPoint(20, 20),
            PlanPoint(0, 20),
          ],
        ),
      ],
    );
    final design = const LandscapeHydraulicDesignService().design(plan);
    final bom =
        IrrigationBomService.buildFromLandscape(plan: plan, design: design);

    expect(bom.system, IrrigationSystemKind.landscape);
    expect(bom.name, 'حديقة الفيلا');
    expect(bom.items, isNotEmpty);
    expect(bom.areaFeddan, closeTo(design.totalAreaM2 / 4200, 0.001));
    expect(bom.notes.join(' '), contains('لاندسكيب'));
  });

  group('بدون أسعار', () {
    final bom = IrrigationBom(
      system: IrrigationSystemKind.pivot,
      name: 'بيفوت',
      areaFeddan: 3,
      items: const [
        IrrigationBomItem(
            code: 'a', category: 'مواسير', name: 'ماسورة', unit: 'م', quantity: 10),
        IrrigationBomItem(
            code: 'b', category: 'محابس', name: 'محبس', unit: 'عدد', quantity: 2),
      ],
    );

    test('البنود بتتجمع حسب الفئة', () {
      expect(bom.grouped.keys, ['مواسير', 'محابس']);
      expect(bom.lines, 2);
      expect(bom.grouped['محابس']!.length, 1);
    });

    test('CSV فيه الكمية والوحدة ومن غير أي سعر أو إجمالي', () {
      final csv = IrrigationBomService.toCsv(bom);
      expect(csv, contains('"الفئة","الصنف","المواصفات","الوحدة","الكمية"'));
      expect(csv, contains('"10.00"'));
      expect(csv, isNot(contains('سعر')));
      expect(csv, isNot(contains('الإجمالي')));
      expect(csv.split('\n').length, 3);
    });

    test('الملخص النصي بيذكر الكميات بدون فلوس', () {
      final text = IrrigationBomService.summaryText(bom);
      expect(text, contains('بيفوت'));
      expect(text, contains('10 م'));
      expect(text, contains('بدون أسعار'));
      expect(text, isNot(contains('ج.م')));
    });
  });

  testWidgets('شاشة القائمة بتعرض البنود والكميات وبدون أسعار',
      (tester) async {
    final bom = IrrigationBom(
      system: IrrigationSystemKind.drip,
      areaFeddan: 1,
      items: const [
        IrrigationBomItem(
            code: 'main-pipe',
            category: 'مواسير',
            name: 'ماسورة رئيسية',
            unit: 'م',
            quantity: 210),
        IrrigationBomItem(
            code: 'emitters',
            category: 'نقاطات',
            name: 'نقاطات',
            unit: 'عدد',
            quantity: 8568),
      ],
      notes: const ['الكميات تقديرية'],
    );

    await tester.pumpWidget(MaterialApp(home: IrrigationBomScreen(bom: bom)));

    expect(find.text('قائمة مشتريات — تنقيط'), findsOneWidget);
    expect(find.text('210 م'), findsOneWidget);
    expect(find.text('8568 عدد'), findsOneWidget);
    expect(find.textContaining('ج.م'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    expect(find.text('• الكميات تقديرية'), findsOneWidget);
  });
}
