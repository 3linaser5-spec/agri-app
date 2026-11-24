import 'package:agri_app/utils/dxf_3d_export.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('3D DXF export', () {
    test('drip includes 3D pipe faces, emitter points, and elevation notes', () {
      final dxf = IrrigationDxf3d.drip(
        widthM: 6,
        lengthM: 10,
        rowSpacingM: 1,
        plantSpacingM: 0.5,
        emittersPerPlant: 1,
        emitterLph: 4,
        sectors: 2,
        mainLengthM: 10,
        mainPipeMm: 50,
        lateralPipeMm: 16,
        fieldZ: 1.5,
        pumpZ: 0.5,
        sectorFlowM3h: 0.5,
        pumpKw: 2,
      );

      expect(dxf, contains('0\n3DFACE\n'));
      expect(dxf, contains('0\nPOINT\n'));
      expect(dxf, contains('Ground Z=1.5 m'));
      expect(dxf, contains('PUMP 2 kW'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
    });

    test('sprinkler includes 3D laterals, risers, and sprinkler points', () {
      final dxf = IrrigationDxf3d.sprinkler(
        widthM: 12,
        lengthM: 18,
        spacingAlongM: 6,
        spacingAcrossM: 6,
        sprinklerFlowM3h: 1.2,
        sectors: 2,
        mainLengthM: 20,
        mainPipeMm: 75,
        lateralPipeMm: 50,
      );

      expect(dxf, contains('RISER'));
      expect(dxf, contains('SPRINKLER'));
      expect(dxf, contains('0\n3DFACE\n'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
    });

    test('surface irrigation contains 3D head channel and furrows', () {
      final dxf = IrrigationDxf3d.surface(
        widthM: 20,
        lengthM: 30,
        furrowSpacingM: 1,
        streamLps: 20,
        mainLengthM: 15,
      );

      expect(dxf, contains('HEAD_CHANNEL'));
      expect(dxf, contains('FURROW'));
      expect(dxf, contains('0\n3DFACE\n'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
    });

    test('pivot includes a 3D span, towers, and nozzle markers', () {
      final dxf = IrrigationDxf3d.pivot(
        radiusM: 100,
        mainLengthM: 20,
        mainPipeMm: 90,
        flowM3h: 30,
        hoursPerRotation: 40,
      );

      expect(dxf, contains('SPAN'));
      expect(dxf, contains('TOWER'));
      expect(dxf, contains('NOZZLE'));
      expect(dxf, contains('Nozzle spacing assumed 20 m'));
      expect(dxf.trimRight().endsWith('EOF'), isTrue);
    });
  });
}
