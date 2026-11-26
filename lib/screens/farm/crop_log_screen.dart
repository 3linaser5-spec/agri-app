import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../services/crop_log_service.dart';
import '../../services/farm_report_service.dart';
import '../../services/farm_share_service.dart';
import '../../services/farm_site_service.dart';
import 'farm_profit_screen.dart';

/// سجل المحاصيل: المواسم، الإنتاج المتوقع/الفعلي، المصروفات، والربح لكل موسم.
class CropLogScreen extends StatefulWidget {
  const CropLogScreen({super.key});

  @override
  State<CropLogScreen> createState() => _CropLogScreenState();
}

class _CropLogScreenState extends State<CropLogScreen> {
  static const Color _green = Color(0xFF047857);

  List<CropSeason> _seasons = const [];
  List<FarmPlot> _plots = const [];
  String? _plotFilter;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final seasons = await CropLogService.loadSeasons();
      final plots = await FarmSiteService.loadPlots();
      if (!mounted) return;
      setState(() {
        _seasons = seasons;
        _plots = plots;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل سجل المحاصيل.';
        _loading = false;
      });
    }
  }

  List<CropSeason> get _visible =>
      CropLogService.filterByPlot(_seasons, _plotFilter);

  Future<void> _addSeason() async {
    final draft = await showModalBottomSheet<_SeasonDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeasonEditorSheet(plots: _plots),
    );
    if (draft == null) return;
    final season = await CropLogService.addSeason(CropSeason(
      id: '',
      ownerId: '',
      plotId: draft.plotId,
      crop: draft.crop,
      variety: draft.variety,
      areaFeddan: draft.area,
      plantingDate: draft.plantingDate,
      harvestDate: draft.harvestDate,
      expectedYieldKg: draft.expectedYield,
      pricePerKg: draft.pricePerKg,
      expenses: draft.expenses,
    ));
    if (season == null || !mounted) return;
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('تم حفظ موسم المحصول.')),
    );
  }

  Future<void> _editSeason(CropSeason season) async {
    final draft = await showModalBottomSheet<_SeasonDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SeasonEditorSheet(plots: _plots, initial: season),
    );
    if (draft == null) return;
    await CropLogService.updateSeason(season.copyWith(
      crop: draft.crop,
      variety: draft.variety,
      areaFeddan: draft.area,
      harvestDate: draft.harvestDate,
      expectedYieldKg: draft.expectedYield,
      actualYieldKg: draft.actualYield,
      pricePerKg: draft.pricePerKg,
      expenses: draft.expenses,
    ));
    await _load();
  }

  Future<void> _delete(CropSeason season) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الموسم'),
        content: Text('حذف موسم «${season.crop}»؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await CropLogService.deleteSeason(season);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final summary = CropProfitSummary.fromSeasons(_visible);
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل المحاصيل', style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'لوحة الأرباح',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => FarmProfitScreen(
                  seasons: _seasons,
                  plots: _plots,
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Excel',
            icon: const Icon(Icons.table_view),
            onPressed: _visible.isEmpty
                ? null
                : () => FarmShareService.shareCsv(
                      fileName: 'سجل_المحاصيل',
                      content: FarmReportService.csvForCropSeasons(_visible),
                      subject: 'سجل المحاصيل',
                    ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSeason,
        backgroundColor: _green,
        icon: const Icon(Icons.add),
        label: const Text('موسم جديد'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 60),
                        const SizedBox(height: 12),
                        Text(_error!),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('إعادة المحاولة'),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _summaryCard(summary),
                        if (_plots.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          _filterChips(),
                        ],
                        const SizedBox(height: 12),
                        if (_visible.isEmpty)
                          _emptyState()
                        else
                          ..._visible.map(
                            (season) => _seasonCard(season, isDark),
                          ),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _summaryCard(CropProfitSummary summary) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: summary.netProfit >= 0
              ? const [Color(0xFF047857), Color(0xFF10B981)]
              : const [Color(0xFFB91C1C), Color(0xFFF97316)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('صافي الربح الحالي',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            '${summary.netProfit.toStringAsFixed(0)} ج.م',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'إيراد ${summary.revenue.toStringAsFixed(0)} · '
            'مصروف ${summary.expenses.toStringAsFixed(0)} · '
            '${summary.seasons} موسم · ${summary.profitPerFeddan.toStringAsFixed(0)} ج.م/فدان',
            style: const TextStyle(color: Colors.white70, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _filterChips() {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          ChoiceChip(
            label: const Text('كل القطع'),
            selected: _plotFilter == null,
            onSelected: (_) => setState(() => _plotFilter = null),
          ),
          const SizedBox(width: 8),
          for (final plot in _plots) ...[
            ChoiceChip(
              label: Text(plot.name),
              selected: _plotFilter == plot.id,
              onSelected: (_) => setState(() => _plotFilter = plot.id),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.grass, size: 90, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد مواسم مسجلة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'سجّل أول موسم لتعرف تكلفة الفدان وربحك الحقيقي.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _seasonCard(CropSeason season, bool isDark) {
    final plotName = _plots
        .where((plot) => plot.id == season.plotId)
        .map((plot) => plot.name)
        .toList();
    final profitColor = season.netProfit >= 0 ? _green : Colors.red;
    return InkWell(
      onTap: () => _editSeason(season),
      onLongPress: () => _delete(season),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: _green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('🌾', style: TextStyle(fontSize: 24)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${season.crop}${season.variety.isEmpty ? '' : ' · ${season.variety}'}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${season.safeAreaFeddan.toStringAsFixed(2)} فدان'
                        '${plotName.isEmpty ? '' : ' · ${plotName.first}'}'
                        ' · زراعة ${_date(season.plantingDate)}',
                        style:
                            const TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${season.netProfit.toStringAsFixed(0)} ج.م',
                  style: TextStyle(
                      color: profitColor, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _chip(Icons.scale,
                    '${season.effectiveYieldKg.toStringAsFixed(0)} كجم'),
                const SizedBox(width: 6),
                _chip(Icons.payments,
                    'إيراد ${season.revenue.toStringAsFixed(0)}'),
                const SizedBox(width: 6),
                _chip(Icons.receipt_long,
                    'مصروف ${season.totalExpenses.toStringAsFixed(0)}'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(IconData icon, String label) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
          decoration: BoxDecoration(
            color: _green.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 12, color: _green),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: _green),
                ),
              ),
            ],
          ),
        ),
      );

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

class _SeasonDraft {
  final String crop;
  final String variety;
  final double area;
  final DateTime plantingDate;
  final DateTime? harvestDate;
  final double expectedYield;
  final double? actualYield;
  final double pricePerKg;
  final List<CropExpense> expenses;
  final String? plotId;

  const _SeasonDraft({
    required this.crop,
    required this.variety,
    required this.area,
    required this.plantingDate,
    required this.expectedYield,
    required this.pricePerKg,
    required this.expenses,
    this.harvestDate,
    this.actualYield,
    this.plotId,
  });
}

class _SeasonEditorSheet extends StatefulWidget {
  final List<FarmPlot> plots;
  final CropSeason? initial;
  const _SeasonEditorSheet({required this.plots, this.initial});

  @override
  State<_SeasonEditorSheet> createState() => _SeasonEditorSheetState();
}

class _SeasonEditorSheetState extends State<_SeasonEditorSheet> {
  late final TextEditingController _crop;
  late final TextEditingController _variety;
  late final TextEditingController _area;
  late final TextEditingController _expected;
  late final TextEditingController _actual;
  late final TextEditingController _price;

  late DateTime _plantingDate;
  DateTime? _harvestDate;
  String? _plotId;
  final List<CropExpense> _expenses = [];
  final _expenseLabel = TextEditingController();
  final _expenseAmount = TextEditingController();

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _crop = TextEditingController(text: initial?.crop ?? '');
    _variety = TextEditingController(text: initial?.variety ?? '');
    _area = TextEditingController(
      text: (initial?.areaFeddan ?? 1).toString(),
    );
    _expected = TextEditingController(
      text: initial?.expectedYieldKg == null
          ? ''
          : initial!.expectedYieldKg.toStringAsFixed(0),
    );
    _actual = TextEditingController(
      text: initial?.actualYieldKg?.toStringAsFixed(0) ?? '',
    );
    _price = TextEditingController(
      text: initial?.pricePerKg == null
          ? ''
          : initial!.pricePerKg.toStringAsFixed(0),
    );
    _plantingDate = initial?.plantingDate ?? DateTime.now();
    _harvestDate = initial?.harvestDate;
    _plotId = initial?.plotId;
    if (initial != null) _expenses.addAll(initial.expenses);
  }

  @override
  void dispose() {
    _crop.dispose();
    _variety.dispose();
    _area.dispose();
    _expected.dispose();
    _actual.dispose();
    _price.dispose();
    _expenseLabel.dispose();
    _expenseAmount.dispose();
    super.dispose();
  }

  Future<void> _pickDate({required bool harvest}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: harvest ? (_harvestDate ?? DateTime.now()) : _plantingDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (harvest) {
        _harvestDate = picked;
      } else {
        _plantingDate = picked;
      }
    });
  }

  void _addExpense() {
    final label = _expenseLabel.text.trim();
    final amount = double.tryParse(_expenseAmount.text.trim());
    if (label.isEmpty || amount == null || amount <= 0) return;
    setState(() {
      _expenses.add(CropExpense(
        label: label,
        amount: amount,
        date: DateTime.now(),
      ));
      _expenseLabel.clear();
      _expenseAmount.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final total = _expenses.fold<double>(0, (sum, item) => sum + item.amount);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.initial == null ? 'موسم محصول جديد' : 'تعديل الموسم',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _crop,
                decoration: const InputDecoration(
                  labelText: 'المحصول',
                  hintText: 'طماطم، قمح، برسيم...',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _variety,
                decoration: const InputDecoration(
                  labelText: 'الصنف (اختياري)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _area,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المساحة (فدان)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _price,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'سعر الكيلو (ج.م)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(harvest: false),
                      child: Text(
                        'زراعة: ${_plantingDate.day}/${_plantingDate.month}/${_plantingDate.year}',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _pickDate(harvest: true),
                      child: Text(
                        _harvestDate == null
                            ? 'الحصاد: لم يحدد'
                            : 'حصاد: ${_harvestDate!.day}/${_harvestDate!.month}/${_harvestDate!.year}',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _expected,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الإنتاج المتوقع (كجم)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _actual,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'الإنتاج الفعلي (كجم)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              if (widget.plots.isNotEmpty) ...[
                const SizedBox(height: 10),
                DropdownButtonFormField<String?>(
                  initialValue: _plotId,
                  decoration: const InputDecoration(
                    labelText: 'القطعة',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                        value: null, child: Text('غير محددة')),
                    for (final plot in widget.plots)
                      DropdownMenuItem(value: plot.id, child: Text(plot.name)),
                  ],
                  onChanged: (value) => setState(() => _plotId = value),
                ),
              ],
              const SizedBox(height: 16),
              Text('المصروفات (${total.toStringAsFixed(0)} ج.م)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _expenseLabel,
                      decoration: const InputDecoration(
                        labelText: 'البند',
                        hintText: 'تقاوي، سماد، عمالة...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _expenseAmount,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'المبلغ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _addExpense,
                    icon: const Icon(Icons.add_circle, color: Color(0xFF047857)),
                  ),
                ],
              ),
              ..._expenses.map((expense) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(expense.label),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${expense.amount.toStringAsFixed(0)} ج.م'),
                        IconButton(
                          icon: const Icon(Icons.close, size: 16),
                          onPressed: () =>
                              setState(() => _expenses.remove(expense)),
                        ),
                      ],
                    ),
                  )),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                  ),
                  onPressed: () {
                    final crop = _crop.text.trim();
                    if (crop.isEmpty) return;
                    Navigator.pop(
                      context,
                      _SeasonDraft(
                        crop: crop,
                        variety: _variety.text.trim(),
                        area: double.tryParse(_area.text.trim()) ?? 1,
                        plantingDate: _plantingDate,
                        harvestDate: _harvestDate,
                        expectedYield:
                            double.tryParse(_expected.text.trim()) ?? 0,
                        actualYield:
                            double.tryParse(_actual.text.trim()),
                        pricePerKg:
                            double.tryParse(_price.text.trim()) ?? 0,
                        expenses: List.of(_expenses),
                        plotId: _plotId,
                      ),
                    );
                  },
                  child: const Text('حفظ الموسم'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
