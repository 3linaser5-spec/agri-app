import 'package:flutter/material.dart';
import '../../services/calculator_service.dart';
import '../../services/landscape_satellite_access_service.dart';

class LandscapeSatelliteAccessAdminScreen extends StatefulWidget {
  const LandscapeSatelliteAccessAdminScreen({super.key});
  @override
  State<LandscapeSatelliteAccessAdminScreen> createState() => _LandscapeSatelliteAccessAdminScreenState();
}

class _LandscapeSatelliteAccessAdminScreenState extends State<LandscapeSatelliteAccessAdminScreen> {
  final uidController = TextEditingController();
  final maxFeddanController = TextEditingController(text: '1');
  bool checking = true, admin = false, enabled = false, busy = false;
  double maxFeddan = 1;

  @override
  void initState() {
    super.initState();
    CalculatorService.isCurrentUserAdmin().then((value) {
      if (mounted) setState(() { admin = value; checking = false; });
    });
  }

  @override
  void dispose() { uidController.dispose(); maxFeddanController.dispose(); super.dispose(); }

  Future<void> lookup() async {
    final uid = uidController.text.trim();
    if (uid.isEmpty) return;
    setState(() => busy = true);
    try {
      final value = await LandscapeSatelliteAccessService.getEntitlement(uid);
      if (mounted) {
        setState(() {
          enabled = value.active;
          maxFeddan = value.maxFeddan;
          maxFeddanController.text = value.maxFeddan.toString();
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final uid = uidController.text.trim();
    if (uid.isEmpty) return;
    setState(() => busy = true);
    try {
      final parsedMax = double.tryParse(maxFeddanController.text.trim());
      if (parsedMax == null || parsedMax < 0) throw ArgumentError('أدخل مساحة فدان صحيحة');
      await LandscapeSatelliteAccessService.setAccess(uid: uid, enabled: enabled, maxFeddan: parsedMax);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(enabled ? 'تم تفعيل خدمة أقمار اللاندسكيب' : 'تم إيقاف خدمة أقمار اللاندسكيب')));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (checking) {
      content = const Center(child: CircularProgressIndicator());
    } else if (!admin) {
      content = const Center(child: Text('هذه الصفحة للأدمن فقط'));
    } else {
      content = Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(controller: uidController, decoration: const InputDecoration(labelText: 'UID المستخدم', hintText: 'أدخل UID ثم اضغط فحص')),
          const SizedBox(height: 12),
          TextField(controller: maxFeddanController, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'الحد الأقصى للمساحة (فدان)')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(child: OutlinedButton(onPressed: busy ? null : lookup, child: const Text('فحص الحالة'))),
            const SizedBox(width: 12),
            Expanded(child: SwitchListTile(value: enabled, onChanged: busy ? null : (value) => setState(() => enabled = value), title: const Text('مفعّلة'), contentPadding: EdgeInsets.zero)),
          ]),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: busy ? null : save, icon: const Icon(Icons.save), label: const Text('حفظ صلاحية اللاندسكيب')),
        ]),
      );
    }
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('أقمار اللاندسكيب')), body: content));
  }
}
