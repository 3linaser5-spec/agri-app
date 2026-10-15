import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_pdf_export/flutter_pdf_export.dart';
import '../utils/safe_parse.dart';
import '../config/app_config.dart';

class PdfService {
  static Future<void> generateAndSharePdf({
    required String programTitle,
    required String programEmoji,
    required String governorate,
    required String sectionName,
    required Map<String, dynamic> inputValues,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> materials,
    required Map<String, dynamic> financial,
  }) async {
    // ✅ حساب القيم
    final double areaMultiplier =
        SafeParse.doubleOrNull(inputValues['area']) ?? 1.0;

    double totalMaterialsCost = 0;
    for (var m in materials) {
      final qty = SafeParse.decimal(m['quantity_per_unit']) * areaMultiplier;
      final price = SafeParse.decimal(m['price_per_unit']);
      totalMaterialsCost += qty * price;
    }

    final double expectedYield =
        SafeParse.decimal(financial['expected_yield']) * areaMultiplier;
    final double expectedPrice = SafeParse.decimal(financial['expected_price']);
    final double totalRevenue = (expectedYield * expectedPrice).toDouble();
    final double netProfit = (totalRevenue - totalMaterialsCost).toDouble();
    final double roi = totalMaterialsCost > 0
        ? ((netProfit / totalMaterialsCost) * 100).toDouble()
        : 0.0;

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) => SafeParse.integer(a['day_from_start'])
        .compareTo(SafeParse.integer(b['day_from_start'])));

    // ═══════════════════════════════════════
    // ✅ بناء الأقسام
    // ═══════════════════════════════════════
    final sections = <PdfSection>[];

    // ─── الهيدر + معلومات البرنامج ───
    sections.add(PdfSection.h1('نباتي - مستشارك الزراعي الذكي'));
    sections.add(PdfSection.h2('برنامج $programTitle'));
    sections.add(PdfSection.paragraph('المحافظة: $governorate'));
    sections.add(PdfSection.paragraph('القسم: $sectionName'));
    sections.add(PdfSection.paragraph(
        'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان | تاريخ: ${_formatDate(DateTime.now())}'));
    sections.add(PdfSection.divider());

    // ─── الجدول الزمني (ذكي: سطر أو سطرين حسب الطول) ───
    if (sortedTasks.isNotEmpty) {
      sections.add(PdfSection.h2('الجدول الزمني (${sortedTasks.length} مهمة)'));

      for (var task in sortedTasks) {
        final day = SafeParse.integer(task['day_from_start']);
        final title = task['title'] ?? '';
        final desc = task['description'] ?? '';
        final category = task['category'] ?? '';

        // ✅ السطر الأساسي (اليوم + العنوان + التصنيف)
        String mainLine = 'اليوم $day: $title';
        if (category.toString().isNotEmpty) {
          mainLine += ' [$category]';
        }

        // ✅ لو فيه وصف → نضيفه (في سطر واحد أو سطرين حسب الطول)
        if (desc.toString().isNotEmpty) {
          final descStr = desc.toString();
          // لو الوصف طويل (أكتر من 80 حرف) → في سطر منفصل
          // لو قصير → في نفس السطر
          if (descStr.length > 80) {
            sections.add(PdfSection.paragraph(mainLine));
            sections.add(PdfSection.paragraph(descStr));
          } else {
            sections.add(PdfSection.paragraph('$mainLine - $descStr'));
          }
        } else {
          sections.add(PdfSection.paragraph(mainLine));
        }
      }
      sections.add(PdfSection.divider());
    }

    // ─── المشتريات (كل صنف في سطر واحد) ───
    if (materials.isNotEmpty) {
      sections.add(PdfSection.h2('قائمة المشتريات (${materials.length} صنف)'));

      for (int i = 0; i < materials.length; i++) {
        final m = materials[i];
        final qty = SafeParse.decimal(m['quantity_per_unit']) * areaMultiplier;
        final price = SafeParse.decimal(m['price_per_unit']);
        final cost = qty * price;
        final name = m['name'] ?? '';
        final unit = m['unit'] ?? '';

        sections.add(PdfSection.paragraph(
            '${i + 1}. $name - ${qty.toStringAsFixed(2)} $unit - ${_formatNumber(cost)} ج.م'));
      }

      sections.add(PdfSection.paragraph(
          'الإجمالي: ${_formatNumber(totalMaterialsCost)} ج.م'));
      sections.add(PdfSection.divider());
    }

    // ─── التحليل المالي ───
    if (expectedYield > 0 || expectedPrice > 0) {
      sections.add(PdfSection.h2('التحليل المالي'));
      sections.add(PdfSection.paragraph(
          'الإنتاج المتوقع: ${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}'));
      sections.add(PdfSection.paragraph(
          'الإيراد المتوقع: ${_formatNumber(totalRevenue)} ج.م'));
      sections.add(PdfSection.paragraph(
          'إجمالي التكاليف: ${_formatNumber(totalMaterialsCost)} ج.م'));
      sections.add(PdfSection.paragraph(
          'صافي الربح: ${_formatNumber(netProfit)} ج.م'));
      sections.add(PdfSection.paragraph(
          'نسبة العائد (ROI): ${roi.toStringAsFixed(1)}%'));
      sections.add(PdfSection.divider());
    }

    // ─── التنبيه + الفوتر ───
    sections.add(PdfSection.paragraph(
        'تنبيه: هذا البرنامج استرشادي، ويجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي.'));
    sections.add(PdfSection.paragraph(
        'تطبيق نباتي - مستشارك الزراعي الذكي | إشراف: م. علي الدهشوري | للتواصل: ${AppConfig.engineerPhoneLocal}'));
    sections.add(PdfSection.paragraph(
        '© 2025 نباتي - جميع الحقوق محفوظة'));

    // ═══════════════════════════════════════
    // ✅ توليد الـ PDF
    // ═══════════════════════════════════════
    final pdfData = PdfDocumentData(
      title: 'برنامج $programTitle',
      sections: sections,
    );

    final file = await PdfBuilder.generate(pdfData);

    if (file == null) {
      throw Exception('فشل إنشاء ملف PDF');
    }

    // ✅ مشاركة الملف
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        subject: 'برنامج $programTitle - تطبيق نباتي',
      ),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  // ✅ تنسيق الأرقام بفواصل
  // الرقم السالب (خسارة) كان بيطلع "-,500" لأن الشرطة كانت بتتحسب كرقم.
  static String _formatNumber(double number) {
    final negative = number < 0;
    final str = number.abs().toStringAsFixed(0);
    final buffer = StringBuffer(negative ? '-' : '');
    for (int i = 0; i < str.length; i++) {
      if (i > 0 && (str.length - i) % 3 == 0) {
        buffer.write(',');
      }
      buffer.write(str[i]);
    }
    return buffer.toString();
  }
}
