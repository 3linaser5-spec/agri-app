import 'package:material_ui/material_ui.dart';

const _blue = Color(0xFF0284C7);

enum IrrigationType { drip, sprinkler, surface, pivot }

const irrigationTypeLabels = <IrrigationType, String>{
  IrrigationType.drip: 'تنقيط',
  IrrigationType.sprinkler: 'رش',
  IrrigationType.surface: 'سطحي',
  IrrigationType.pivot: 'محوري',
};

/// سطر نتيجة في بطاقة مخرجات الحاسبة.
class IrrigationResultLine {
  final String label;
  final String value;
  final int kind; // 0 صف عادي، 1 سليم، 2 تحذير، 3 عنوان قسم

  const IrrigationResultLine.section(this.label)
      : value = '',
        kind = 3;
  const IrrigationResultLine.row(this.label, this.value) : kind = 0;
  const IrrigationResultLine.ok(this.label, this.value) : kind = 1;
  const IrrigationResultLine.warn(this.label, this.value) : kind = 2;
}

/// اختيار نوع نظام الري.
class IrrigationTypeChips extends StatelessWidget {
  final IrrigationType type;
  final ValueChanged<IrrigationType> onSelected;

  const IrrigationTypeChips({
    super.key,
    required this.type,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        for (final t in IrrigationType.values)
          ChoiceChip(
            label: Text(irrigationTypeLabels[t]!),
            selected: type == t,
            selectedColor: _blue.withValues(alpha: 0.2),
            onSelected: (_) => onSelected(t),
          ),
      ],
    );
  }
}

/// عرض سطر واحد من نتائج الحساب.
class IrrigationResultLineTile extends StatelessWidget {
  final IrrigationResultLine line;

  const IrrigationResultLineTile({super.key, required this.line});

  @override
  Widget build(BuildContext context) {
    if (line.kind == 3) {
      return Padding(
        padding: const EdgeInsets.only(top: 12, bottom: 6),
        child: Text(line.label,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: _blue, fontSize: 15)),
      );
    }
    final color = line.kind == 1
        ? Colors.green.shade700
        : line.kind == 2
            ? Colors.red.shade700
            : null;
    final icon = line.kind == 1
        ? Icons.check_circle
        : line.kind == 2
            ? Icons.warning_amber
            : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 6),
          ],
          Expanded(flex: 4, child: Text(line.label)),
          const SizedBox(width: 8),
          Expanded(
            flex: 5,
            child: Text(line.value,
                style: TextStyle(fontWeight: FontWeight.bold, color: color)),
          ),
        ],
      ),
    );
  }
}

/// بطاقة مخرجات الحساب مع أزرار تصدير DXF.
class IrrigationResultCard extends StatelessWidget {
  final List<IrrigationResultLine> lines;
  final bool bomReady;
  final VoidCallback? onOpenBom;
  final bool dxfReady;
  final bool dxf3dReady;
  final bool exporting;
  final VoidCallback onExportDxf;
  final VoidCallback onExportDxf3d;

  const IrrigationResultCard({
    super.key,
    required this.lines,
    this.bomReady = false,
    this.onOpenBom,
    required this.dxfReady,
    required this.dxf3dReady,
    required this.exporting,
    required this.onExportDxf,
    required this.onExportDxf3d,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(top: 20),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final l in lines) IrrigationResultLineTile(line: l),
            if (bomReady && onOpenBom != null) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: onOpenBom,
                icon: const Icon(Icons.receipt_long),
                label: const Text('عرض قائمة المشتريات'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFB45309),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
            if (dxfReady) ...[
              const SizedBox(height: 14),
              ElevatedButton.icon(
                onPressed: exporting ? null : onExportDxf,
                icon: exporting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.download),
                label: Text(exporting
                    ? 'جاري التصدير...'
                    : 'تصدير مخطط 2D بصيغة DXF'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _blue,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
              if (dxf3dReady) ...[
                const SizedBox(height: 8),
                ElevatedButton.icon(
                  onPressed: onExportDxf3d,
                  icon: const Icon(Icons.view_in_ar),
                  label: const Text('تصدير شبكة الري 3D بصيغة DXF'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF166534),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(48),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Text(
                'ملف 3D تخطيطي بوحدة المتر، مع مضخة وخطوط ومكونات النظام. '
                'منسوب الحقل والمضخة يؤخذان من الحقول أعلاه، ولا تُنمذج تضاريس '
                'الحقل أو مسارات الموقع التفصيلية. راجع مهندس ري قبل التنفيذ.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
