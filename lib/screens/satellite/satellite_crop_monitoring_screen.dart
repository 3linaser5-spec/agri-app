import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../services/satellite_access_service.dart';
import 'satellite_block_detail_screen.dart';
import 'satellite_block_editor_screen.dart';

const Color _sectionGreen = Color(0xFF047857);

/// قسم مستقل لمتابعة المحاصيل بالأقمار الصناعية، منفصل عن شاشة «مزرعتي».
class SatelliteCropMonitoringScreen extends StatefulWidget {
  const SatelliteCropMonitoringScreen({super.key});

  @override
  State<SatelliteCropMonitoringScreen> createState() =>
      _SatelliteCropMonitoringScreenState();
}

class _SatelliteCropMonitoringScreenState
    extends State<SatelliteCropMonitoringScreen> {
  final SatelliteAccessService _service = SatelliteAccessService();
  bool _requestBusy = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('سجل الدخول أولاً لاستخدام الخدمة.')),
      );
    }

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'متابعة المحاصيل بالأقمار الصناعية',
            style: TextStyle(color: Colors.white, fontSize: 17),
          ),
          backgroundColor: _sectionGreen,
          foregroundColor: Colors.white,
        ),
        body: StreamBuilder<SatelliteEntitlement?>(
          stream: _service.watchEntitlement(user.uid),
          builder: (context, accessSnapshot) {
            if (accessSnapshot.hasError) {
              return _messageView('تعذر قراءة حالة الاشتراك. تحقق من اتصالك.');
            }
            if (accessSnapshot.connectionState == ConnectionState.waiting &&
                !accessSnapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final entitlement = accessSnapshot.data;
            if (entitlement == null || !entitlement.isActive) {
              return _activationView(user.uid, entitlement);
            }
            return _blocksView(user.uid, entitlement);
          },
        ),
      ),
    );
  }

  Widget _activationView(String uid, SatelliteEntitlement? entitlement) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const SizedBox(height: 10),
        const Icon(Icons.satellite_alt, size: 76, color: _sectionGreen),
        const SizedBox(height: 12),
        const Text(
          'قسم تجاري يُفعّل يدوياً',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        const Text(
          'تحديد قطع الأرض على الخريطة الفضائية، ومتابعة تسعة مؤشرات نباتية من NASA، '
          'مع بيان الأجزاء الأضعف داخل كل قطعة.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, height: 1.7),
        ),
        const SizedBox(height: 16),
        _featureRow(
          Icons.crop_free,
          'قطع متعددة بأسماء ومساحات ومحصول وصنف وعمر',
        ),
        _featureRow(Icons.grid_on, 'تقسيم داخلي لكل قطعة لبيان مواضع الضعف'),
        _featureRow(
          Icons.insights,
          'تسعة مؤشرات: NDVI وEVI وSAVI وMSAVI وNDMI وNDWI وNBR وNBR2 وTVI',
        ),
        _featureRow(Icons.history, 'سجل زمني للقراءات لمتابعة تطوّر المحصول'),
        if (entitlement != null) ...[
          const SizedBox(height: 16),
          Card(
            color: const Color(0xFFFFF7ED),
            child: ListTile(
              leading: const Icon(Icons.lock_clock, color: Colors.deepOrange),
              title: Text(
                entitlement.status == 'active'
                    ? 'انتهت مدة الاشتراك'
                    : 'الخدمة غير مفعّلة لهذا الحساب',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: entitlement.expiresAt == null
                  ? null
                  : Text('انتهى التفعيل في ${_date(entitlement.expiresAt!)}'),
            ),
          ),
        ],
        const SizedBox(height: 20),
        StreamBuilder<Map<String, dynamic>?>(
          stream: _service.watchRequest(uid),
          builder: (context, snapshot) {
            final status = snapshot.data?['status'] as String?;
            if (status == 'pending') {
              return Card(
                color: const Color(0xFFEAF6F0),
                child: const ListTile(
                  leading: Icon(Icons.hourglass_top, color: _sectionGreen),
                  title: Text(
                    'طلبك قيد المراجعة',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text('سيتواصل معك المسؤول بعد مراجعة الطلب.'),
                ),
              );
            }
            return Column(
              children: [
                FilledButton.icon(
                  onPressed: _requestBusy ? null : () => _request(uid),
                  icon: _requestBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.mark_email_unread_outlined),
                  label: const Text('إرسال طلب تفعيل'),
                  style: FilledButton.styleFrom(
                    backgroundColor: _sectionGreen,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _contactAdmin,
                  icon: const Icon(Icons.chat_outlined),
                  label: const Text('التواصل عبر واتساب'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        const Text(
          'القراءات من NASA HLS-VI عبر AppEEARS، ويُعالجها الخادم بعد التحقق من اشتراكك. '
          'التفعيل والسعر والمدة والحدود يحددها الأدمن.',
          style: TextStyle(fontSize: 12, color: Colors.black54, height: 1.6),
        ),
      ],
    );
  }

  Widget _featureRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: _sectionGreen),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.5)),
        ),
      ],
    ),
  );

  Widget _blocksView(String uid, SatelliteEntitlement entitlement) {
    return StreamBuilder<List<SatelliteField>>(
      stream: _service.watchFields(uid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _messageView('تعذر تحميل القطع المحفوظة.');
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final fields = snapshot.data!;
        final totalArea = fields.fold<double>(
          0,
          (sum, field) => sum + field.areaFeddan,
        );
        final crops = fields.map((field) => field.cropType).toSet();

        return RefreshIndicator(
          onRefresh: () async =>
              Future<void>.delayed(const Duration(milliseconds: 400)),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _summaryCard(fields.length, totalArea, crops.length),
              const SizedBox(height: 14),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'قطع الأرض',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: fields.length >= entitlement.maxFields
                        ? null
                        : () => _openEditor(uid),
                    icon: const Icon(Icons.add_location_alt_outlined),
                    label: const Text('إضافة قطعة'),
                    style: FilledButton.styleFrom(
                      backgroundColor: _sectionGreen,
                    ),
                  ),
                ],
              ),
              if (fields.length >= entitlement.maxFields)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'وصلت للحد الأقصى (${entitlement.maxFields} قطع). تواصل مع الإدارة لزيادته.',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              if (fields.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Text(
                      'لم تضف قطعاً بعد. اضغط «إضافة قطعة»، ارسم الحدود على الخريطة الفضائية، '
                      'ثم أدخل اسم القطعة ونوع المحصول والصنف وتاريخ الزراعة.',
                      style: TextStyle(height: 1.6),
                    ),
                  ),
                )
              else
                ...fields.map((field) => _fieldCard(uid, entitlement, field)),
              const SizedBox(height: 12),
              Text(
                'الباقة الحالية: ${entitlement.maxFields} قطع • '
                '${entitlement.maxAreaFeddan} فدان لكل قطعة • '
                '${entitlement.maxAnalysesPerMonth} تحليلات شهرياً • '
                'تنتهي ${entitlement.expiresAt == null ? 'غير محدد' : _date(entitlement.expiresAt!)}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: Colors.black54,
                  height: 1.6,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _summaryCard(int blocks, double area, int cropCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF10B981)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'إجمالي المتابعة',
            style: TextStyle(color: Colors.white70, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _summaryItem('$blocks', 'قطعة')),
              Expanded(child: _summaryItem(area.toStringAsFixed(2), 'فدان')),
              Expanded(child: _summaryItem('$cropCount', 'محصول')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summaryItem(String value, String label) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        value,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
      Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
    ],
  );

  Widget _fieldCard(
    String uid,
    SatelliteEntitlement entitlement,
    SatelliteField field,
  ) {
    final age = field.cropAgeDays;
    final ndvi = field.lastIndices['NDVI'];
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SatelliteBlockDetailScreen(
              uid: uid,
              field: field,
              maxAnalysesPerMonth: entitlement.maxAnalysesPerMonth,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: _sectionGreen.withValues(alpha: 0.12),
                    child: const Icon(Icons.grass, color: _sectionGreen),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          field.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${field.cropType} • ${field.cultivar}${age == null ? '' : ' • $age يوم'}',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_left, color: Colors.grey),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _badge(
                    Icons.straighten,
                    '${field.areaFeddan.toStringAsFixed(2)} فدان',
                    Colors.blueGrey,
                  ),
                  _badge(
                    Icons.grid_on,
                    '${field.zones.isEmpty ? 1 : field.zones.length} منطقة',
                    Colors.indigo,
                  ),
                  if (ndvi != null)
                    _badge(
                      Icons.eco,
                      'NDVI ${ndvi.toStringAsFixed(2)}',
                      _sectionGreen,
                    ),
                  _badge(
                    Icons.sync,
                    _statusLabel(field.lastAnalysisStatus),
                    _statusColor(field.lastAnalysisStatus),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 10.5,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );

  String _statusLabel(String status) => switch (status) {
    'processing' => 'قيد المعالجة',
    'ready' => 'قراءات متاحة',
    'failed' => 'فشل التحليل',
    'no_valid_scenes' => 'لا مشاهد صافية',
    _ => 'بانتظار التحليل',
  };

  Color _statusColor(String status) => switch (status) {
    'ready' => _sectionGreen,
    'processing' => Colors.blue,
    'failed' => Colors.red,
    'no_valid_scenes' => Colors.orange,
    _ => Colors.grey,
  };

  Widget _messageView(String message) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Text(message, textAlign: TextAlign.center),
    ),
  );

  String _date(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  Future<void> _openEditor(String uid, [SatelliteField? field]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => SatelliteBlockEditorScreen(uid: uid, field: field),
      ),
    );
  }

  Future<void> _request(String uid) async {
    setState(() => _requestBusy = true);
    try {
      await _service.requestActivation(uid);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم إرسال طلب التفعيل إلى الإدارة.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('تعذر إرسال الطلب: $error')));
      }
    } finally {
      if (mounted) setState(() => _requestBusy = false);
    }
  }

  Future<void> _contactAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    final message =
        'أرغب في تفعيل خدمة متابعة المحاصيل بالأقمار الصناعية في نباتي. UID: $uid';
    final uri = Uri.parse(
      '${AppConfig.whatsappUrl}?text=${Uri.encodeComponent(message)}',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('تعذر فتح واتساب.')));
    }
  }
}
