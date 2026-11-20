import 'package:cloud_firestore/cloud_firestore.dart';

class ActiveSubscriber {
  final String uid;
  final String name;
  final String phone;
  final String plan;
  final double areaLimitFeddans;
  final double usedAreaFeddans;
  final DateTime? expiresAt;
  final String status;

  const ActiveSubscriber({
    required this.uid,
    required this.name,
    required this.phone,
    required this.plan,
    required this.areaLimitFeddans,
    required this.usedAreaFeddans,
    required this.expiresAt,
    required this.status,
  });

  double get remainingAreaFeddans => (areaLimitFeddans - usedAreaFeddans).clamp(0, double.infinity);
  double get usageRatio => areaLimitFeddans <= 0 ? 0 : (usedAreaFeddans / areaLimitFeddans).clamp(0, 1);

  factory ActiveSubscriber.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ActiveSubscriber.fromData(doc.id, doc.data() ?? const <String, dynamic>{});
  }

  factory ActiveSubscriber.fromData(String uid, Map<String, dynamic> data) {
    return ActiveSubscriber(
      uid: uid,
      name: data['name']?.toString().trim().isNotEmpty == true ? data['name'].toString().trim() : 'مشترك',
      phone: data['phone']?.toString() ?? '',
      plan: data['plan']?.toString() ?? 'مراقبة المحاصيل',
      areaLimitFeddans: _number(
        data['max_area_feddan'] ??
            data['max_area_feddans'] ??
            data['area_limit_feddans'] ??
            data['area_limit'],
      ),
      usedAreaFeddans: _number(
        data['used_area_feddan'] ??
            data['used_area_feddans'] ??
            data['used_area'],
      ),
      expiresAt: _date(data['expires_at'] ?? data['expiry_date']),
      status: data['status']?.toString() ?? 'active',
    );
  }

  static double _number(dynamic value) => value is num ? value.toDouble() : double.tryParse(value?.toString() ?? '') ?? 0;
  static DateTime? _date(dynamic value) => value is Timestamp ? value.toDate() : value is DateTime ? value : DateTime.tryParse(value?.toString() ?? '');
}
