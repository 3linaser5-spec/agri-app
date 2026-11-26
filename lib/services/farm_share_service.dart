import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_pdf_export/flutter_pdf_export.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config/app_config.dart';
import '../models/farm_workspace_models.dart';
import '../models/irrigation_design_models.dart';
import 'design_comparison_service.dart';
import 'farm_report_service.dart';
import 'irrigation_export_service.dart';

/// مشاركة تقارير المزرعة: PDF جاهز على واتساب، ملف CSV يفتح في Excel، ونص
/// ملخص للمشاركة السريعة.
class FarmShareService {
  FarmShareService._();

  static const String _disclaimer =
      'هذا التقرير استرشادي، ويجب مراجعته مع المهندس الزراعي قبل التطبيق.';

  /// مشاركة ملف CSV (يفتح مباشرة في Excel أو Google Sheets).
  static Future<void> shareCsv({
    required String fileName,
    required String content,
    required String subject,
  }) async {
    final directory = await getTemporaryDirectory();
    final safeName = fileName.replaceAll(RegExp(r'[^\w\-\.]+'), '_');
    final file = File('${directory.path}/$safeName.csv');
    await file.writeAsString('\uFEFF$content'); // BOM حتى تظهر العربية في Excel
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path)], subject: subject),
    );
  }

  /// مشاركة نص عبر أي تطبيق (واتساب، تليجرام...).
  static Future<void> shareText(String text, {String subject = 'نباتي'}) async {
    await SharePlus.instance.share(
      ShareParams(text: text, subject: subject),
    );
  }

  static Future<void> shareDesignPdf(
    IrrigationDesignProject project, {
    DesignCostRates rates = const DesignCostRates(),
  }) async {
    final snapshot =
        const DesignComparisonService().snapshot(project, rates: rates);
    final sections = <PdfSection>[
      PdfSection.h1('نباتي — تقرير تصميم الري'),
      PdfSection.h2(snapshot.name),
      PdfSection.paragraph('التاريخ: ${FarmReportService.formatDate(DateTime.now())}'),
      PdfSection.divider(),
      PdfSection.h2('ملخص التصميم'),
      PdfSection.paragraph('المساحة: ${snapshot.areaM2.toStringAsFixed(0)} م²'),
      PdfSection.paragraph('عدد المناطق: ${snapshot.zones}'),
      PdfSection.paragraph(
          'التصرف الكلي: ${snapshot.totalFlowLpm.toStringAsFixed(1)} لتر/دقيقة'),
      PdfSection.paragraph(
          'المياه اليومية التقديرية: ${snapshot.dailyWaterM3.toStringAsFixed(1)} م³'),
      PdfSection.paragraph(
          'التكلفة التقديرية: ${snapshot.estimatedCost.toStringAsFixed(0)} ج.م'),
      PdfSection.divider(),
      PdfSection.h2('جدول المناطق'),
    ];
    if (project.zones.isEmpty) {
      sections.add(PdfSection.paragraph('لا توجد مناطق محفوظة.'));
    } else {
      for (final zone in project.zones) {
        sections.add(PdfSection.paragraph(
          '${zone.nameAr.isEmpty ? zone.id : zone.nameAr}: '
          '${zone.areaM2.toStringAsFixed(0)} م² · ${zone.method} · '
          '${zone.designFlowLpm.toStringAsFixed(1)} ل/د · '
          '${zone.applicationRateMmH.toStringAsFixed(2)} مم/س',
        ));
      }
    }
    sections.add(PdfSection.divider());
    sections.add(PdfSection.h2('قائمة المشتريات (BOQ)'));
    try {
      final bundle = IrrigationExportService.exportProject(project);
      if (bundle.boq.isEmpty) {
        sections.add(PdfSection.paragraph('لا توجد بنود.'));
      } else {
        for (final line in bundle.boq) {
          sections.add(PdfSection.paragraph(
            '• ${line.description} — ${line.quantity} ${line.unit}',
          ));
        }
      }
    } on IrrigationExportValidationException catch (error) {
      sections.add(PdfSection.paragraph(
          'تعذر توليد قائمة المشتريات الكاملة: ${error.errors.join('; ')}'));
    }
    sections.add(PdfSection.divider());
    sections.add(PdfSection.paragraph(_disclaimer));
    sections.add(PdfSection.paragraph(
        'تطبيق نباتي | للتواصل: ${AppConfig.engineerPhoneLocal}'));
    await _sharePdf(
      PdfDocumentData(title: 'تصميم ري — ${snapshot.name}', sections: sections),
      subject: 'تصميم ري — ${snapshot.name}',
    );
  }

  static Future<void> shareCropPdf({
    required CropProfitSummary summary,
    List<CropSeason> seasons = const [],
  }) async {
    final sections = <PdfSection>[
      PdfSection.h1('نباتي — تقرير المحاصيل والأرباح'),
      PdfSection.paragraph('التاريخ: ${FarmReportService.formatDate(DateTime.now())}'),
      PdfSection.divider(),
      PdfSection.h2('ملخص الموسم'),
      PdfSection.paragraph('عدد المواسم: ${summary.seasons}'),
      PdfSection.paragraph(
          'المساحة: ${summary.areaFeddan.toStringAsFixed(2)} فدان'),
      PdfSection.paragraph('الإنتاج: ${summary.yieldKg.toStringAsFixed(0)} كجم'),
      PdfSection.paragraph(
          'الإيراد: ${summary.revenue.toStringAsFixed(0)} ج.م'),
      PdfSection.paragraph(
          'المصروفات: ${summary.expenses.toStringAsFixed(0)} ج.م'),
      PdfSection.paragraph(
          'صافي الربح: ${summary.netProfit.toStringAsFixed(0)} ج.م'),
      PdfSection.paragraph(
          'ربح الفدان: ${summary.profitPerFeddan.toStringAsFixed(0)} ج.م'),
      PdfSection.divider(),
      PdfSection.h2('تفاصيل المواسم'),
    ];
    if (seasons.isEmpty) {
      sections.add(PdfSection.paragraph('لا توجد مواسم مسجلة.'));
    } else {
      for (final season in seasons) {
        sections.add(PdfSection.paragraph(
          '${season.crop}${season.variety.isEmpty ? '' : ' (${season.variety})'} · '
          '${season.safeAreaFeddan.toStringAsFixed(2)} فدان · '
          'إنتاج ${season.effectiveYieldKg.toStringAsFixed(0)} كجم · '
          'ربح ${season.netProfit.toStringAsFixed(0)} ج.م',
        ));
      }
    }
    sections.add(PdfSection.divider());
    sections.add(PdfSection.paragraph(_disclaimer));
    await _sharePdf(
      PdfDocumentData(title: 'تقرير المحاصيل والأرباح', sections: sections),
      subject: 'تقرير المحاصيل والأرباح',
    );
  }

  static Future<void> shareTasksPdf(List<FarmTask> tasks) async {
    final sections = <PdfSection>[
      PdfSection.h1('نباتي — مهام المزرعة'),
      PdfSection.paragraph('التاريخ: ${FarmReportService.formatDate(DateTime.now())}'),
      PdfSection.divider(),
    ];
    if (tasks.isEmpty) {
      sections.add(PdfSection.paragraph('لا توجد مهام مسجلة.'));
    } else {
      for (final task in tasks) {
        sections.add(PdfSection.paragraph(
          '${task.done ? '✅' : '•'} ${task.title} — '
          '${FarmReportService.formatDate(task.dueAt)} (${task.repeat.label})',
        ));
      }
    }
    await _sharePdf(
      PdfDocumentData(title: 'مهام المزرعة', sections: sections),
      subject: 'مهام المزرعة',
    );
  }

  static Future<void> _sharePdf(
    PdfDocumentData data, {
    required String subject,
  }) async {
    try {
      final file = await PdfBuilder.generate(data);
      await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path)], subject: subject),
      );
    } catch (error) {
      debugPrint('تعذر إنشاء ملف PDF: $error');
      rethrow;
    }
  }
}
