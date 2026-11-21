import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/models/irrigation_catalog_models.dart';

void main() {
  test('round-trips a catalog item with specifications', () {
    final item = IrrigationCatalogItem(id:'rotor-1', kind:'equipment', nameAr:'رشاش', manufacturer:'Acme', specifications:const {'flow_lpm':12, 'pressure_bar':2.5});
    final restored = IrrigationCatalogItem.fromJson(item.toJson());
    expect(restored.nameAr, 'رشاش');
    expect(restored.specifications['flow_lpm'], 12);
  });

  test('round-trips a zone satellite link', () {
    final link = IrrigationSatelliteLink(projectId:'p', zoneId:'z', fieldId:'field', alertIds:const ['a1'], updatedAt:DateTime(2026, 1, 1));
    final restored = IrrigationSatelliteLink.fromJson(link.toJson());
    expect(restored.fieldId, 'field');
    expect(restored.alertIds, contains('a1'));
  });
}
