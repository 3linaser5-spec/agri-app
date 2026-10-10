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
      11,
    );
    final boldFont = PdfTrueTypeFont(
      boldData.buffer.asUint8List(),
      12,
    );
    final titleFont = PdfTrueTypeFont(
      boldData.buffer.asUint8List(),
      16,
    );
    final smallFont = PdfTrueTypeFont(
      regularData.buffer.asUint8List(),
      8,
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

    // ✅ RTL Format
    final PdfStringFormat rtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.right,
      textDirection: PdfTextDirection.rightToLeft,
    );
    final PdfStringFormat centerRtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.center,
      textDirection: PdfTextDirection.rightToLeft,
    );
    final PdfStringFormat leftRtlFormat = PdfStringFormat(
      alignment: PdfTextAlignment.left,
      textDirection: PdfTextDirection.rightToLeft,
    );

    // ✅ Layout Format للـ TextElement (بيسمح بتقسيم الصفحات)
    final PdfLayoutFormat layoutFormat = PdfLayoutFormat(
      layoutType: PdfLayoutType.paginate,
      breakType: PdfLayoutBreakType.fitPage,
    );

    // ═══════════════════════════════════════
    // إنشاء الصفحة الأولى
    // ═══════════════════════════════════════
    PdfPage page = document.pages.add();
    PdfGraphics graphics = page.graphics;

    final double pageWidth = page.getClientSize().width;
    final double pageHeight = page.getClientSize().height;
    double y = 0;

    // ═══════════════════════════════════════
    // Header — شعار نباتي (خلفية خضراء)
    // ═══════════════════════════════════════
    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      bounds: Rect.fromLTWH(0, 0, pageWidth, 50),
    );

    // "نباتي"
    final PdfTextElement titleElement = PdfTextElement(
      text: 'نباتي',
      font: titleFont,
      brush: PdfBrushes.white,
      format: rtlFormat,
    );
    titleElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 5, pageWidth - 10, 25),
    );

    // "مستشارك الزراعي الذكي"
    final PdfTextElement subtitleElement = PdfTextElement(
      text: 'مستشارك الزراعي الذكي',
      font: smallFont,
      brush: PdfBrushes.white,
      format: rtlFormat,
    );
    subtitleElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, 30, pageWidth - 10, 15),
    );

    y = 60;

    // ═══════════════════════════════════════
    // عنوان البرنامج
    // ═══════════════════════════════════════
    final PdfTextElement programTitleElement = PdfTextElement(
      text: 'برنامج $programTitle $programEmoji',
      font: titleFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      format: rtlFormat,
    );
    programTitleElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth - 10, 25),
    );
    y += 28;

    final PdfTextElement govElement = PdfTextElement(
      text: 'المحافظة: $governorate',
      font: regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      format: rtlFormat,
    );
    govElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth - 10, 18),
    );
    y += 18;

    final PdfTextElement sectionElement = PdfTextElement(
      text: 'القسم: $sectionName',
      font: regularFont,
      brush: PdfSolidBrush(PdfColor(0, 0, 0)),
      format: rtlFormat,
    );
    sectionElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth - 10, 18),
    );
    y += 18;

    final PdfTextElement areaElement = PdfTextElement(
      text: 'المساحة: ${areaMultiplier.toStringAsFixed(2)} فدان | تاريخ: ${_formatDate(DateTime.now())}',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      format: rtlFormat,
    );
    areaElement.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth - 10, 15),
    );
    y += 25;

    // ═══════════════════════════════════════
    // الجدول الزمني — عنوان + جدول
    // ═══════════════════════════════════════
    if (sortedTasks.isNotEmpty) {
      // عنوان القسم
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      final PdfTextElement tasksTitleElement = PdfTextElement(
        text: 'الجدول الزمني',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      );
      tasksTitleElement.draw(
        page: page,
        bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15),
      );
      y += 25;

      // جدول المهام
      final PdfGrid taskGrid = _buildTaskGrid(
        sortedTasks,
        regularFont,
        boldFont,
        rtlFormat,
        centerRtlFormat,
      );
      final PdfLayoutResult result = taskGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      // ✅ تحديث الصفحة والموقع بعد الرسم
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // ═══════════════════════════════════════
    // قائمة المشتريات
    // ═══════════════════════════════════════
    if (materials.isNotEmpty) {
      // تحقق من المساحة
      if (y > pageHeight - 150) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      // عنوان القسم
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      final PdfTextElement materialsTitleElement = PdfTextElement(
        text: 'قائمة المشتريات',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      );
      materialsTitleElement.draw(
        page: page,
        bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15),
      );
      y += 25;

      // جدول المشتريات
      final PdfGrid materialGrid = _buildMaterialGrid(
        materials,
        areaMultiplier,
        totalMaterialsCost,
        regularFont,
        boldFont,
        rtlFormat,
        centerRtlFormat,
      );
      final PdfLayoutResult result = materialGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // ═══════════════════════════════════════
    // التحليل المالي
    // ═══════════════════════════════════════
    if (expectedYield > 0 || expectedPrice > 0) {
      if (y > pageHeight - 180) {
        page = document.pages.add();
        graphics = page.graphics;
        y = 20;
      }

      // عنوان القسم
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(4, 120, 87)),
        bounds: Rect.fromLTWH(0, y, pageWidth, 20),
      );
      final PdfTextElement financialTitleElement = PdfTextElement(
        text: 'التحليل المالي',
        font: boldFont,
        brush: PdfBrushes.white,
        format: rtlFormat,
      );
      financialTitleElement.draw(
        page: page,
        bounds: Rect.fromLTWH(5, y + 3, pageWidth - 10, 15),
      );
      y += 25;

      // جدول التحليل المالي
      final PdfGrid financialGrid = _buildFinancialGrid(
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
      final PdfLayoutResult result = financialGrid.draw(
        page: page,
        bounds: Rect.fromLTWH(0, y, pageWidth, pageHeight - y - 30),
      )!;
      page = result.page;
      graphics = page.graphics;
      y = result.bounds.bottom + 15;
    }

    // ═══════════════════════════════════════
    // التنبيه الاسترشادي
    // ═══════════════════════════════════════
    if (y > pageHeight - 80) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 20;
    }

    graphics.drawRectangle(
      brush: PdfSolidBrush(PdfColor(255, 243, 205)),
      bounds: Rect.fromLTWH(0, y, pageWidth, 35),
    );

    final PdfTextElement warningElement = PdfTextElement(
      text: 'البرنامج استرشادي - يجب مراجعة المهندس الزراعي المختص قبل التطبيق الفعلي',
      font: boldFont,
      brush: PdfSolidBrush(PdfColor(133, 100, 4)),
      format: centerRtlFormat,
    );
    warningElement.draw(
      page: page,
      bounds: Rect.fromLTWH(5, y + 8, pageWidth - 10, 20),
    );
    y += 45;

    // ═══════════════════════════════════════
    // الفوتر
    // ═══════════════════════════════════════
    if (y > pageHeight - 80) {
      page = document.pages.add();
      graphics = page.graphics;
      y = 20;
    }

    final PdfTextElement footer1Element = PdfTextElement(
      text: 'تطبيق نباتي - مستشارك الزراعي الذكي',
      font: boldFont,
      brush: PdfSolidBrush(PdfColor(4, 120, 87)),
      format: centerRtlFormat,
    );
    footer1Element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth, 18),
    );
    y += 20;

    final PdfTextElement footer2Element = PdfTextElement(
      text: 'إشراف: علي الدهشوري - للتواصل: 01284172047',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      format: centerRtlFormat,
    );
    footer2Element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth, 15),
    );
    y += 18;

    final PdfTextElement footer3Element = PdfTextElement(
      text: '© 2025 نباتي - جميع الحقوق محفوظة',
      font: smallFont,
      brush: PdfSolidBrush(PdfColor(150, 150, 150)),
      format: centerRtlFormat,
    );
    footer3Element.draw(
      page: page,
      bounds: Rect.fromLTWH(0, y, pageWidth, 15),
    );

    // ═══════════════════════════════════════
    // حفظ ومشاركة
    // ═══════════════════════════════════════
    final List<int> bytes = await document.save();
    document.dispose();

    final dir = await getTemporaryDirectory();
    final filePath =
        '${dir.path}/nabati_${programTitle}_${DateTime.now().millisecondsSinceEpoch}.pdf';
    final file = File(filePath);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles(
      [XFile(filePath)],
      subject: 'برنامج $programTitle',
    );
  }

  // ═══════════════════════════════════════
  // Helper: جدول المهام
  // ═══════════════════════════════════════
  static PdfGrid _buildTaskGrid(
    List<Map<String, dynamic>> tasks,
    PdfTrueTypeFont regularFont,
    PdfTrueTypeFont boldFont,
    PdfStringFormat rtlFormat,
    PdfStringFormat centerRtlFormat,
  ) {
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 3);

    // ✅ عرض الأعمدة
    grid.columns[0].width = 40;
    grid.columns[1].width = 150;
    grid.columns[2].width = 300;

    grid.style = PdfGridStyle(
      font: regularFont,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );

    // ✅ Header مع RTL
    final PdfGridRow header = grid.headers.add(1)[0];
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

    // ✅ محتوى الجدول
    for (var task in tasks) {
      final PdfGridRow row = grid.rows.add();
      row.cells[0].value = '${task['day_from_start'] ?? 0}';
      row.cells[1].value = '${task['title'] ?? ''}';
      row.cells[2].value = '${task['description'] ?? ''}';

      row.cells[0].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[1].style = PdfGridCellStyle(format: rtlFormat);
      row.cells[2].style = PdfGridCellStyle(format: rtlFormat);
    }

    // ✅ Allow row to break across pages
    grid.style.allowRowBreakAcrossPages = true;

    return grid;
  }

  // ═══════════════════════════════════════
  // Helper: جدول المشتريات
  // ═══════════════════════════════════════
  static PdfGrid _buildMaterialGrid(
    List<Map<String, dynamic>> materials,
    double areaMultiplier,
    double totalCost,
    PdfTrueTypeFont regularFont,
    PdfTrueTypeFont boldFont,
    PdfStringFormat rtlFormat,
    PdfStringFormat centerRtlFormat,
  ) {
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 4);

    // ✅ عرض الأعمدة
    grid.columns[0].width = 200;
    grid.columns[1].width = 80;
    grid.columns[2].width = 70;
    grid.columns[3].width = 100;

    grid.style = PdfGridStyle(
      font: regularFont,
      cellPadding: PdfPaddings(left: 4, right: 4, top: 3, bottom: 3),
    );

    // Header
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

    header.cells[0].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[1].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[2].style = PdfGridCellStyle(format: centerRtlFormat);
    header.cells[3].style = PdfGridCellStyle(format: centerRtlFormat);

    // محتوى
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
      row.cells[1].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[2].style = PdfGridCellStyle(format: centerRtlFormat);
      row.cells[3].style = PdfGridCellStyle(format: centerRtlFormat);
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
    totalRow.cells[3].value = '${totalCost.toStringAsFixed(0)} ج.م';

    totalRow.cells[0].style = PdfGridCellStyle(
      format: centerRtlFormat,
      font: boldFont,
    );
    totalRow.cells[3].style = PdfGridCellStyle(
      format: centerRtlFormat,
      font: boldFont,
    );

    grid.style.allowRowBreakAcrossPages = true;

    return grid;
  }

  // ═══════════════════════════════════════
  // Helper: جدول التحليل المالي
  // ═══════════════════════════════════════
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
    final PdfGrid grid = PdfGrid();
    grid.columns.add(count: 2);

    grid.columns[0].width = 200;
    grid.columns[1].width = 250;

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

    return grid;
  }

  static String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
