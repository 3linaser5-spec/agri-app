import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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
    // 1. حساب القيم
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
        ((financial['expected_yield'] as num? ?? 0) * areaMultiplier).toDouble();
    final double expectedPrice =
        (financial['expected_price'] as num? ?? 0).toDouble();
    final double totalRevenue = (expectedYield * expectedPrice).toDouble();
    final double netProfit = (totalRevenue - totalMaterialsCost).toDouble();
    final double roi = totalMaterialsCost > 0
        ? ((netProfit / totalMaterialsCost) * 100).toDouble()
        : 0.0;

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) => (a['day_from_start'] as int? ?? 0)
        .compareTo(b['day_from_start'] as int? ?? 0));

    // 2. إعداد مستند الـ PDF والخط العربي
    final pdf = pw.Document();
    
    final arabicFont = await PdfGoogleFonts.cairoRegular();
    final arabicFontBold = await PdfGoogleFonts.cairoBold();

    // 3. بناء صفحات الـ PDF مع ضبط الاتجاهات بدقة لكل عنصر
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        theme: pw.ThemeData.withFont(
          base: arabicFont,
          bold: arabicFontBold,
        ),
        build: (pw.Context context) {
          return [
            // --- القسم الأول: الهيدر والبيانات الأساسية ---
            pw.Directionality(
              textDirection: pw.TextDirection.rtl,
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('برنامج $programTitle $programEmoji', 
                          style: pw.TextStyle(font: arabicFontBold, fontSize: 20)),
                      pw.Text('تاريخ الإصدار: ${_formatDate(DateTime.now())}',
                          style: pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                    ],
                  ),
                  pw.SizedBox(height: 6),
                  pw.Text('المحافظة: $governorate', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('القسم: $sectionName', style: pw.TextStyle(fontSize: 12)),
                  pw.Text('المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان', style: pw.TextStyle(fontSize: 12)),
                ],
              ),
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),

            // --- القسم الثاني: الجدول الزمني ---
            if (sortedTasks.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text('الجدول الزمني', 
                  style: pw.TextStyle(font: arabicFontBold, fontSize: 16, color: PdfColors.green900)),
              pw.SizedBox(height: 5),
              ...sortedTasks.map((task) {
                final day = task['day_from_start'] ?? 0;
                final title = task['title'] ?? '';
                final desc = task['description'] ?? '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('اليوم $day - $title', 
                          style: pw.TextStyle(font: arabicFontBold, fontSize: 11, color: PdfColors.green800)),
                      if (desc.toString().isNotEmpty) 
                        pw.Text(desc.toString(), style: pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    ],
                  ),
                );
              }).toList(),
              pw.Divider(),
            ],

            // --- القسم الثالث: قائمة المشتريات ---
            if (materials.isNotEmpty) ...[
              pw.SizedBox(height: 5),
              pw.Text('قائمة المشتريات', 
                  style: pw.TextStyle(font: arabicFontBold, fontSize: 16, color: PdfColors.green900)),
              pw.SizedBox(height: 5),
              ...materials.map((m) {
                final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
                final price = m['price_per_unit'] as num? ?? 0;
                final cost = qty * price;
                final name = m['name'] ?? '';
                final unit = m['unit'] ?? '';
                return pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: pw.Text(
                      '• $name - ${qty.toStringAsFixed(2)} $unit - ${cost.toStringAsFixed(0)} ج.م',
                      style: pw.TextStyle(fontSize: 11)),
                );
              }).toList(),
              pw.SizedBox(height: 6),
              pw.Text('الإجمالي: ${totalMaterialsCost.toStringAsFixed(0)} ج.م', 
                  style: pw.TextStyle(font: arabicFontBold, fontSize: 12)),
              pw.Divider(),
            ],

            // --- القسم الرابع: التحليل المالي ---
            if (expectedYield > 0 || expectedPrice > 0) ...[
              pw.SizedBox(height: 5),
              pw.Text('التحليل المالي', 
                  style: pw.TextStyle(font: arabicFontBold, fontSize: 16, color: PdfColors.green900)),
              pw.SizedBox(height: 5),
              pw.Text('الإنتاج المتوقع: ${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}', style: pw.TextStyle(fontSize: 11)),
              pw.Text('الإيراد المتوقع: ${totalRevenue.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 11)),
              pw.Text('إجمالي التكاليف: ${totalMaterialsCost.toStringAsFixed(0)} ج.م', style: pw.TextStyle(fontSize: 11)),
              pw.Text('صافي الربح: ${netProfit.toStringAsFixed(0)} ج.م', 
                  style: pw.TextStyle(font: arabicFontBold, fontSize: 12, color: PdfColors.blue800)),
              pw.Text('نسبة العائد (ROI): ${roi.toStringAsFixed(1)}%', style: pw.TextStyle(fontSize: 11)),
              pw.Divider(),
            ],

            // --- القسم الخامس: الفوتر والتنبيه ---
            pw.SizedBox(height: 5),
            pw.Text(
                'البرنامج استرشادي - يجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي',
                style: pw.TextStyle(fontSize: 10, color: PdfColors.red600)),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Column(
                children: [
                  pw.Text('تطبيق نباتي - مستشارك الزراعي الذكي', 
                      style: pw.TextStyle(font: arabicFontBold, fontSize: 11)),
                  pw.SizedBox(height: 2),
                  pw.Text('إشراف: م. علي الدهشوري - للتواصل: 01284172047', style: pw.TextStyle(fontSize: 10)),
                  pw.SizedBox(height: 2),
                  pw.Text('© ${DateTime.now().year} نباتي - جميع الحقوق محفوظة', 
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                ],
              ),
            ),
          ];
        },
      ),
    );

    // 4. استخراج الملف ومشاركته
    try {
      final output = await getTemporaryDirectory();
      final file = File('${output.path}/Nabaty_Program_${DateTime.now().millisecondsSinceEpoch}.pdf');
      
      await file.writeAsBytes(await pdf.save());

      await Share.shareXFiles(
        [XFile(file.path)],
        subject: 'برنامج $programTitle - تطبيق نباتي',
      );
    } catch (e) {
      throw Exception('فشل إنشاء أو مشاركة ملف PDF: $e');
    }
  }

  static String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day}';
  }
}
