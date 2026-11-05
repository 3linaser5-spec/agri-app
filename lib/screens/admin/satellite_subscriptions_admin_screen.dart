import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../services/satellite_access_service.dart';

class SatelliteSubscriptionsAdminScreen extends StatefulWidget {
  const SatelliteSubscriptionsAdminScreen({super.key});

  @override
  State<SatelliteSubscriptionsAdminScreen> createState() =>
      _SatelliteSubscriptionsAdminScreenState();
}

class _SatelliteSubscriptionsAdminScreenState
    extends State<SatelliteSubscriptionsAdminScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !AppConfig.adminEmails.contains(user.email ?? '')) {
      return const Scaffold(
        body: Center(child: Text('ليس لديك صلاحية إدارة اشتراكات الأقمار.')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('اشتراكات الأقمار الصناعية'),
          backgroundColor: const Color(0xFF047857),
          foregroundColor: Colors.white,
          actions: [
            IconButton(
              tooltip: 'تفعيل UID يدويًا',
              onPressed: _busy ? null : _activateManual,
              icon: const Icon(Icons.person_add_alt_1),
            ),
          ],
        ),
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _service.watchPendingRequests(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'تعذر تحميل طلبات التفعيل. تحقق من صلاحيات Firestore واتصال الشبكة.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final requests = snapshot.data!.docs;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Card(
                  color: Color(0xFFEAF6F0),
                  child: Padding(
                    padding: EdgeInsets.all(14),
                    child: Text(
                      'التفعيل يدوي ولا يوجد دفع داخل التطبيق. اتفق مع العميل خارج التطبيق، ثم أدخل السعر والمدة وحد الحقول ومساحة كل حقل وعدد تحليلات NDVI الشهرية.',
                      style: TextStyle(height: 1.5),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'طلبات قيد المراجعة',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Text('${requests.length}'),
                  ],
                ),
                const SizedBox(height: 8),
                if (requests.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(18),
                      child: Text('لا توجد طلبات جديدة حالياً.'),
                    ),
                  )
                else
                  ...requests.map(_requestCard),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: _busy ? null : _activateManual,
                  icon: const Icon(Icons.key),
                  label: const Text('تفعيل أو تجديد لمعرّف UID'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _requestCard(QueryDocumentSnapshot<Map<String, dynamic>> request) {
    final createdAt = request.data()['createdAt'];
    final dateLabel = createdAt is Timestamp
        ? _date(createdAt.toDate())
        : 'وقت غير متاح';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'معرّف المستخدم (UID)',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            SelectableText(request.id),
            const SizedBox(height: 4),
            Text(
              'تاريخ الطلب: $dateLabel',
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: _busy ? null : () => _activate(request.id),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('تفعيل'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _reject(request.id),
                  icon: const Icon(Icons.close),
                  label: const Text('رفض الطلب'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _activateManual() async {
    final uid = await showDialog<String>(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: const Text('تفعيل مستخدم يدوياً'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'Firebase Auth UID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('متابعة'),
            ),
          ],
        );
      },
    );
    if (uid == null || uid.isEmpty) return;
    await _activate(uid);
  }

  Future<void> _activate(String uid) async {
    final settings = await _showActivationDialog(uid);
    if (settings == null) return;
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    setState(() => _busy = true);
    try {
      await _service.activateUser(
        uid: uid,
        adminUid: adminUid,
        priceEgp: settings.priceEgp,
        durationDays: settings.durationDays,
        maxFields: settings.maxFields,
        maxAnalysesPerMonth: settings.maxAnalysesPerMonth,
        maxAreaFeddan: settings.maxAreaFeddan,
      );
      _message('تم تفعيل/تجديد اشتراك المستخدم.');
    } catch (error) {
      _message('تعذر التفعيل: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<_ActivationSettings?> _showActivationDialog(String uid) async {
    final price = TextEditingController(text: '0');
    final days = TextEditingController(text: '30');
    final fields = TextEditingController(text: '3');
    final analyses = TextEditingController(text: '6');
    final area = TextEditingController(text: '100');
    final result = await showDialog<_ActivationSettings>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تفاصيل الاشتراك'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SelectableText('UID: $uid', textDirection: TextDirection.ltr),
              const SizedBox(height: 12),
              TextField(
                controller: price,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'السعر المتفق عليه (جنيه مصري)',
                ),
              ),
              TextField(
                controller: days,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'مدة التفعيل بالأيام',
                ),
              ),
              TextField(
                controller: fields,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'الحد الأقصى للحقول',
                ),
              ),
              TextField(
                controller: analyses,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'تحليلات NDVI المتاحة شهرياً',
                ),
              ),
              TextField(
                controller: area,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'أقصى مساحة للحقل (فدان)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              final parsedPrice = double.tryParse(price.text.trim());
              final parsedDays = int.tryParse(days.text.trim());
              final parsedFields = int.tryParse(fields.text.trim());
              final parsedAnalyses = int.tryParse(analyses.text.trim());
              final parsedArea = double.tryParse(area.text.trim());
              if (parsedPrice == null ||
                  parsedPrice < 0 ||
                  parsedDays == null ||
                  parsedDays < 1 ||
                  parsedFields == null ||
                  parsedFields < 1 ||
                  parsedAnalyses == null ||
                  parsedAnalyses < 1 ||
                  parsedArea == null ||
                  parsedArea <= 0)
                return;
              Navigator.pop(
                context,
                _ActivationSettings(
                  parsedPrice,
                  parsedDays,
                  parsedFields,
                  parsedAnalyses,
                  parsedArea,
                ),
              );
            },
            child: const Text('تأكيد التفعيل'),
          ),
        ],
      ),
    );
    price.dispose();
    days.dispose();
    fields.dispose();
    analyses.dispose();
    area.dispose();
    return result;
  }

  Future<void> _reject(String uid) async {
    final adminUid = FirebaseAuth.instance.currentUser?.uid;
    if (adminUid == null) return;
    try {
      await _service.rejectRequest(uid: uid, adminUid: adminUid);
      _message('تم رفض الطلب.');
    } catch (error) {
      _message('تعذر رفض الطلب: $error');
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _ActivationSettings {
  const _ActivationSettings(
    this.priceEgp,
    this.durationDays,
    this.maxFields,
    this.maxAnalysesPerMonth,
    this.maxAreaFeddan,
  );

  final double priceEgp;
  final int durationDays;
  final int maxFields;
  final int maxAnalysesPerMonth;
  final double maxAreaFeddan;
}
