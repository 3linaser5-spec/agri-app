import 'package:flutter/material.dart';

import '../../services/satellite_access_service.dart';
import 'satellite_monitoring_screen.dart';

class SatelliteMonitoringScreen extends StatelessWidget {
  const SatelliteMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: SatelliteAccessService.watchAccess(),
    builder: (context, access) {
      if (access.data == true) return const SatelliteFieldsScreen();

      return StreamBuilder<String?>(
        stream: SatelliteAccessService.watchRequestStatus(),
        builder: (context, request) => _SatelliteAccessPanel(
          status: request.data,
          hasAccessError: access.hasError,
          hasRequestError: request.hasError,
          checkingAccess:
              access.connectionState == ConnectionState.waiting &&
              !access.hasData,
        ),
      );
    },
  );
}

class _SatelliteAccessPanel extends StatefulWidget {
  final String? status;
  final bool hasAccessError;
  final bool hasRequestError;
  final bool checkingAccess;

  const _SatelliteAccessPanel({
    required this.status,
    required this.hasAccessError,
    required this.hasRequestError,
    required this.checkingAccess,
  });

  @override
  State<_SatelliteAccessPanel> createState() => _SatelliteAccessPanelState();
}

class _SatelliteAccessPanelState extends State<_SatelliteAccessPanel> {
  bool _sending = false;

  static const _indices = <({String code, String description})>[
    (code: 'NDVI', description: 'مؤشر اخضرار وحيوية الغطاء النباتي'),
    (code: 'EVI', description: 'متابعة كثافة الغطاء النباتي'),
    (code: 'SAVI', description: 'يقلل أثر التربة المكشوفة في القياس'),
    (code: 'MSAVI', description: 'مفيد عند قلة الغطاء النباتي وظهور التربة'),
    (code: 'NDMI', description: 'متابعة التغير في رطوبة النبات'),
    (code: 'NDWI', description: 'رصد التغيرات المرتبطة بالماء'),
    (code: 'NBR', description: 'مؤشر لتغيرات الغطاء النباتي'),
    (code: 'NBR2', description: 'تحليل إضافي باستخدام نطاقات SWIR'),
    (code: 'TVI', description: 'مؤشر مساعد لتقدير كثافة النبات'),
  ];

