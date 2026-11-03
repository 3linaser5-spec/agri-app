import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/services/egypt_locations_service.dart';

void main() {
  group('EgyptLocationCatalog', () {
    test('loads Egyptian administrative data and Aswan villages', () async {
      final catalog = await EgyptLocationCatalog.load();
      final aswan = catalog.findGovernorate('أسوان');

      expect(catalog.governorates, hasLength(27));
      expect(
        catalog.governorates.fold<int>(
          0,
          (total, governorate) => total + governorate.areas.length,
        ),
        365,
      );
      expect(
        catalog.governorates.fold<int>(
          0,
          (total, governorate) => total +
              governorate.areas.fold<int>(
                0,
                (areaTotal, area) => areaTotal + area.villages.length,
              ),
        ),
        5716,
      );
      expect(aswan, isNotNull);
      expect(aswan!.areas, hasLength(10));
      expect(
        aswan.areas.fold<int>(0, (total, area) => total + area.villages.length),
        122,
      );
      expect(aswan.areas.any((area) => area.name == 'مركز أدفو'), isTrue);
    });

    test('matches normalized governorate spellings and Luxor source alias', () {
      final catalog = EgyptLocationCatalog(
        governorates: const [
          EgyptAdministrativeGovernorate(
            code: 'EG02',
            name: 'الاسكندرية',
            areas: [],
          ),
          EgyptAdministrativeGovernorate(
            code: 'EG29',
            name: 'مدينة الأقصر',
            areas: [],
          ),
        ],
        source: '',
        license: '',
        coverageNote: '',
      );

      expect(catalog.findGovernorate('الإسكندرية')?.code, 'EG02');
      expect(catalog.findGovernorate('الأقصر')?.code, 'EG29');
    });

    test('round-trips a village weather selection with its precise coordinates', () {
      const governorate = EgyptAdministrativeGovernorate(
        code: 'EG28',
        name: 'أسوان',
        areas: [],
      );
      const area = EgyptAdministrativeArea(
        code: 'EG2803',
        name: 'مركز أدفو',
        latitude: 25.0609,
        longitude: 32.9567,
        villages: [],
      );
      const village = EgyptAdministrativeVillage(
        code: 'EG280305',
        name: 'إدفو قبلي',
        latitude: 24.98,
        longitude: 32.87,
      );

      final original = WeatherLocationSelection.forVillage(
        governorate,
        area,
        village,
      );
      final restored = WeatherLocationSelection.fromJson(original.toJson());

      expect(restored.displayName, 'إدفو قبلي، مركز أدفو، أسوان');
      expect(restored.latitude, 24.98);
      expect(restored.longitude, 32.87);
      expect(restored.villageCode, 'EG280305');
    });
  });
}
