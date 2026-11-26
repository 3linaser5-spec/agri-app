import '../models/farm_workspace_models.dart';
import '../models/irrigation_design_models.dart';
import 'design_comparison_service.dart';

/// تكوين التقارير النصية والجداول (CSV) لمزرعة المستخدم وتصاميم الري.
///
/// هذه الطبقة نقية بلا Flutter حتى يمكن اختبارها؛ مشاركة الملفات وإنشاء PDF
/// في `farm_share_service.dart`.
class FarmReportService {
  FarmReportService._();

  // ═══════════════════════════════════════
  // CSV / Excel
  // ═══════════════════════════════════════
  static String csvForTasks(Iterable<FarmTask> tasks) {
    final rows = <List<String>>[
      ['المهمة', 'الموعد', 'التكرار', 'الحالة', 'ملاحظات'],
      for (final task in tasks)
        [
          task.title,
          formatDate(task.dueAt),
          task.repeat.label,
          task.done ? 'منجزة' : 'قيد الانتظار',
          task.notes,
        ],
    ];
    return _csv(rows);
  }

  static String csvForCropSeasons(Iterable<CropSeason> seasons) {
    final rows = <List<String>>[
      [
        'المحصول',
        'الصنف',
        'المساحة (فدان)',
        'تاريخ الزراعة',
        'الحصاد',
        'الإنتاج (كجم)',
        'سعر الكيلو',
        'المصروفات',
        'الإيراد',
        'صافي الربح'
      ],
      for (final season in seasons)
        [
          season.crop,
          season.variety,
          season.safeAreaFeddan.toStringAsFixed(2),
          formatDate(season.plantingDate),
          season.harvestDate == null ? '' : formatDate(season.harvestDate!),
          season.effectiveYieldKg.toStringAsFixed(0),
          season.pricePerKg.toStringAsFixed(2),
          season.totalExpenses.toStringAsFixed(0),
          season.revenue.toStringAsFixed(0),
          season.netProfit.toStringAsFixed(0),
        ],
    ];
    return _csv(rows);
  }

  static String _csv(List<List<String>> rows) {
    String cell(String value) => '"${value.replaceAll('"', '""')}"';
    return '${rows.map((row) => row.map(cell).join(',')).join('\n')}\n';
  }

  // ═══════════════════════════════════════
  // نصوص المشاركة
  // ═══════════════════════════════════════
  static String designSummaryText(
    IrrigationDesignProject project, {
    DesignCostRates rates = const DesignCostRates(),
  }) {
    final snapshot =
        const DesignComparisonService().snapshot(project, rates: rates);
    final buffer = StringBuffer()
      ..writeln('🌱 تصميم ري — ${snapshot.name}')
      ..writeln('• المساحة: ${snapshot.areaM2.toStringAsFixed(0)} م²')
      ..writeln('• عدد المناطق: ${snapshot.zones}')
      ..writeln(
          '• التصرف الكلي: ${snapshot.totalFlowLpm.toStringAsFixed(1)} لتر/دقيقة')
      ..writeln(
          '• طول المواسير: ${snapshot.totalPipeMeters.toStringAsFixed(0)} م')
      ..writeln(
          '• المحابس: ${snapshot.valves} · النقاطات/المعدات: ${snapshot.equipment}')
      ..writeln(
          '• المياه اليومية التقديرية: ${snapshot.dailyWaterM3.toStringAsFixed(1)} م³')
      ..writeln(
          '• التكلفة التقديرية: ${snapshot.estimatedCost.toStringAsFixed(0)} ج.م');
    if (project.zones.isNotEmpty) {
      buffer.writeln('— جدول المناطق —');
      for (final zone in project.zones) {
        buffer.writeln(
          '• ${zone.nameAr.isEmpty ? zone.id : zone.nameAr}: '
          '${zone.areaM2.toStringAsFixed(0)} م² · '
          '${zone.designFlowLpm.toStringAsFixed(1)} ل/د',
        );
      }
    }
    buffer.writeln('— نباتي، مستشارك الزراعي —');
    return buffer.toString();
  }

  static String cropSummaryText(
    CropProfitSummary summary, {
    String title = 'ملخص أرباح الموسم',
  }) {
    final buffer = StringBuffer()
      ..writeln('🌾 $title')
      ..writeln('• عدد المواسم: ${summary.seasons}')
      ..writeln('• المساحة: ${summary.areaFeddan.toStringAsFixed(2)} فدان')
      ..writeln('• الإنتاج: ${summary.yieldKg.toStringAsFixed(0)} كجم')
      ..writeln('• الإيراد: ${summary.revenue.toStringAsFixed(0)} ج.م')
      ..writeln('• المصروفات: ${summary.expenses.toStringAsFixed(0)} ج.م')
      ..writeln('• صافي الربح: ${summary.netProfit.toStringAsFixed(0)} ج.م')
      ..writeln(
          '• ربح الفدان: ${summary.profitPerFeddan.toStringAsFixed(0)} ج.م');
    return buffer.toString();
  }

  static String formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';
}
