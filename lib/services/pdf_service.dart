import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_pdf_export/flutter_pdf_export.dart';

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
    double areaMultiplier = 1.0;
    final area = inputValues['area'];
    if (area is num) areaMultiplier = area.toDouble();

    double totalMaterialsCost = 0;
    for (var m in materials) {
      final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
      final price = m['price_per_unit'] as num? ?? 0;
      totalMaterialsCost += qty * price;
    }

    final double expectedYield =
        ((financial['expected_yield'] as num? ?? 0) * areaMultiplier)
            .toDouble();
    final double expectedPrice =
        (financial['expected_price'] as num? ?? 0).toDouble();
    final double totalRevenue = (expectedYield * expectedPrice).toDouble();
    final double netProfit =
        (totalRevenue - totalMaterialsCost).toDouble();
    final double roi = totalMaterialsCost > 0
        ? ((netProfit / totalMaterialsCost) * 100).toDouble()
        : 0.0;

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) => (a['day_from_start'] as int? ?? 0)
        .compareTo(b['day_from_start'] as int? ?? 0));

    // ✅ بناء الأقسام
    final sections = <PdfSection>[
      PdfSection.h1('برنامج $programTitle $programEmoji'),
      PdfSection.paragraph('المحافظة: $governorate'),
      PdfSection.paragraph('القسم: $sectionName'),
      PdfSection.paragraph(
          'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان'),
      PdfSection.paragraph(
          'تاريخ الإصدار: ${_formatDate(DateTime.now())}'),
      PdfSection.divider(),
    ];

    // ✅ الجدول الزمني
    if (sortedTasks.isNotEmpty) {
      sections.add(PdfSection.h2('الجدول الزمني'));
      for (var task in sortedTasks) {
        final day = task['day_from_start'] ?? 0;
        final title = task['title'] ?? '';
        final desc = task['description'] ?? '';
        sections.add(PdfSection.paragraph('اليوم $day - $title'));
        if (desc.toString().isNotEmpty) {
          sections.add(PdfSection.paragraph(desc.toString()));
        }
      }
      sections.add(PdfSection.divider());
    }

    // ✅ المشتريات
    if (materials.isNotEmpty) {
      sections.add(PdfSection.h2('قائمة المشتريات'));
      for (var m in materials) {
        final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
        final price = m['price_per_unit'] as num? ?? 0;
        final cost = qty * price;
        final name = m['name'] ?? '';
        final unit = m['unit'] ?? '';
        sections.add(PdfSection.paragraph(
            '$name - ${qty.toStringAsFixed(2)} $unit - ${cost.toStringAsFixed(0)} ج.م'));
      }
      sections.add(PdfSection.paragraph(
          'الإجمالي: ${totalMaterialsCost.toStringAsFixed(0)} ج.م'));
      sections.add(PdfSection.divider());
    }

    // ✅ التحليل المالي
    if (expectedYield > 0 || expectedPrice > 0) {
      sections.add(PdfSection.h2('التحليل المالي'));
      sections.add(PdfSection.paragraph(
          'الإنتاج المتوقع: ${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}'));
      sections.add(PdfSection.paragraph(
          'الإيراد المتوقع: ${totalRevenue.toStringAsFixed(0)} ج.م'));
      sections.add(PdfSection.paragraph(
          'إجمالي التكاليف: ${totalMaterialsCost.toStringAsFixed(0)} ج.م'));
      sections.add(PdfSection.paragraph(
          'صافي الربح: ${netProfit.toStringAsFixed(0)} ج.م'));
      sections.add(PdfSection.paragraph(
          'نسبة العائد ROI: ${roi.toStringAsFixed(1)}%'));
      sections.add(PdfSection.divider());
    }

    // ✅ التنبيه
    sections.add(PdfSection.paragraph(
        'البرنامج استرشادي - يجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي'));

    sections.add(PdfSection.divider());

    // ✅ الفوتر
    sections.add(PdfSection.paragraph(
        'تطبيق نباتي - مستشارك الزراعي الذكي'));
    sections.add(PdfSection.paragraph(
        'إشراف: علي الدهشوري - للتواصل: 01284172047'));
    sections.add(PdfSection.paragraph(
        '© 2025 نباتي - جميع الحقوق محفوظة'));

    // ✅ توليد الـ PDF
    final pdfData = PdfDocumentData(
      title: 'برنامج $programTitle',
      sections: sections,
    );

    final file = await PdfBuilder.generate(pdfData);

    if (file == null) {
      throw Exception('فشل إنشاء ملف PDF');
    }

    // ✅ مشاركة الملف
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'برنامج $programTitle',
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
