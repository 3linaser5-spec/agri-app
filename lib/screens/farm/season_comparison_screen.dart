import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../services/farm_share_service.dart';
import '../../services/season_comparison_service.dart';

/// مقارنة موسمين جنبًا إلى جنب: الإنتاج والتكلفة والربح لكل فدان، مع ملخص
/// كل سنة وآخر موسمين تلقائيًا.
class SeasonComparisonScreen extends StatefulWidget {
  final List<CropSeason> seasons;

  const SeasonComparisonScreen({super.key, required this.seasons});

  @override
  State<SeasonComparisonScreen> createState() => _SeasonComparisonScreenState();
}

class _SeasonComparisonScreenState extends State<SeasonComparisonScreen> {
  static const Color _green = Color(0xFF047857);
  static const Color _red = Color(0xFFB91C1C);

  CropSeason? _first;
  CropSeason? _second;

  @override
  void initState() {
    super.initState();
    final automatic = SeasonComparisonService.automatic(widget.seasons);
    if (automatic != null) {
      _first = automatic.first;
      _second = automatic.second;
    } else if (widget.seasons.isNotEmpty) {
      _first = widget.seasons.first;
    }
  }

  SeasonComparison? get _comparison {
    final first = _first;
    final second = _second;
    if (first == null || second == null) return null;
    return SeasonComparisonService.compare(first, second);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final comparison = _comparison;
    final yearly = SeasonComparisonService.yearlySummaries(widget.seasons);
    final best = SeasonComparisonService.bestPerCrop(widget.seasons);

    return Scaffold(
      appBar: AppBar(
        title: const Text('مقارنة المواسم',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'مشاركة المقارنة',
            icon: const Icon(Icons.share),
            onPressed: comparison == null
                ? null
                : () => FarmShareService.shareText(
                      SeasonComparisonService.shareText(comparison),
                      subject: 'مقارنة المواسم',
                    ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: widget.seasons.length < 2
            ? _emptyState()
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  _pickers(),
                  const SizedBox(height: 16),
                  if (comparison == null)
                    const Text('اختر موسمين مختلفين للمقارنة.')
                  else ...[
                    _verdictCard(comparison),
                    const SizedBox(height: 12),
                    _metricsTable(comparison, isDark),
                  ],
                  if (yearly.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('الأرباح سنة بسنة'),
                    const SizedBox(height: 8),
                    ...yearly.reversed.map((year) => _yearRow(year, isDark)),
                  ],
                  if (best.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _sectionTitle('أفضل موسم لكل محصول'),
                    const SizedBox(height: 8),
                    ...best.entries.map((entry) => _bestRow(entry.key, entry.value)),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _emptyState() => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare_arrows, size: 80, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'تحتاج موسمين على الأقل',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 6),
              const Text(
                'سجّل موسمين لنفس المحصول (مثلًا صيف 2025 وصيف 2026) '
                'لتظهر لك المقارنة والفرق في الربح.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
      );

  Widget _pickers() {
    return Row(
      children: [
        Expanded(child: _seasonDropdown('الموسم الأول', _first, true)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 6),
          child: Icon(Icons.compare_arrows, color: _green),
        ),
        Expanded(child: _seasonDropdown('الموسم الثاني', _second, false)),
      ],
    );
  }

  Widget _seasonDropdown(String label, CropSeason? value, bool isFirst) {
    final unique = <String, CropSeason>{
      for (final season in widget.seasons) season.id: season,
    }.values.toList(growable: false);
    return DropdownButtonFormField<String>(
      initialValue: value?.id,
      isExpanded: true,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      ),
      items: [
        for (final season in unique)
          DropdownMenuItem(
            value: season.id,
            child: Text(
              SeasonComparisonService.seasonLabel(season),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
      onChanged: (id) {
        if (id == null) return;
        final selected =
            widget.seasons.firstWhere((season) => season.id == id);
        setState(() {
          if (isFirst) {
            _first = selected;
          } else {
            _second = selected;
          }
        });
      },
    );
  }

  Widget _verdictCard(SeasonComparison comparison) {
    final betterSecond = comparison.profitPerFeddanDelta >= 0;
    final color = betterSecond ? _green : _red;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            betterSecond ? Icons.trending_up : Icons.trending_down,
            color: color,
            size: 34,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  comparison.verdict,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: color,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'الفرق في الربح الكلي: '
                  '${comparison.profitDelta.toStringAsFixed(0)} جنيه',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsTable(SeasonComparison comparison, bool isDark) {
    final first = comparison.firstMetrics;
    final second = comparison.secondMetrics;
    final rows = <(String, double, double, String)>[
      ('الربح لكل فدان', first.profitPerFeddan, second.profitPerFeddan, 'جنيه'),
      ('الإنتاج لكل فدان', first.yieldPerFeddan, second.yieldPerFeddan, 'كجم'),
      ('التكلفة لكل فدان', first.costPerFeddan, second.costPerFeddan, 'جنيه'),
      ('هامش الربح', first.marginRatio * 100, second.marginRatio * 100, '٪'),
      ('الإيراد الكلي', first.revenue, second.revenue, 'جنيه'),
      ('إجمالي التكلفة', first.expenses, second.expenses, 'جنيه'),
    ];
    final headerStyle = TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
    );
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(flex: 3, child: Text('البند', style: headerStyle)),
              Expanded(
                flex: 2,
                child: Text('الأول', style: headerStyle, textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text('الثاني', style: headerStyle, textAlign: TextAlign.center),
              ),
              Expanded(
                flex: 2,
                child: Text('الفرق', style: headerStyle, textAlign: TextAlign.center),
              ),
            ],
          ),
          const Divider(height: 16),
          for (final row in rows) _metricRow(row.$1, row.$2, row.$3, row.$4),
        ],
      ),
    );
  }

  Widget _metricRow(String label, double first, double second, String unit) {
    final delta = second - first;
    final improved = label == 'التكلفة لكل فدان' ||
            label == 'إجمالي التكلفة'
        ? delta <= 0
        : delta >= 0;
    final color = delta.abs() < 0.01
        ? Colors.grey
        : (improved ? _green : _red);
    String format(double value) => value.abs() >= 1000
        ? '${(value / 1000).toStringAsFixed(1)}k'
        : value.toStringAsFixed(0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(label, style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(format(first),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(format(second),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12)),
          ),
          Expanded(
            flex: 2,
            child: Text(
              '${delta >= 0 ? '+' : '-'}${format(delta)}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _yearRow(YearlySeasonSummary year, bool isDark) {
    final profit = year.summary.netProfit;
    final color = profit >= 0 ? _green : _red;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: _green.withValues(alpha: 0.12),
            child: Text(
              '${year.year}',
              style: const TextStyle(fontSize: 10, color: _green),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '${year.seasons} موسم · '
              '${year.summary.areaFeddan.toStringAsFixed(1)} فدان',
              style: const TextStyle(fontSize: 12),
            ),
          ),
          Text(
            '${profit >= 0 ? '+' : ''}${profit.toStringAsFixed(0)} جنيه',
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bestRow(String crop, CropSeason season) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          children: [
            const Icon(Icons.emoji_events, color: Color(0xFFF59E0B), size: 18),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '$crop — ${season.plantingDate.year}',
                style: const TextStyle(fontSize: 13),
              ),
            ),
            Text(
              '${season.profitPerFeddan.toStringAsFixed(0)} جنيه/فدان',
              style: const TextStyle(fontSize: 12, color: _green),
            ),
          ],
        ),
      );

  Widget _sectionTitle(String title) => Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
      );
}
