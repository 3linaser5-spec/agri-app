import 'package:cloud_firestore/cloud_firestore.dart';

class MapAlert {
  final String id;
  final String fieldId;
  final String title;
  final String message;
  final double latitude;
  final double longitude;
  final String severity;
  final DateTime? createdAt;
  final bool resolved;

  const MapAlert({required this.id, required this.fieldId, required this.title, required this.message, required this.latitude, required this.longitude, required this.severity, required this.createdAt, required this.resolved});

  factory MapAlert.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const <String, dynamic>{};
    final coordinates = d['coordinates'] is Map ? d['coordinates'] as Map : const {};
    return MapAlert(
      id: doc.id,
      fieldId: d['field_id']?.toString() ?? '',
      title: d['title']?.toString() ?? 'تنبيه فحص',
      message: d['message']?.toString() ?? '',
      latitude: _number(d['latitude'] ?? coordinates['lat']),
      longitude: _number(d['longitude'] ?? coordinates['lon']),
      severity: d['severity']?.toString() ?? 'medium',
      createdAt: d['created_at'] is Timestamp ? (d['created_at'] as Timestamp).toDate() : DateTime.tryParse(d['created_at']?.toString() ?? ''),
      resolved: d['resolved'] == true,
    );
  }
  static double _number(dynamic v) => v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;
}
