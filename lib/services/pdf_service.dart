import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfService {
  // ✅ توليد ملف PDF لبرنامج زراعي
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
    final pdf = pw.Document();

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

    // ترتيب المهام
    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) =>
        (a['day_from_start'] as int? ?? 0)
            .compareTo(b['day_from_start'] as int? ?? 0));

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        textDirection: pw.TextDirection.rtl,
        margin: const pw.EdgeInsets.all(20),
        build: (pw.Context context) => [
          // ============ Header ============
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
                        fontSize: 24,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      'مستشارك الزراعي الذكي',
                      style: const pw.TextStyle(
                        fontSize: 11,
                        color: PdfColors.white,
                      ),
                    ),
                  ],
                ),
                pw.Text(programEmoji, style: const pw.TextStyle(fontSize: 36)),
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
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF047857),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Text('المحافظة: $governorate',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text('القسم: $sectionName',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان',
                    style: const pw.TextStyle(fontSize: 12)),
                pw.Text(
                    'تاريخ الإصدار: ${_formatDate(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 11)),
              ],
            ),
          ),

          pw.SizedBox(height: 16),

          // ============ الجدول الزمني ============
          if (sortedTasks.isNotEmpty) ...[
            _buildSectionTitle('📋 الجدول الزمني'),
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
                    _buildHeaderCell('اليوم'),
                    _buildHeaderCell('المهمة'),
                    _buildHeaderCell('التفاصيل'),
                  ],
                ),
                ...sortedTasks.map((task) {
                  return pw.TableRow(
                    children: [
                      _buildDataCell('${task['day_from_start'] ?? 0}',
                          center: true),
                      _buildDataCell('${task['title'] ?? ''}'),
                      _buildDataCell('${task['description'] ?? ''}'),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ============ المشتريات ============
          if (materials.isNotEmpty) ...[
            _buildSectionTitle('🛒 قائمة المشتريات'),
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
                    _buildHeaderCell('المادة'),
                    _buildHeaderCell('الكمية'),
                    _buildHeaderCell('الوحدة'),
                    _buildHeaderCell('التكلفة'),
                  ],
                ),
                ...materials.map((m) {
                  final qty =
                      (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
                  final price = m['price_per_unit'] as num? ?? 0;
                  final cost = qty * price;
                  return pw.TableRow(
                    children: [
                      _buildDataCell('${m['name'] ?? ''}'),
                      _buildDataCell(qty.toStringAsFixed(2), center: true),
                      _buildDataCell('${m['unit'] ?? ''}', center: true),
                      _buildDataCell('${cost.toStringAsFixed(0)} ج.م',
                          center: true),
                    ],
                  );
                }),
                pw.TableRow(
                  decoration:
                      pw.BoxDecoration(color: PdfColor.fromInt(0xFFECFDF5)),
                  children: [
                    _buildDataCell('الإجمالي',
                        bold: true, center: true),
                    _buildDataCell('', center: true),
                    _buildDataCell('', center: true),
                    _buildDataCell(
                        '${totalMaterialsCost.toStringAsFixed(0)} ج.م',
                        bold: true, center: true),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
          ],

          // ============ التحليل المالي ============
          if (expectedYield > 0 || expectedPrice > 0) ...[
            _buildSectionTitle('💰 التحليل المالي'),
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                borderRadius: pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                children: [
                  _buildFinancialRow('الإنتاج المتوقع',
                      '${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}'),
                  pw.Divider(height: 6),
                  _buildFinancialRow('الإيراد المتوقع',
                      '${totalRevenue.toStringAsFixed(0)} ج.م'),
                  pw.Divider(height: 6),
                  _buildFinancialRow('إجمالي التكاليف',
                      '${totalMaterialsCost.toStringAsFixed(0)} ج.م'),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'صافي الربح',
                    '${netProfit.toStringAsFixed(0)} ج.م',
                    color: netProfit > 0 ? PdfColors.green : PdfColors.red,
                    bold: true,
                  ),
                  pw.Divider(height: 6),
                  _buildFinancialRow(
                    'نسبة العائد (ROI)',
                    '${roi.toStringAsFixed(1)}%',
                    color: roi > 0 ? PdfColors.green : PdfColors.red,
                    bold: true,
                  ),
                ],
              ),
            ),
          ],

          pw.SizedBox(height: 20),

          // ============ Footer ============
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
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF047857),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'إشراف: م. علي الدهشوري',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'للتواصل: 01284172047',
                  style: const pw.TextStyle(fontSize: 10),
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  '© 2025 نباتي - جميع الحقوق محفوظة',
                  style: pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey600,
                  ),
                ),
              ],
            ),
          ),
        ],
        // ============ العلامة المائية على كل صفحة ============
        footer: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.center,
          margin: const pw.EdgeInsets.only(top: 10),
          child: pw.Text(
            'نباتي - ${_formatDate(DateTime.now())}',
            style: pw.TextStyle(
              fontSize: 8,
              color: PdfColors.grey400,
            ),
          ),
        ),
        header: (pw.Context context) => pw.Container(
          alignment: pw.Alignment.centerRight,
          margin: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Text(
            '🌱 نباتي',
            style: pw.TextStyle(
              fontSize: 9,
              color: PdfColors.grey400,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ),
      ),
    );

    // مشاركة / طباعة
    final Uint8List bytes = await pdf.save();
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'nabati_${programTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );
  }

  // ============ Helper Widgets ============

  static pw.Widget _buildSectionTitle(String title) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: pw.BoxDecoration(
        color: PdfColor.fromInt(0xFF047857),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 13,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildHeaderCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(
        text,
        textAlign: pw.TextAlign.center,
        style: pw.TextStyle(
          fontSize: 11,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildDataCell(String text,
      {bool bold = false, bool center = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: center ? pw.TextAlign.center : pw.TextAlign.right,
        style: pw.TextStyle(
          fontSize: 10,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  static pw.Widget _buildFinancialRow(String label, String value,
      {PdfColor? color, bool bold = false}) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 11,
            fontWeight: pw.FontWeight.bold,
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
