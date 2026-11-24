import 'package:flutter_test/flutter_test.dart';
import 'package:agri_app/services/landscape_satellite_access_service.dart';

void main() {
  test('allows only active designs within the assigned area', () {
    const entitlement = LandscapeSatelliteEntitlement(
      active: true,
      maxFeddan: 2.5,
    );
    expect(entitlement.allows(2.5), isTrue);
    expect(entitlement.allows(2.51), isFalse);
  });

  test('revoked or zero-area entitlements do not allow designs', () {
    expect(
      const LandscapeSatelliteEntitlement(active: false, maxFeddan: 10)
          .allows(1),
      isFalse,
    );
    expect(
      const LandscapeSatelliteEntitlement(active: true, maxFeddan: 0)
          .allows(0),
      isFalse,
    );
  });
}
