import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
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
    // ✅ تحميل الخط العربي
    final regularData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');
    final arabicFont = pw.Font.ttf(regularData);
    final arabicBold = pw.Font.ttf(boldData);

    final theme = pw.ThemeData.withFont(
      base: arabicFont,
      bold: arabicBold,
      italic: arabicFont,
      boldItalic: arabicBold,
    );

    final pdf = pw.Document(theme: theme);

    // حساب القيم
    double areaMultiplier = 1.0;
    final area = inputValues['area'];
    if (area is num) areaMultiplier = area.toDouble();

    double totalMaterialsCost = 0;
    for (var m in materials) {
      final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
      final price = m['price_per_unit'] as num? ?? 0;
      totalMaterialsCost += qty * price;
    }

    final expectedYield =
        (financial['expected_yield'] as num? ?? 0) * areaMultiplier;
    final expectedPrice = financial['expected_price'] as num? ?? 0;
    final totalRevenue = expectedYield * expectedPrice;
    final netProfit = totalRevenue - totalMaterialsCost;
    final roi = totalMaterialsCost > 0
        ? (netProfit / totalMaterialsCost) * 100
        : 0.0;

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) => (a['day_from_start'] as int? ?? 0)
        .compareTo(b['day_from_start'] as int? ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.fromLTRB(20, 30, 20, 40),
        theme: theme,

        // ✅ الترويسة (Header) — على كل صفحة
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 8),
          padding: const pw.EdgeInsets.only(bottom: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              bottom: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                'نباتي - مستشارك الزراعي الذكي',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                _formatDate(DateTime.now()),
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 9,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),

        // ✅ التذييل (Footer) — على كل صفحة
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 8),
          padding: const pw.EdgeInsets.only(top: 4),
          decoration: const pw.BoxDecoration(
            border: pw.Border(
              top: pw.BorderSide(color: PdfColors.grey400, width: 0.5),
            ),
          ),
          child: pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '© 2025 نباتي - جميع الحقوق محفوظة',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
              pw.Text(
                'صفحة ${context.pageNumber} من ${context.pagesCount}',
                style: pw.TextStyle(
                  font: arabicFont,
                  fontSize: 8,
                  color: PdfColors.grey600,
                ),
              ),
            ],
          ),
        ),

        build: (pw.Context context) => [
          // ============ Header شعار نباتي ============
          pw.Container(
            padding: const pw.EdgeInsets.all(12),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFF047857),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'نباتي',
                      style: pw.TextStyle(
                        font: arabicBold,
                        fontSize: 24,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'مستشارك الزراعي الذكي',
                      style: pw.TextStyle(
                        font: arabicFont,
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Text(
                  programEmoji,
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 36,
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ============ عنوان البرنامج ============
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFECFDF5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'برنامج $programTitle',
                  style: pw.TextStyle(
                    font: arabicBold,
                    fontSize: 18,
                    color: PdfColor.fromInt(0xFF047857),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  'المحافظة: $governorate',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'القسم: $sectionName',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان',
                  style: pw.TextStyle(font: arabicFont, fontSize: 12),
                ),
                pw.Text(
                  'تاريخ الإصدار: ${_formatDate(DateTime.now())}',
                  style: pw.TextStyle(font: arabicFont, fontSize: 11),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ============ الجدول الزمني ============
          if (sortedTasks.isNotEmpty) ...[
            _buildSectionTitle('الجدول الزمني', arabicBold),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FixedColumnWidth(50),
                1: const pw.FlexColumnWidth(2),
                2: const pw.FlexColumnWidth(3),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromInt(0xFF047857)),
                  children: [
                    _buildHeaderCell('اليوم', arabicBold),
                    _buildHeaderCell('المهمة', arabicBold),
                    _buildHeaderCell('التفاصيل', arabicBold),
                  ],
                ),
                ...sortedTasks.map((task) {
                  return pw.TableRow(
                    children: [
                      _buildDataCell(
                        '${task['day_from_start'] ?? 0}',
                        arabicFont,
                        center: true,
                      ),
                      _buildDataCell(
                          '${task['title'] ?? ''}', arabicFont),
                      _buildDataCell(
                          '${task['description'] ?? ''}', arabicFont),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ============ المشتريات ============
          if (materials.isNotEmpty) ...[
            _buildSectionTitle('قائمة المشتريات', arabicBold),
            pw.SizedBox(height: 8),
            pw.Table(
              border: pw.TableBorder.all(
                color: PdfColors.grey300,
                width: 0.5,
              ),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FixedColumnWidth(60),
                2: const pw.FixedColumnWidth(70),
                3: const pw.FixedColumnWidth(80),
              },
              children: [
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromInt(0xFF047857)),
                  children: [
                    _buildHeaderCell('المادة', arabicBold),
                    _buildHeaderCell('الكمية', arabicBold),
                    _buildHeaderCell('الوحدة', arabicBold),
                    _buildHeaderCell('التكلفة', arabicBold),
                  ],
                ),
                ...materials.map((m) {
                  final qty =
                      (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
                  final price = m['price_per_unit'] as num? ?? 0;
                  final cost = qty * price;
                  return pw.TableRow(
                    children: [
                      _buildDataCell('${m['name'] ?? ''}', arabicFont),
                      _buildDataCell(
                        qty.toStringAsFixed(2),
                        arabicFont,
                        center: true,
                      ),
                      _buildDataCell(
                          '${m['unit'] ?? ''}', arabicFont,
                          center: true),
                      _buildDataCell(
                        '${cost.toStringAsFixed(0)} ج.م',
                        arabicFont,
                        center: true,
                      ),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromInt(0xFFECFDF5)),
                  children: [
                    _buildDataCell('الإجمالي', arabicBold,
                        bold: true, center: true),
                    _buildDataCell('', arabicFont, center: true),
                    _buildDataCell('', arabicFont, center: true),
                    _buildDataCell(
                      '${totalMaterialsCost.toStringAsFixed(0)} ج.م',
                      arabicBold,
                      bold: true,
                      center: true,
                    ),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ============ التحليل المالي ============
          if (expectedYield > 0 || expectedPrice > 0) ...[
            _buildSectionTitle('التحليل المالي', arabicBold),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _buildFinancialRow(
                    'الإنتاج المتوقع',
                    '${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}',
                    arabicFont,
                    arabicBold,
                  ),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'الإيراد المتوقع',
                    '${totalRevenue.toStringAsFixed(0)} ج.م',
                    arabicFont,
                    arabicBold,
                  ),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'إجمالي التكاليف',
                    '${totalMaterialsCost.toStringAsFixed(0)} ج.م',
                    arabicFont,
                    arabicBold,
                  ),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'صافي الربح',
                    '${netProfit.toStringAsFixed(0)} ج.م',
                    arabicFont,
                    arabicBold,
                    color: netProfit > 0 ? PdfColors.green : PdfColors.red,
                    bold: true,
                  ),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'نسبة العائد (ROI)',
                    '${roi.toStringAsFixed(1)}%',
                    arabicFont,
                    arabicBold,
                    color: roi > 0 ? PdfColors.green : PdfColors.red,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 20),

          // ============ تنبيه "هذا البرنامج استرشادي" ============
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFFFF3CD),
              border: pw.Border.all(
                color: PdfColor.fromInt(0xFFFFC107),
                width: 1,
              ),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  '!',
                  style: pw.TextStyle(
                    font: arabicBold,
                    fontSize: 18,
                    color: PdfColor.fromInt(0xFF856404),
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: pw.Text(
                    'تنبيه: هذا البرنامج استرشادي فقط، ويجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي.',
                    style: pw.TextStyle(
                      font: arabicBold,
                      fontSize: 11,
                      color: PdfColor.fromInt(0xFF856404),
                    ),
                  ),
                ),
              ],
            ),
          ),

          pw.SizedBox(height: 12),

          // ============ Footer الرئيسي ============
          pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Column(
              children: [
                pw.Text(
                  'تطبيق نباتي - مستشارك الزراعي الذكي',
                  style: pw.TextStyle(
                    font: arabicBold,
                    fontSize: 12,
                    color: PdfColor.fromInt(0xFF047857),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'إشراف: م. علي الدهشوري',
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'للتواصل: 01284172047',
                  style: pw.TextStyle(font: arabicFont, fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '© 2025 نباتي - جميع الحقوق محفوظة',
                  style: pw.TextStyle(
                    font: arabicFont,
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename:
          'nabati_${programTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ═══════════════════════════════════════
  // Helper Widgets
  // ═══════════════════════════════════════

  static pw.Widget _buildSectionTitle(String title, pw.Font boldFont) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF047857),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 13,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text, pw.Font boldFont) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          font: boldFont,
          fontSize: 11,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(
    String text,
    pw.Font font, {
    bool bold = false,
    bool center = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        style: pw.TextStyle(
          font: font,
          fontSize: 10,
        ),
      ),
    );
  }

  static pw.Widget _buildFinancialRow(
    String label,
    String value,
    pw.Font font,
    pw.Font boldFont, {
    PdfColor? color,
    bool bold = false,
  }) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            font: bold ? boldFont : font,
            fontSize: 11,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            font: boldFont,
            fontSize: 11,
            color: color ?? PdfColors.black,
          ),
        ),
      ],
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
