import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../services/crop_log_service.dart';
import '../../services/farm_report_service.dart';
import '../../services/farm_share_service.dart';

/// لوحة التكاليف والأرباح: إجمالي الموسم، ولكل محصول وقطعة، وأفضل المواسم.
class FarmProfitScreen extends StatelessWidget {
  final List<CropSeason> seasons;
  final List<FarmPlot> plots;

  const FarmProfitScreen({
    super.key,
    required this.seasons,
    this.plots = const [],
  });

  static const Color _green = Color(0xFF047857);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = CropProfitSummary.fromSeasons(seasons);
    final byCrop = CropLogService.summaryByCrop(seasons);
    final best = CropLogService.bestSeason(seasons);
    final sortedCrops = byCrop.entries.toList()
      ..sort((a, b) => b.value.netProfit.compareTo(a.value.netProfit));
    final maxProfit = sortedCrops.isEmpty
        ? 1.0
        : sortedCrops
            .map((entry) => entry.value.netProfit.abs())
            .reduce((a, b) => a > b ? a : b)
            .clamp(1.0, double.infinity);

    return Scaffold(
      appBar: AppBar(
        title: const Text('التكاليف والأرباح',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'مشاركة PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: seasons.isEmpty
                ? null
                : () => FarmShareService.shareCropPdf(
                      summary: summary,
                      seasons: seasons,
                    ),
          ),
          IconButton(
            tooltip: 'مشاركة الملخص',
            icon: const Icon(Icons.share),
            onPressed: seasons.isEmpty
                ? null
                : () => FarmShareService.shareText(
                      FarmReportService.cropSummaryText(summary),
                      subject: 'ملخص أرباح الموسم',
                    ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: seasons.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.pie_chart_outline,
                          size: 80, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text(
                        'لا توجد بيانات أرباح بعد',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'سجّل مواسم المحاصيل ومصروفاتها لتظهر لك التكلفة والربح.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _totals(summary),
                  const SizedBox(height: 16),
                  _sectionTitle('الربح حسب المحصول'),
                  const SizedBox(height: 8),
                  ...sortedCrops.map(
                    (entry) => _cropBar(
                      entry.key,
                      entry.value,
                      maxProfit,
                      isDark,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (plots.isNotEmpty) ...[
                    _sectionTitle('المساحات المسجلة'),
                    const SizedBox(height: 8),
                    _plotsBreakdown(),
                    const SizedBox(height: 16),
                  ],
                  if (best != null) ...[
                    _sectionTitle('أفضل موسم'),
                    const SizedBox(height: 8),
                    _bestSeasonCard(best, isDark),
                    const SizedBox(height: 16),
                  ],
                  _costTable(sortedCrops, isDark),
                ],
              ),
      ),
    );
  }

  Widget _totals(CropProfitSummary summary) {
    final profitColor = summary.netProfit >= 0 ? _green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: profitColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: profitColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _stat('الإيراد', summary.revenue, Colors.blue),
              _stat('المصروفات', summary.expenses, Colors.orange),
              _stat('صافي الربح', summary.netProfit, profitColor),
            ],
          ),
          const Divider(height: 24),
          Row(
            children: [
              _stat('المساحة', summary.areaFeddan, Colors.teal, unit: 'فدان'),
              _stat('الإنتاج', summary.yieldKg, Colors.brown, unit: 'كجم'),
              _stat('ربح/فدان', summary.profitPerFeddan, _green, unit: 'ج.م'),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: summary.marginRatio.clamp(0.0, 1.0),
              minHeight: 8,
              color: profitColor,
              backgroundColor: Colors.grey.withValues(alpha: 0.2),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'هامش الربح ${(summary.marginRatio * 100).toStringAsFixed(1)}%',
            style: TextStyle(fontSize: 11, color: profitColor),
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, double value, Color color, {String unit = 'ج.م'}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            _format(value),
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '$label ($unit)',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );

  Widget _cropBar(
    String crop,
    CropProfitSummary summary,
    double maxProfit,
    bool isDark,
  ) {
    final positive = summary.netProfit >= 0;
    final ratio = (summary.netProfit.abs() / maxProfit).clamp(0.03, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(crop,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Text(
                '${summary.netProfit.toStringAsFixed(0)} ج.م',
                style: TextStyle(
                  color: positive ? _green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: positive ? _green : Colors.red,
              backgroundColor: Colors.grey.withValues(alpha: 0.15),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${summary.seasons} موسم · ${summary.areaFeddan.toStringAsFixed(2)} فدان '
            '· ${summary.profitPerFeddan.toStringAsFixed(0)} ج.م/فدان',
            style: const TextStyle(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _plotsBreakdown() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final plot in plots)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: _green.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${plot.name}: ${plot.areaFeddan.toStringAsFixed(2)} فدان',
              style: const TextStyle(fontSize: 11, color: _green),
            ),
          ),
      ],
    );
  }

  Widget _bestSeasonCard(CropSeason season, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Text('🏆', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${season.crop}${season.variety.isEmpty ? '' : ' · ${season.variety}'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  'ربح ${season.netProfit.toStringAsFixed(0)} ج.م · '
                  '${season.safeAreaFeddan.toStringAsFixed(2)} فدان',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _costTable(List<MapEntry<String, CropProfitSummary>> rows, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              Expanded(
                  flex: 2,
                  child: Text('المحصول',
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('إيراد',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('تكلفة',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(
                  child: Text('ربح',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
          const Divider(),
          ...rows.map(
            (row) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(flex: 2, child: Text(row.key, style: const TextStyle(fontSize: 11))),
                  Expanded(
                      child: Text(row.value.revenue.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11))),
                  Expanded(
                      child: Text(row.value.expenses.toStringAsFixed(0),
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 11))),
                  Expanded(
                      child: Text(
                    row.value.netProfit.toStringAsFixed(0),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: row.value.netProfit >= 0 ? _green : Colors.red,
                    ),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _format(double value) {
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}k';
    }
    return value.toStringAsFixed(0);
  }
}