  Future<void> _sendRequest() async {
    setState(() => _sending = true);
    try {
      await SatelliteAccessService.requestAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'تم إرسال طلبك، وستجده في لوحة الأدمن ضمن طلبات تفعيل مراقبة الأقمار.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_friendlyRequestError(error))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String _friendlyRequestError(Object error) {
    final value = error.toString();
    if (value.contains('permission-denied')) {
      return 'تعذر حفظ الطلب في قاعدة البيانات. يلزم مراجعة صلاحيات Firestore وإعداد حساب الأدمن.';
    }
    if (value.contains('unavailable') || value.contains('network')) {
      return 'لم يصل الطلب بسبب تعذر الاتصال بالخدمة. حاول الإرسال مرة أخرى عند توفر الإنترنت.';
    }
    return value.replaceFirst('Bad state: ', '');
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.status == 'pending';
    final approvedWithoutGrant = widget.status == 'approved';
    final rejected = widget.status == 'rejected';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراقبة المحاصيل بالأقمار'),
          backgroundColor: const Color(0xFF047857),
          foregroundColor: Colors.white,
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _introCard(),
                  const SizedBox(height: 16),
                  const Text(
                    'تسعة مؤشرات لمتابعة صحة المحصول',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _indices.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: 1.9,
                        ),
                    itemBuilder: (context, index) {
                      final item = _indices[index];
                      return _IndexCard(
                        code: item.code,
                        description: item.description,
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  _additionalFeatures(),
                  const SizedBox(height: 12),
                  const Text(
                    'المؤشرات أدوات متابعة وليست تشخيصًا نهائيًا للمحصول. تتأثر النتائج بتوفر المشاهد ووضوحها، ويعرض التطبيق أعلام جودة الصور للمساعدة في تفسيرها.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  const SizedBox(height: 18),
                  _requestStatus(
                    pending: pending,
                    approvedWithoutGrant: approvedWithoutGrant,
                    rejected: rejected,
                  ),
                  if (!pending && !approvedWithoutGrant) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _sending ? null : _sendRequest,
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_outlined),
                        label: Text(
                          _sending
                              ? 'جارٍ إرسال الطلب...'
                              : rejected
                              ? 'إعادة طلب تفعيل الخدمة'
                              : 'طلب تفعيل الخدمة',
                        ),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  const Text(
                    'يصل الطلب إلى قائمة «طلبات تفعيل مراقبة الأقمار» في لوحة الأدمن.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _introCard() => Card(
    elevation: 0,
    color: const Color(0xFFEAF6F0),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          const Icon(Icons.satellite_alt, size: 48, color: Color(0xFF047857)),
          const SizedBox(height: 8),
          const Text(
            'راقب نمو محاصيلك من الفضاء',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'يجمع التحليل مشاهد متعددة المستشعرات في سجل زمني موحّد لمتابعة نمو النبات ورطوبته والتغيرات في الحقل. دقة التحليل الحالية 30 مترًا، وتعتمد إتاحة كل مشاهدة على صفاء السماء وتوفر البيانات.',
            textAlign: TextAlign.center,
            style: TextStyle(height: 1.5),
          ),
          const SizedBox(height: 14),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: const [
              _FeaturePill(icon: Icons.show_chart, label: 'سجل زمني موحّد'),
              _FeaturePill(
                icon: Icons.map_outlined,
                label: 'متابعة داخل الحقل',
              ),
              _FeaturePill(
                icon: Icons.cloud_outlined,
                label: 'فحص جودة المشاهد',
              ),
              _FeaturePill(
                icon: Icons.notification_important_outlined,
                label: 'تنبيهات التغير',
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _additionalFeatures() => Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Colors.green.shade100),
      borderRadius: BorderRadius.circular(16),
    ),
    child: const Padding(
      padding: EdgeInsets.all(14),
      child: Text(
        'مع التفعيل يمكنك رسم حدود الحقل، ومقارنة المؤشرات عبر التواريخ، ومراجعة عينات المواقع وأعلام السحب والظلال، وتدوين ملاحظاتك الميدانية.',
        textAlign: TextAlign.center,
        style: TextStyle(height: 1.5),
      ),
    ),
  );

  Widget _requestStatus({
    required bool pending,
    required bool approvedWithoutGrant,
    required bool rejected,
  }) {
    String message;
    Color color;
    IconData icon;

    if (pending) {
      message = 'طلبك قيد المراجعة لدى الأدمن. ستُفتح الخدمة بعد التفعيل.';
      color = const Color(0xFFB45309);
      icon = Icons.hourglass_top;
    } else if (approvedWithoutGrant) {
      message = 'ظهر أن طلبك معتمد لكن الخدمة غير مفعّلة بعد. تواصل مع الأدمن.';
      color = const Color(0xFFB45309);
      icon = Icons.info_outline;
    } else if (rejected) {
      message = 'لم تتم الموافقة على الطلب السابق. يمكنك إرسال طلب جديد.';
      color = const Color(0xFFB91C1C);
      icon = Icons.info_outline;
    } else if (widget.hasAccessError || widget.hasRequestError) {
      message =
          'تعذر تحديث حالة التفعيل الآن. يمكنك الاطلاع على المزايا ومحاولة إرسال طلبك.';
      color = const Color(0xFF6B7280);
      icon = Icons.sync_problem;
    } else if (widget.checkingAccess) {
      message = 'جارٍ التحقق من حالة الخدمة. يمكنك استعراض المزايا أدناه.';
      color = const Color(0xFF047857);
      icon = Icons.hourglass_empty;
    } else {
      message =
          'الخدمة تحتاج إلى تفعيل الأدمن قبل إنشاء الحقول وطلب التحليلات.';
      color = const Color(0xFF047857);
      icon = Icons.lock_outline;
    }

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}

class _IndexCard extends StatelessWidget {
  final String code;
  final String description;

  const _IndexCard({required this.code, required this.description});

  @override
  Widget build(BuildContext context) => Card(
    elevation: 0,
    margin: EdgeInsets.zero,
    shape: RoundedRectangleBorder(
      side: BorderSide(color: Colors.grey.shade300),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            code,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: Color(0xFF047857),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 11, height: 1.25),
          ),
        ],
      ),
    ),
  );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;

  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Chip(
    avatar: Icon(icon, size: 17, color: const Color(0xFF047857)),
    label: Text(label, style: const TextStyle(fontSize: 11)),
    backgroundColor: Colors.white,
    side: BorderSide(color: Colors.green.shade100),
  );
}
