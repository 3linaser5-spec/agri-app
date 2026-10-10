import 'dart:io';
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
    // ✅ إنشاء مستند PDF جديد
    final PdfDocument document = PdfDocument();

    // ✅ تحميل الخط العربي
    final regularData =
        await rootBundle.load('assets/fonts/Cairo-Regular.ttf');
    final boldData = await rootBundle.load('assets/fonts/Cairo-Bold.ttf');

    final regularFont = PdfTrueTypeFont(
      regularData.buffer.asUint8List(),
      12,
    );
    final boldFont = PdfTrueTypeFont(
      boldData.buffer.asUint8List(),
      14,
    );
    final titleFont = PdfTrueTypeFont(
      boldData.buffer.asUint8List(),
      18,
    );
    final smallFont = PdfTrueTypeFont(
      regularData.buffer.asUint8List(),
      9,
    );

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

    // ✅ حجم الصفحة A4
    final PdfPageSettings pageSettings = PdfPageSettings()
      ..size = PdfPageSize.a4
      ..margins.all = 40;

    // ✅ إنشاء صفحة أولى
    PdfPage page = document.pages.add();
    PdfGraphics graphics = page.graphics;

    // ✅ استخدام RTL (من اليمين لليسار)
    final PdfStringFormat rtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.right,
      textDirection: PdfTextDirection.rightToLeft,
    );
    final PdfStringFormat centerFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      textDirection: PdfTextDirection.rightToLeft,
    );

    // ═══════════════════════════════════════
    // الهيدر - شعار نباتي
    // ═══════════════════════════════════════
    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;
    double y = 0;

    // خلفية خضراء للهيدر
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 60),
    );

    // شعار "نباتي"
    graphics.drawString(
      'نباتي',
      titleFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(0, 8, pageWidth - 20, 30),
      format: rtlFormat,
    );

    graphics.drawString(
      'مستشارك الزراعي الذكي',
      smallFont,
      brush: PdfBrushes.white,
      bounds: Rect.fromLTWH(0, 38, pageWidth - 20, 20),
      format: rtlFormat,
    );

    y = 75;

    // ═══════════════════════════════════════
    // عنوان البرنامج
    // ═══════════════════════════════════════
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(236, 253, 245)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 90),
    );

    graphics.drawString(
      'برنامج $programTitle $programEmoji',
      titleFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      bounds: Rect.fromLTWH(0, y + 8, pageWidth - 15, 30),
      format: rtlFormat,
    );

    graphics.drawString(
      'المحافظة: $governorate',
      regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: Rect.fromLTWH(0, y + 40, pageWidth - 15, 20),
      format: rtlFormat,
    );

    graphics.drawString(
      'القسم: $sectionName',
      regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      bounds: Rect.fromLTWH(0, y + 58, pageWidth - 15, 20),
      format: rtlFormat,
    );

    graphics.drawString(
      'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان | تاريخ الإصدار: ${_formatDate(DateTime.now())}',
      smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      bounds: Rect.fromLTWH(0, y + 76, pageWidth - 15, 15),
      format: rtlFormat,
    );

    y += 105;

    // ═══════════════════════════════════════
    // الجدول الزمني
    // ═══════════════════════════════════════
    if (sortedTasks.isNotEmpty) {
      // عنوان القسم
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 22),
      );
      graphics.drawString(
        '  الجدول الزمني',
        boldFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(5, y + 2, pageWidth, 20),
        format: rtlFormat,
      );
      y += 30;

      // إنشاء الجدول
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 3);
      grid.style = PdfGridStyle(
        font: regularFont,
        cellPadding: PdfPaddings(left: 5, right: 5, top: 3, bottom: 3),
      );

      // رأس الجدول
      final PdfGridRow header = grid.headers.add(1)[0];
      header.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(4, 120, 87)),
        textBrush: PdfBrushes.white,
        font: boldFont,
      );
      header.cells[0].value = 'اليوم';
      header.cells[1].value = 'المهمة';
      header.cells[2].value = 'التفاصيل';

      // محتوى الجدول
      for (var task in sortedTasks) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = '${task['day_from_start'] ?? 0}';
        row.cells[1].value = '${task['title'] ?? ''}';
        row.cells[2].value = '${task['description'] ?? ''}';

        row.cells[0].style = PdfGridCellStyle(
          format: centerFormat,
          font: regularFont,
        );
        row.cells[1].style = PdfGridCellStyle(
          format: rtlFormat,
          font: regularFont,
        );
        row.cells[2].style = PdfGridCellStyle(
          format: rtlFormat,
          font: regularFont,
        );
      }

      // رسم الجدول
      final PdfLayoutResult result = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 80),
      )!;
      y = result.bounds.bottom + 15;
    }

    // ═══════════════════════════════════════
    // المشتريات
    // ═══════════════════════════════════════
    if (materials.isNotEmpty) {
      // تحقق من المساحة - لو مش كفاية، أضف صفحة جديدة
      if (y > pageHeight - 200) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      // عنوان القسم
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 22),
      );
      graphics.drawString(
        '  قائمة المشتريات',
        boldFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(5, y + 2, pageWidth, 20),
        format: rtlFormat,
      );
      y += 30;

      // جدول المشتريات
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 4);
      grid.style = PdfGridStyle(
        font: regularFont,
        cellPadding: PdfPaddings(left: 5, right: 5, top: 3, bottom: 3),
      );

      final PdfGridRow header = grid.headers.add(1)[0];
      header.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(4, 120, 87)),
        textBrush: PdfBrushes.white,
        font: boldFont,
      );
      header.cells[0].value = 'المادة';
      header.cells[1].value = 'الكمية';
      header.cells[2].value = 'الوحدة';
      header.cells[3].value = 'التكلفة';

      for (var m in materials) {
        final qty = (m['quantity_per_unit'] as num? ?? 0) * areaMultiplier;
        final price = m['price_per_unit'] as num? ?? 0;
        final cost = qty * price;

        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = '${m['name'] ?? ''}';
        row.cells[1].value = qty.toStringAsFixed(2);
        row.cells[2].value = '${m['unit'] ?? ''}';
        row.cells[3].value = '${cost.toStringAsFixed(0)} ج.م';

        row.cells[0].style = PdfGridCellStyle(format: rtlFormat);
        row.cells[1].style = PdfGridCellStyle(format: centerFormat);
        row.cells[2].style = PdfGridCellStyle(format: centerFormat);
        row.cells[3].style = PdfGridCellStyle(format: centerFormat);
      }

      // صف الإجمالي
      final PdfGridRow totalRow = grid.rows.add();
      totalRow.style = PdfGridRowStyle(
        backgroundBrush: PdfSolidBrush(PdfColor(236, 253, 245)),
        font: boldFont,
      );
      totalRow.cells[0].value = 'الإجمالي';
      totalRow.cells[1].value = '';
      totalRow.cells[2].value = '';
      totalRow.cells[3].value =
          '${totalMaterialsCost.toStringAsFixed(0)} ج.م';

      totalRow.cells[0].style = PdfGridCellStyle(
        format: centerFormat,
        font: boldFont,
      );
      totalRow.cells[3].style = PdfGridCellStyle(
        format: centerFormat,
        font: boldFont,
      );

      final PdfLayoutResult result = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 80),
      )!;
      y = result.bounds.bottom + 15;
    }

    // ═══════════════════════════════════════
    // التحليل المالي
    // ═══════════════════════════════════════
    if (expectedYield > 0 || expectedPrice > 0) {
      if (y > pageHeight - 150) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 22),
      );
      graphics.drawString(
        '  التحليل المالي',
        boldFont,
        brush: PdfBrushes.white,
        bounds: Rect.fromLTWH(5, y + 2, pageWidth, 20),
        format: rtlFormat,
      );
      y += 30;

      // الجدول المالي
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 2);
      grid.style = PdfGridStyle(
        font: regularFont,
        cellPadding: PdfPaddings(left: 8, right: 8, top: 5, bottom: 5),
      );

      final items = [
        ['الإنتاج المتوقع', '${expectedYield.toStringAsFixed(2)} ${financial['yield_unit'] ?? 'طن'}'],
        ['الإيراد المتوقع', '${totalRevenue.toStringAsFixed(0)} ج.م'],
        ['إجمالي التكاليف', '${totalMaterialsCost.toStringAsFixed(0)} ج.م'],
        ['صافي الربح', '${netProfit.toStringAsFixed(0)} ج.م'],
        ['نسبة العائد (ROI)', '${roi.toStringAsFixed(1)}%'],
      ];

      for (var item in items) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = item[0];
        row.cells[1].value = item[1];

        row.cells[0].style = PdfGridCellStyle(
          format: rtlFormat,
          font: boldFont,
        );
        row.cells[1].style = PdfGridCellStyle(
          format: rtlFormat,
          font: boldFont,
        );
      }

      final PdfLayoutResult result = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 80),
      )!;
      y = result.bounds.bottom + 20;
    }

    // ═══════════════════════════════════════
    // التنبيه الاسترشادي
    // ═══════════════════════════════════════
    if (y > pageHeight - 100) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 20;
    }

    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 243, 205)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 45),
    );

    graphics.drawString(
      'البرنامج استرشادي - يجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي',
      boldFont,
      brush: PdfSolidBrush(PdfColor(133, 100, 4)),
      bounds: Rect.fromLTWH(10, y + 12, pageWidth - 20, 25),
      format: centerFormat,
    );

    y += 60;

    // ═══════════════════════════════════════
    // الفوتر
    // ═══════════════════════════════════════
    graphics.drawString(
      'تطبيق نباتي - مستشارك الزراعي الذكي',
      boldFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      format: centerFormat,
    );

    graphics.drawString(
      'إشراف: علي الدهشوري - للتواصل: 01284172047',
      smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      bounds: Rect.fromLTWH(0, y + 22, pageWidth, 15),
      format: centerFormat,
    );

    graphics.drawString(
      '© 2025 نباتي - جميع الحقوق محفوظة',
      smallFont,
      brush: PdfSolidBrush(PdfColor(150, 150, 150)),
      bounds: Rect.fromLTWH(0, y + 40, pageWidth, 15),
      format: centerFormat,
    );

    // ═══════════════════════════════════════
    // حفظ ومشاركة
    // ═══════════════════════════════════════
    final List<int> bytes = await document.save();
    document.dispose();

    // حفظ الملف
    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/nabati_${programTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    // مشاركة الملف
    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'برنامج $programTitle',
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
