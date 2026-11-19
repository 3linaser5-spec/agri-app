import 'package:flutter/material.dart';

import '../../models/subscriber_model.dart';
import '../../services/calculator_service.dart';
import '../../services/subscriber_service.dart';

class ActiveSubscribersScreen extends StatefulWidget {
  const ActiveSubscribersScreen({super.key});

  @override
  State<ActiveSubscribersScreen> createState() => _ActiveSubscribersScreenState();
}

class _ActiveSubscribersScreenState extends State<ActiveSubscribersScreen> {
  static const green = Color(0xFF047857);
  final Set<String> _busy = {};

  String _date(DateTime? d) => d == null
      ? 'غير محدد'
      : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _editLimit(ActiveSubscriber subscriber) async {
    final controller = TextEditingController(
      text: subscriber.areaLimitFeddans.toStringAsFixed(2),
    );
    final value = await showDialog<double>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: Text('حد مساحة ${subscriber.name}'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'الحد الأقصى بالفدان',
              suffixText: 'فدان',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final parsed = double.tryParse(controller.text.trim());
                if (parsed == null || !parsed.isFinite || parsed <= 0) return;
                Navigator.pop(dialogContext, parsed);
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _busy.add(subscriber.uid));
    try {
      await SubscriberService.setAreaLimit(uid: subscriber.uid, maxAreaFeddan: value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم تحديث حد المساحة بالفدان.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تعذر تحديث الحد: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(subscriber.uid));
    }
  }

  @override
  Widget build(BuildContext context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('المشتركون النشطون'),
            backgroundColor: green,
            foregroundColor: Colors.white,
          ),
          body: FutureBuilder<bool>(
            future: CalculatorService.isCurrentUserAdmin(),
            builder: (context, auth) {
              if (!auth.hasData) return const Center(child: CircularProgressIndicator());
              if (auth.data != true) return const Center(child: Text('هذه الصفحة متاحة للأدمن فقط.'));
              return StreamBuilder<List<ActiveSubscriber>>(
                stream: SubscriberService.watchActiveSubscribers(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Center(child: Text('تعذر تحميل المشتركين: ${snapshot.error}'));
                  final items = snapshot.data ?? const <ActiveSubscriber>[];
                  if (items.isEmpty) return const Center(child: Text('لا يوجد مشتركون نشطون حاليًا.'));
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _card(items[i]),
                  );
                },
              );
            },
          ),
        ),
      );

  Widget _card(ActiveSubscriber s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: Color(0xFFEAF6F0),
                    child: Icon(Icons.person, color: green),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.name,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ),
                  Chip(label: Text(s.plan)),
                ],
              ),
              if (s.phone.isNotEmpty) Text('الهاتف: ${s.phone}'),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _metric('الحد', '${s.areaLimitFeddans.toStringAsFixed(2)} فدان')),
                  Expanded(child: _metric('المستخدم', '${s.usedAreaFeddans.toStringAsFixed(2)} فدان')),
                  Expanded(child: _metric('المتبقي', '${s.remainingAreaFeddans.toStringAsFixed(2)} فدان')),
                ],
              ),
              const SizedBox(height: 10),
              LinearProgressIndicator(
                value: s.usageRatio,
                color: s.usageRatio > .9 ? Colors.red : green,
                backgroundColor: green.withValues(alpha: .12),
              ),
              const SizedBox(height: 5),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('استخدام ${(s.usageRatio * 100).toStringAsFixed(0)}%'),
                  Text('ينتهي: ${_date(s.expiresAt)}'),
                ],
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton.icon(
                  onPressed: _busy.contains(s.uid) ? null : () => _editLimit(s),
                  icon: _busy.contains(s.uid)
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.edit_location_alt_outlined),
                  label: const Text('تعديل حد المساحة بالفدان'),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _metric(String label, String value) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      );
}
