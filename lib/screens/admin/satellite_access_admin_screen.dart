import 'package:flutter/material.dart';

import '../../services/calculator_service.dart';
import '../../services/satellite_access_service.dart';

class SatelliteAccessAdminScreen extends StatefulWidget {
  const SatelliteAccessAdminScreen({super.key});

  @override
  State<SatelliteAccessAdminScreen> createState() =>
      _SatelliteAccessAdminScreenState();
}

class _SatelliteAccessAdminScreenState
    extends State<SatelliteAccessAdminScreen> {
  bool _checkingAdmin = true;
  bool _isAdmin = false;
  String? _error;
  final Set<String> _busyUids = {};

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final allowed = await CalculatorService.isCurrentUserAdmin();
    if (!mounted) return;
    setState(() {
      _isAdmin = allowed;
      _checkingAdmin = false;
      if (!allowed) _error = 'هذه الصفحة متاحة للأدمن فقط.';
    });
  }

  Future<void> _review(
    SatelliteAccessRequest request, {
    required bool approve,
  }) async {
    final action = approve ? 'تفعيل الخدمة' : 'رفض الطلب';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('$action؟'),
          content: Text(
            approve
                ? 'سيتم تفعيل مراقبة الأقمار الصناعية للمستخدم ${request.name}.'
                : 'سيتم رفض طلب ${request.name}. يمكنه إرسال طلب جديد لاحقًا.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text(action),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyUids.add(request.uid));
    try {
      if (approve) {
        await SatelliteAccessService.approveRequest(request.uid);
      } else {
        await SatelliteAccessService.rejectRequest(request.uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approve
                  ? 'تم تفعيل الخدمة للمستخدم.'
                  : 'تم رفض الطلب، ويمكن للمستخدم إعادة إرساله.',
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'تعذر $action: ${error.toString().replaceFirst('Bad state: ', '')}',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busyUids.remove(request.uid));
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'وقت الإرسال غير متاح';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('طلبات تفعيل مراقبة الأقمار'),
          backgroundColor: const Color(0xFF047857),
          foregroundColor: Colors.white,
        ),
        body: _checkingAdmin
            ? const Center(child: CircularProgressIndicator())
            : !_isAdmin
            ? Center(child: Text(_error ?? 'غير مصرح'))
            : StreamBuilder<List<SatelliteAccessRequest>>(
                stream: SatelliteAccessService.watchPendingRequests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting &&
                      !snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                          'تعذر تحميل الطلبات. تحقق من صلاحية الأدمن وقواعد Firestore.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  final requests = snapshot.data ?? const [];
                  if (requests.isEmpty) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.inbox_outlined,
                              size: 56,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 12),
                            Text('لا توجد طلبات تفعيل معلّقة.'),
                          ],
                        ),
                      ),
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final busy = _busyUids.contains(request.uid);
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          side: BorderSide(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const CircleAvatar(
                                    backgroundColor: Color(0xFFEAF6F0),
                                    child: Icon(
                                      Icons.satellite_alt,
                                      color: Color(0xFF047857),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      request.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                  const Chip(label: Text('قيد المراجعة')),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                request.phone.isEmpty
                                    ? 'رقم الهاتف غير متاح في الحساب'
                                    : 'الهاتف: ${request.phone}',
                              ),
                              const SizedBox(height: 3),
                              SelectableText('UID: ${request.uid}'),
                              const SizedBox(height: 3),
                              Text(
                                'تاريخ الطلب: ${_date(request.requestedAt)}',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () => _review(
                                              request,
                                              approve: false,
                                            ),
                                      icon: const Icon(Icons.close),
                                      label: const Text('رفض'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: FilledButton.icon(
                                      onPressed: busy
                                          ? null
                                          : () =>
                                                _review(request, approve: true),
                                      icon: busy
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.check),
                                      label: const Text('تفعيل الخدمة'),
                                      style: FilledButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF047857,
                                        ),
                                        foregroundColor: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
      ),
    );
  }
}
