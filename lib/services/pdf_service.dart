import 'dart:io';
import 'dart:ui' show Rect;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

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
    // تحميل الخطوط
    final regularData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

    // ✅ توليد الـ bytes
    final bytes = _generatePdfBytes(
      regularFontBytes: regularData.buffer.asUint8List(),
      boldFontBytes: boldData.buffer.asUint8List(),
      programTitle: programTitle,
      programEmoji: programEmoji,
      governorate: governorate,
      sectionName: sectionName,
      inputValues: inputValues,
      tasks: tasks,
      materials: materials,
      financial: financial,
    );

    // حفظ الملف
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/nabati_${programTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // مشاركة
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'برنامج $programTitle',
    );
  }

  // ✅ توليد PDF bytes
  static Uint8List _generatePdfBytes({
    required Uint8List regularFontBytes,
    required Uint8List boldFontBytes,
    required String programTitle,
    required String programEmoji,
    required String governorate,
    required String sectionName,
    required Map<String, dynamic> inputValues,
    required List<Map<String, dynamic>> tasks,
    required List<Map<String, dynamic>> materials,
    required Map<String, dynamic> financial,
  }) {
    final PdfDocument document = PdfDocument();

    final regularFont = PdfTrueTypeFont(regularFontBytes, 11);
    final boldFont = PdfTrueTypeFont(boldFontBytes, 12);
    final titleFont = PdfTrueTypeFont(boldFontBytes, 16);
    final smallFont = PdfTrueTypeFont(regularFontBytes, 8);

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

    final double expectedYield =
        ((financial['expected_yield'] as num? ?? 0) * areaMultiplier)
            .toDouble();
    final double expectedPrice =
        (financial['expected_price'] as num? ?? 0).toDouble();
    final double totalRevenue =
        (expectedYield * expectedPrice).toDouble();
    final double netProfit =
        (totalRevenue - totalMaterialsCost).toDouble();
    final double roi = totalMaterialsCost > 0
        ? ((netProfit / totalMaterialsCost) * 100).toDouble()
        : 0.0;

    final sortedTasks = List<Map<String, dynamic>>.from(tasks);
    sortedTasks.sort((a, b) => (a['day_from_start'] as int? ?? 0)
        .compareTo(b['day_from_start'] as int? ?? 0));

    final rtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.right,
      textDirection: PdfTextDirection.rightToLeft,
    );
    final centerRtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      textDirection: PdfTextDirection.rightToLeft,
    );

    PdfPage page = document.pages.add();
    PdfGraphics graphics = page.graphics;

    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;
    double y = 0;

    // Header
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 50),
    );

    PdfTextElement(
      text: 'نباتي',
      font: titleFont,
      brush: PdfBrushes.white,
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, 5, pageWidth - 10, 25));

    PdfTextElement(
      text: 'مستشارك الزراعي الذكي',
      font: smallFont,
      brush: PdfBrushes.white,
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, 30, pageWidth - 10, 15));

    y = 60;

    PdfTextElement(
      text: 'برنامج $programTitle $programEmoji',
      font: titleFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth - 10, 25));
    y += 28;

    PdfTextElement(
      text: 'المحافظة: $governorate',
      font: regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth - 10, 18));
    y += 18;

    PdfTextElement(
      text: 'القسم: $sectionName',
      font: regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth - 10, 18));
    y += 18;

    PdfTextElement(
      text:
          'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان | تاريخ: ${_formatDate(DateTime.now())}',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      format: rtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth - 10, 15));
    y += 25;

    // الجدول الزمني
    if (sortedTasks.isNotEmpty) {
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      PdfTextElement(
        text: 'الجدول الزمني',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      ).draw(page: page, bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15));
      y += 25;

      final taskGrid = _buildTaskGrid(
        sortedTasks,
        regularFont,
        boldFont,
        rtlFormat,
        centerRtlFormat,
      );
      final result = taskGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // المشتريات
    if (materials.isNotEmpty) {
      if (y > pageHeight - 150) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      PdfTextElement(
        text: 'قائمة المشتريات',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      ).draw(page: page, bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15));
      y += 25;

      final materialGrid = _buildMaterialGrid(
        materials,
        areaMultiplier,
        totalMaterialsCost,
        regularFont,
        boldFont,
        rtlFormat,
        centerRtlFormat,
      );
      final result = materialGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // التحليل المالي
    if (expectedYield > 0 || expectedPrice > 0) {
      if (y > pageHeight - 180) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      PdfTextElement(
        text: 'التحليل المالي',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      ).draw(page: page, bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15));
      y += 25;

      final financialGrid = _buildFinancialGrid(
        expectedYield,
        expectedPrice,
        totalRevenue,
        totalMaterialsCost,
        netProfit,
        roi,
        financial,
        regularFont,
        boldFont,
        rtlFormat,
      );
      final result = financialGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // التنبيه
    if (y > pageHeight - 80) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 20;
    }

    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 243, 205)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 35),
    );

    PdfTextElement(
      text:
          'البرنامج استرشادي - يجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي',
      font: boldFont,
      brush: PdfSolidBrush(PdfColor(133, 100, 4)),
      format: centerRtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(5, y + 8, pageWidth - 10, 20));
    y += 45;

    // الفوتر
    if (y > pageHeight - 80) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 20;
    }

    PdfTextElement(
      text: 'تطبيق نباتي - مستشارك الزراعي الذكي',
      font: boldFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      format: centerRtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth, 18));
    y += 20;

    PdfTextElement(
      text: 'إشراف: علي الدهشوري - للتواصل: 01284172047',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      format: centerRtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth, 15));
    y += 18;

    PdfTextElement(
      text: '© 2025 نباتي - جميع الحقوق محفوظة',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(150, 150, 150)),
      format: centerRtlFormat,
    ).draw(page: page, bounds: Rect.fromLTWH(0, y, pageWidth, 15));

    // ✅ Syncfusion بحاجة `saveSync` مش `save`
    final List<int> bytes = document.saveSync();
    document.dispose();

    return Uint8List.fromList(bytes);
  }

  // Helper: جدول المهام
  static PdfGrid _buildTaskGrid(
    List<Map<String, dynamic>> tasks,
    PdfTrueTypeFont regularFont,
    PdfTrueTypeFont boldFont,
    PdfStringFormat rtlFormat,
    PdfStringFormat centerRtlFormat,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 3);
    grid.columns[0].width = 40;
    grid.columns[1].width = 150;
    grid.columns[2].width = 300;

    grid.style = PdfGridStyle(
      font: regularFont,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );

    final header = grid.headers.add(1)[0];
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(4, 120, 87)),
      textBrush: PdfBrushes.white,
      font: boldFont,
    );
    header.cells[0].value = 'اليوم';
    header.cells[1].value = 'المهمة';
    header.cells[2].value = 'التفاصيل';

    header.cells[0].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[1].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[2].style = PdfGridCellStyle(format: centerRtlFormat);

    for (var task in tasks) {
      final row = grid.rows.add();
      row.cells[0].value = '${task['day_from_start'] ?? 0}';
      row.cells[1].value = '${task['title'] ?? ''}';
      row.cells[2].value = '${task['description'] ?? ''}';

      row.cells[0].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[1].style = PdfGridCellStyle(format: rtlFormat);
      row.cells[2].style = PdfGridCellStyle(format: rtlFormat);
    }

    return grid;
  }

  // Helper: جدول المشتريات
  static PdfGrid _buildMaterialGrid(
    List<Map<String, dynamic>> materials,
    double areaMultiplier,
    double totalCost,
    PdfTrueTypeFont regularFont,
    PdfTrueTypeFont boldFont,
    PdfStringFormat rtlFormat,
    PdfStringFormat centerRtlFormat,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 4);
    grid.columns[0].width = 200;
    grid.columns[1].width = 80;
    grid.columns[2].width = 70;
    grid.columns[3].width = 100;

    grid.style = PdfGridStyle(
      font: regularFont,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );

    final header = grid.headers.add(1)[0];
    header.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(4, 120, 87)),
      textBrush: PdfBrushes.white,
      font: boldFont,
    );
    header.cells[0].value = 'المادة';
    header.cells[1].value = 'الكمية';
    header.cells[2].value = 'الوحدة';
    header.cells[3].value = 'التكلفة';

    header.cells[0].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[1].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[2].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[3].style = PdfGridCellStyle(format: centerRtlFormat);

    for (var m in materials) {
      final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
      final price = m['price_per_unit'] as num? ?? 0;
      final cost = qty * price;

      final row = grid.rows.add();
      row.cells[0].value = '${m['name'] ?? ''}';
      row.cells[1].value = qty.toStringAsFixed(2);
      row.cells[2].value = '${m['unit'] ?? ''}';
      row.cells[3].value = '${cost.toStringAsFixed(0)} ج.م';

      row.cells[0].style = PdfGridCellStyle(format: rtlFormat);
      row.cells[1].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[2].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[3].style = PdfGridCellStyle(format: centerRtlFormat);
    }

    final totalRow = grid.rows.add();
    totalRow.style = PdfGridRowStyle(
      backgroundBrush: PdfSolidBrush(PdfColor(236, 253, 245)),
      font: boldFont,
    );
    totalRow.cells[0].value = 'الإجمالي';
    totalRow.cells[1].value = '';
    totalRow.cells[2].value = '';
    totalRow.cells[3].value = '${totalCost.toStringAsFixed(0)} ج.م';

    totalRow.cells[0].style = PdfGridCellStyle(
      format: centerRtlFormat,
      font: boldFont,
    );
    totalRow.cells[3].style = PdfGridCellStyle(
      format: centerRtlFormat,
      font: boldFont,
    );

    return grid;
  }

  // Helper: جدول التحليل المالي
  static PdfGrid _buildFinancialGrid(
    double expectedYield,
    double expectedPrice,
    double totalRevenue,
    double totalMaterialsCost,
    double netProfit,
    double roi,
    Map<String, dynamic> financial,
    PdfTrueTypeFont regularFont,
    PdfTrueTypeFont boldFont,
    PdfStringFormat rtlFormat,
  ) {
    final grid = PdfGrid();
    grid.columns.add(count: 2);
    grid.columns[0].width = 200;
    grid.columns[1].width = 250;

    grid.style = PdfGridStyle(
      font: regularFont,
      cellPadding: PdfPaddings(left: 8, right: 8, top: 5, bottom: 5),
    );

    final items = [
      [
        'الإنتاج المتوقع',
        '${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}'
      ],
      ['الإيراد المتوقع', '${totalRevenue.toStringAsFixed(0)} ج.م'],
      ['إجمالي التكاليف', '${totalMaterialsCost.toStringAsFixed(0)} ج.م'],
      ['صافي الربح', '${netProfit.toStringAsFixed(0)} ج.م'],
      ['نسبة العائد (ROI)', '${roi.toStringAsFixed(1)}%'],
    ];

    for (var item in items) {
      final row = grid.rows.add();
      row.cells[0].value = item[0];
      row.cells[1].value = item[1];
      row.cells[0].style = PdfGridCellStyle(format: rtlFormat, font: boldFont);
      row.cells[1].style = PdfGridCellStyle(format: rtlFormat, font: boldFont);
    }

    return grid;
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
