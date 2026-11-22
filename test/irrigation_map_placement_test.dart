import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_design_models.dart';

void main() {
  test('serializes map placements with equipment and zone links', () {
    final placement = IrrigationMapPlacement(
      id: 'sprinkler-1',
      kind: 'rotor',
      coordinate: const GeoCoordinate(latitude: 30, longitude: 31),
      rotationDegrees: 90,
      equipmentId: 'rotor-catalog-1',
      zoneId: 'zone-1',
    );
    final restored = IrrigationMapPlacement.fromJson(placement.toJson());

    expect(restored.id, 'sprinkler-1');
    expect(restored.kind, 'rotor');
    expect(restored.rotationDegrees, 90);
    expect(restored.equipmentId, 'rotor-catalog-1');
    expect(restored.zoneId, 'zone-1');
  });
}
