import 'package:flutter_pdf_export/flutter_pdf_export.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/irrigation_bom_models.dart';
import '../../services/farm_share_service.dart';
import '../../services/irrigation_bom_service.dart';

const _blue = Color(0xFF0284C7);

String _qty(double value) {
  if (!value.isFinite) return '-';
  return value == value.roundToDouble()
      ? value.toStringAsFixed(0)
      : value.toStringAsFixed(1);
}

/// قائمة المشتريات: بنود التصميم بكمياتها ووحداتها، بدون أسعار، عشان
/// المستخدم يبعتها للمورد وياخد عروض أسعار.
class IrrigationBomScreen extends StatefulWidget {
  final IrrigationBom bom;

  const IrrigationBomScreen({super.key, required this.bom});

  @override
  State<IrrigationBomScreen> createState() => _IrrigationBomScreenState();
}

class _IrrigationBomScreenState extends State<IrrigationBomScreen> {
  bool _busy = false;

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  Future<void> _shareCsv() async {
    final bom = widget.bom;
    try {
      await FarmShareService.shareCsv(
        fileName: 'bom_${bom.system.name}',
        content: IrrigationBomService.toCsv(bom),
        subject: 'قائمة مشتريات ${bom.name.isEmpty ? bom.systemLabel : bom.name} - نباتي',
      );
    } catch (_) {
      _snack('تعذر إنشاء ملف CSV');
    }
  }

  Future<void> _sharePdf() async {
    final bom = widget.bom;
    final title = bom.name.isEmpty ? bom.systemLabel : bom.name;
    setState(() => _busy = true);
    try {
      final sections = <PdfSection>[
        PdfSection.h1('نباتي — قائمة مشتريات ($title)'),
        PdfSection.paragraph(
            'المساحة: ${bom.areaFeddan.toStringAsFixed(2)} فدان'),
        PdfSection.paragraph(
            'التاريخ: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}'),
        PdfSection.divider(),
        for (final entry in bom.grouped.entries) ...[
          PdfSection.h2(entry.key),
          for (final item in entry.value)
            PdfSection.paragraph(
              '• ${item.name}${item.spec.isEmpty ? '' : ' (${item.spec})'} — '
              '${_qty(item.quantity)} ${item.unit}',
            ),
        ],
        PdfSection.divider(),
        for (final note in bom.notes) PdfSection.paragraph('ملاحظة: $note'),
        PdfSection.paragraph(
            'القائمة بدون أسعار: تُستخدم لطلب عروض أسعار من الموردين.'),
      ];
      final file = await PdfBuilder.generate(PdfDocumentData(
        title: 'قائمة مشتريات $title',
        sections: sections,
      ));
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path)],
        subject: 'قائمة مشتريات $title - نباتي',
      ));
    } catch (_) {
      _snack('تعذر إنشاء ملف PDF');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bom = widget.bom;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            bom.name.isEmpty
                ? 'قائمة مشتريات — ${bom.systemLabel}'
                : 'قائمة مشتريات — ${bom.name}',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: _blue,
          iconTheme: const IconThemeData(color: Colors.white),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        bom.name.isEmpty
                            ? 'نظام الري: ${bom.systemLabel}'
                            : '${bom.name} — ${bom.systemLabel}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('المساحة: ${bom.areaFeddan.toStringAsFixed(2)} فدان'),
                    const SizedBox(height: 4),
                    Text('عدد البنود: ${bom.lines}',
                        style: const TextStyle(color: Colors.grey)),
                    const SizedBox(height: 8),
                    const Text(
                      'قائمة كميات بدون أسعار — ابعتها للمورد واطلب تسعيرها.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
            for (final entry in bom.grouped.entries) ...[
              Padding(
                padding: const EdgeInsets.only(top: 18, bottom: 8),
                child: Text(entry.key,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _blue,
                        fontSize: 15)),
              ),
              Card(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Column(
                    children: [
                      for (final item in entry.value) _itemRow(item),
                    ],
                  ),
                ),
              ),
            ],
            for (final note in bom.notes)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('• $note',
                    style:
                        const TextStyle(fontSize: 12, color: Colors.grey)),
              ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _busy ? null : _sharePdf,
              icon: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_busy ? 'جاري إنشاء الملف...' : 'مشاركة القائمة PDF'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _blue,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _shareCsv,
              icon: const Icon(Icons.table_view),
              label: const Text('مشاركة القائمة CSV (Excel)'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _itemRow(IrrigationBomItem item) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (item.spec.isNotEmpty)
                    Text(item.spec,
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text('${_qty(item.quantity)} ${item.unit}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );
}
