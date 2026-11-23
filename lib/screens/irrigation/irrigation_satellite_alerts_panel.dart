import 'package:flutter/material.dart';
import '../../models/map_alert_model.dart';
import '../../services/map_alert_service.dart';

class IrrigationSatelliteAlertsPanel extends StatelessWidget {
  const IrrigationSatelliteAlertsPanel({super.key});

  @override
  Widget build(BuildContext context) => StreamBuilder<List<MapAlert>>(
        stream: MapAlertService.watchAlerts(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Card(child: ListTile(leading: CircularProgressIndicator(), title: Text('جاري تحميل تنبيهات الفحص')));
          }
          final alerts = snapshot.data ?? const <MapAlert>[];
          return Card(
            child: ExpansionTile(
              initiallyExpanded: alerts.isNotEmpty,
              leading: Icon(alerts.isEmpty ? Icons.verified : Icons.warning_amber, color: alerts.isEmpty ? Colors.green : Colors.orange),
              title: const Text('تنبيهات التحليل المرتبطة بالـZones'),
              subtitle: Text(alerts.isEmpty ? 'لا توجد تنبيهات مفتوحة' : '${alerts.length} تنبيهات تحتاج فحصًا ميدانيًا'),
              children: alerts.isEmpty ? const [] : alerts.map((alert) => _AlertTile(alert: alert)).toList(growable: false),
            ),
          );
        },
      );
}

class _AlertTile extends StatelessWidget {
  final MapAlert alert;
  const _AlertTile({required this.alert});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: const Icon(Icons.location_on, color: Colors.red),
        title: Text('${alert.title}${alert.zoneId == null ? '' : ' — Zone ${alert.zoneId}'}'),
        subtitle: Text('${alert.message}\nالإحداثيات: ${alert.latitude.toStringAsFixed(6)}, ${alert.longitude.toStringAsFixed(6)}\nيرجى الفحص الميداني — الخطورة: ${alert.severity}'),
        isThreeLine: true,
        trailing: IconButton(icon: const Icon(Icons.note_add), tooltip: 'تسجيل نتيجة الفحص', onPressed: () => _addNote(context)),
      );

  Future<void> _addNote(BuildContext context) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('نتيجة الفحص الميداني'),
        content: TextField(controller: controller, maxLines: 4, autofocus: true, decoration: const InputDecoration(hintText: 'اكتب ما تم التحقق منه...')),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('إلغاء')), ElevatedButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('حفظ'))],
      ),
    );
    controller.dispose();
    if (note == null || note.trim().isEmpty || !context.mounted) return;
    try {
      await MapAlertService.addInspectionNote(alertId: alert.id, text: note);
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تم حفظ نتيجة الفحص الميداني')));
    } catch (error) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر حفظ نتيجة الفحص: $error')));
    }
  }
}
