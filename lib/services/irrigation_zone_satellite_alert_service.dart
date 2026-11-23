import '../models/irrigation_catalog_models.dart';
import '../models/irrigation_design_models.dart';
import '../models/map_alert_model.dart';

class IrrigationZoneSatelliteAlert {
  final String id;
  final String zoneId;
  final GeoCoordinate coordinate;
  final String severity;
  final String title;
  final String message;
  final String fieldInspectionRequest;
  final bool resolved;

  const IrrigationZoneSatelliteAlert({
    required this.id,
    required this.zoneId,
    required this.coordinate,
    required this.severity,
    required this.title,
    required this.message,
    required this.fieldInspectionRequest,
    this.resolved = false,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'zone_id': zoneId,
        'latitude': coordinate.latitude,
        'longitude': coordinate.longitude,
        'severity': severity,
        'title': title,
        'message': message,
        'field_inspection_request': fieldInspectionRequest,
        'resolved': resolved,
      };
}

/// يحول مؤشرات التحليل إلى تنبيهات مفهومة للمستخدم بدون عرض مصادر البيانات.
class IrrigationZoneSatelliteAlertService {
  const IrrigationZoneSatelliteAlertService();

  List<IrrigationZoneSatelliteAlert> fromMapAlerts(
    Iterable<MapAlert> alerts, {
    required IrrigationSatelliteLink link,
  }) {
    return List.unmodifiable(alerts
        .where((alert) => link.alertIds.contains(alert.id))
        .where((alert) => alert.zoneId == null || alert.zoneId == link.zoneId)
        .map((alert) => IrrigationZoneSatelliteAlert(
              id: alert.id,
              zoneId: link.zoneId,
              coordinate: GeoCoordinate.checked(
                latitude: alert.latitude,
                longitude: alert.longitude,
              ),
              severity: alert.severity,
              title: alert.title,
              message: alert.message,
              fieldInspectionRequest:
                  'يرجى إجراء فحص ميداني عند الإحداثيات المعروضة وتسجيل النتيجة قبل اتخاذ إجراء.',
              resolved: alert.resolved,
            )));
  }

  List<IrrigationZoneSatelliteAlert> analyze(
    IrrigationDesignProject project, {
    Map<String, Map<String, double>> zoneMetrics = const {},
  }) {
    return List.unmodifiable(project.zones.expand((zone) {
      final metrics = zoneMetrics[zone.id] ?? const <String, double>{};
      final coordinate = _zoneCoordinate(project, zone.id);
      final alerts = <IrrigationZoneSatelliteAlert>[];
      final dryness = metrics['dryness'] ?? metrics['drought_risk'];
      final salinity = metrics['salinity'] ?? metrics['salinity_risk'];
      final vegetation = metrics['vegetation_health'] ?? metrics['ndvi'];
      if (dryness != null && dryness >= .7) {
        alerts.add(_alert(
          zone.id,
          coordinate,
          'dryness',
          'احتمال إجهاد مائي',
          'توجد مؤشرات على إجهاد مائي محتمل داخل المنطقة.',
        ));
      }
      if (salinity != null && salinity >= .7) {
        alerts.add(_alert(
          zone.id,
          coordinate,
          'salinity',
          'احتمال مشكلة ملوحة',
          'توجد مؤشرات على مشكلة ملوحة محتملة داخل المنطقة.',
        ));
      }
      if (vegetation != null && vegetation <= .35) {
        alerts.add(_alert(
          zone.id,
          coordinate,
          'vegetation',
          'ضعف محتمل في نمو النباتات',
          'توجد منطقة ضعف محتملة تحتاج إلى مراجعة شبكة الري والنباتات.',
        ));
      }
      return alerts;
    }));
  }

  IrrigationZoneSatelliteAlert _alert(
    String zoneId,
    GeoCoordinate coordinate,
    String code,
    String title,
    String message,
  ) => IrrigationZoneSatelliteAlert(
        id: 'satellite-$zoneId-$code',
        zoneId: zoneId,
        coordinate: coordinate,
        severity: 'medium',
        title: title,
        message: message,
        fieldInspectionRequest:
            'يرجى إجراء فحص ميداني عند الإحداثيات المعروضة وتسجيل النتيجة قبل اتخاذ إجراء.',
      );

  GeoCoordinate _zoneCoordinate(
    IrrigationDesignProject project,
    String zoneId,
  ) {
    final points = project.placements
        .where((placement) => placement.zoneId == zoneId)
        .map((placement) => placement.coordinate)
        .toList(growable: false);
    final source = points.isEmpty ? project.siteBoundary.points : points;
    final lat = source.fold<double>(0, (sum, point) => sum + point.latitude) /
        source.length;
    final lon = source.fold<double>(0, (sum, point) => sum + point.longitude) /
        source.length;
    return GeoCoordinate(latitude: lat, longitude: lon);
  }
}
