import '../models/irrigation_design_models.dart';

class IrrigationMapIssue {
  final String code;
  final String message;
  final String subjectId;

  const IrrigationMapIssue({
    required this.code,
    required this.message,
    required this.subjectId,
  });
}

class IrrigationMapValidationService {
  const IrrigationMapValidationService();

  List<IrrigationMapIssue> validate(IrrigationDesignProject project) {
    final issues = <IrrigationMapIssue>[];
    final ids = <String>{};
    for (final placement in project.placements) {
      if (!ids.add(placement.id)) {
        issues.add(IrrigationMapIssue(
          code: 'duplicate_id',
          message: 'يوجد عنصران بنفس المعرّف على الخريطة.',
          subjectId: placement.id,
        ));
      }
      if (!_contains(project.siteBoundary.points, placement.coordinate)) {
        issues.add(IrrigationMapIssue(
          code: 'outside_boundary',
          message: 'العنصر موضوع خارج حدود الموقع.',
          subjectId: placement.id,
        ));
      }
      if (_requiresZone(placement.kind) && placement.zoneId == null) {
        issues.add(IrrigationMapIssue(
          code: 'missing_zone',
          message: 'عنصر الري يحتاج إلى ربطه بمنطقة تشغيل.',
          subjectId: placement.id,
        ));
      }
      if (placement.zoneId != null &&
          !project.zones.any((zone) => zone.id == placement.zoneId)) {
        issues.add(IrrigationMapIssue(
          code: 'unknown_zone',
          message: 'العنصر مربوط بمنطقة غير موجودة في المشروع.',
          subjectId: placement.id,
        ));
      }
    }
    return List.unmodifiable(issues);
  }

  bool _requiresZone(String kind) =>
      {'rotor', 'spray', 'drip', 'bubbler', 'micro_spray', 'valve'}
          .contains(kind);

  bool _contains(List<GeoCoordinate> polygon, GeoCoordinate point) {
    if (polygon.length < 3) return false;
    var inside = false;
    for (var i = 0, j = polygon.length - 1; i < polygon.length; j = i++) {
      final a = polygon[i];
      final b = polygon[j];
      final crosses = (a.latitude > point.latitude) !=
          (b.latitude > point.latitude);
      if (crosses &&
          point.longitude <
              (b.longitude - a.longitude) *
                      (point.latitude - a.latitude) /
                      (b.latitude - a.latitude) +
                  a.longitude) {
        inside = !inside;
      }
    }
    return inside;
  }
}
