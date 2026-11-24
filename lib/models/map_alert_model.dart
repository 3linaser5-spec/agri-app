import 'package:cloud_firestore/cloud_firestore.dart';

class MapAlert {
  final String id;
  final String fieldId;
  final String? zoneId;
  final String title;
  final String message;
  final double latitude;
  final double longitude;
  final String severity;
  final String status;
  final DateTime? createdAt;
  final bool resolved;
  final String? inspectionResult;

  const MapAlert({required this.id, required this.fieldId, this.zoneId, required this.title, required this.message, required this.latitude, required this.longitude, required this.severity, this.status = 'open', required this.createdAt, required this.resolved, this.inspectionResult});

  factory MapAlert.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final coordinates = d['coordinates'] is Map ? d['coordinates'] as Map : const {};
    return MapAlert(
      id: doc.id,
      fieldId: d['field_id']?.toString() ?? '',
      zoneId: d['zone_id']?.toString(),
      title: d['title']?.toString() ?? 'تنبيه فحص',
      message: d['message']?.toString() ?? '',
      latitude: _number(d['latitude'] ?? coordinates['lat']),
      longitude: _number(d['longitude'] ?? coordinates['lon']),
      severity: d['severity']?.toString() ?? 'medium',
      status: d['status']?.toString() ?? (d['resolved'] == true ? 'resolved' : 'open'),
      createdAt: d['created_at'] is Timestamp ? (d['created_at'] as Timestamp).toDate() : DateTime.tryParse(d['created_at']?.toString() ?? ''),
      resolved: d['resolved'] == true,
      inspectionResult: d['inspection_result']?.toString() ?? d['inspection_note']?.toString(),
    );
  }
  MapAlert copyWith({String? inspectionResult}) => MapAlert(
        id: id,
        fieldId: fieldId,
        zoneId: zoneId,
        title: title,
        message: message,
        latitude: latitude,
        longitude: longitude,
        severity: severity,
        status: status,
        createdAt: createdAt,
        resolved: resolved,
        inspectionResult: inspectionResult ?? this.inspectionResult,
      );
  static double _number(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
}
