import 'package:flutter/material.dart';

import '../../services/satellite_access_service.dart';
import 'satellite_monitoring_screen.dart';

class SatelliteMonitoringScreen extends StatelessWidget {
  const SatelliteMonitoringScreen({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<bool>(
    stream: SatelliteAccessService.watchAccess(),
    builder: (context, access) {
      if (access.connectionState == ConnectionState.waiting &&
          !access.hasData) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (access.hasError) {
        return const _AccessStateScreen(
          message:
              'تعذر التحقق من تفعيل الخدمة. تحقق من اتصال الإنترنت وحاول مجددًا.',
        );
      }
      if (access.data == true) return const SatelliteFieldsScreen();
      return StreamBuilder<String?>(
        stream: SatelliteAccessService.watchRequestStatus(),
        builder: (context, request) => _SatelliteAccessPanel(
          status: request.data,
          hasError: request.hasError,
        ),
      );
    },
  );
}

class _SatelliteAccessPanel extends StatefulWidget {
  final String? status;
  final bool hasError;

  const _SatelliteAccessPanel({required this.status, required this.hasError});

  @override
  State<_SatelliteAccessPanel> createState() => _SatelliteAccessPanelState();
}

class _SatelliteAccessPanelState extends State<_SatelliteAccessPanel> {
  bool _sending = false;

  Future<void> _sendRequest() async {
    setState(() => _sending = true);
    try {
      await SatelliteAccessService.requestAccess();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم إرسال طلب تفعيل الخدمة إلى الأدمن.'),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.status == 'pending';
    final approvedWithoutGrant = widget.status == 'approved';
    final rejected = widget.status == 'rejected';
    final message = widget.hasError
        ? 'تعذر تحميل حالة طلبك. تحقق من اتصال الإنترنت.'
        : pending
        ? 'طلبك قيد المراجعة. ستظهر الخدمة هنا بعد موافقة الأدمن.'
        : approvedWithoutGrant
        ? 'تمت الموافقة على طلبك، لكن الخدمة غير مفعّلة حاليًا. تواصل مع الأدمن.'
        : rejected
        ? 'لم تتم الموافقة على الطلب السابق. يمكنك إرسال طلب جديد.'
        : 'أرسل طلبًا إلى الأدمن. سيظهر قسم الأقمار بعد تفعيل الخدمة لحسابك.';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('مراقبة المحاصيل بالأقمار'),
          backgroundColor: const Color(0xFF047857),
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.satellite_alt,
                        size: 58,
                        color: Color(0xFF047857),
                      ),
                      const SizedBox(height: 14),
                      const Text(
                        'تفعيل خدمة مراقبة المحاصيل',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(message, textAlign: TextAlign.center),
                      if (!widget.hasError &&
                          !pending &&
                          !approvedWithoutGrant) ...[
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
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
                                  ? 'إرسال طلب جديد'
                                  : 'طلب تفعيل الخدمة',
                            ),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccessStateScreen extends StatelessWidget {
  final String message;
  const _AccessStateScreen({required this.message});

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    ),
  );
}
