import 'package:material_ui/material_ui.dart';

import '../../models/farm_workspace_models.dart';
import '../../services/farm_site_service.dart';

/// إدارة أكثر من مزرعة/قطعة، واختيار القطعة النشطة بسرعة.
class FarmSitesScreen extends StatefulWidget {
  const FarmSitesScreen({super.key});

  @override
  State<FarmSitesScreen> createState() => _FarmSitesScreenState();
}

class _FarmSitesScreenState extends State<FarmSitesScreen> {
  static const Color _green = Color(0xFF047857);

  List<FarmSite> _sites = const [];
  List<FarmPlot> _plots = const [];
  String? _activePlotId;
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
      final sites = await FarmSiteService.loadSites();
      final plots = await FarmSiteService.loadPlots();
      final active = await FarmSiteService.activePlotId();
      if (!mounted) return;
      setState(() {
        _sites = sites;
        _plots = plots;
        _activePlotId = active;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل المزارع. تحقق من الاتصال ثم أعد المحاولة.';
        _loading = false;
      });
    }
  }

  Future<void> _addSite() async {
    final draft = await _showSiteDialog();
    if (draft == null) return;
    await FarmSiteService.addSite(
      name: draft.name,
      governorate: draft.governorate,
      notes: draft.notes,
    );
    await _load();
  }

  Future<void> _addPlot(FarmSite site) async {
    final draft = await _showPlotDialog();
    if (draft == null) return;
    final plot = await FarmSiteService.addPlot(
      siteId: site.id,
      name: draft.name,
      crop: draft.crop,
      areaFeddan: draft.area,
      irrigationMethod: draft.method,
    );
    if (plot != null) await FarmSiteService.setActivePlotId(plot.id);
    await _load();
  }

  Future<void> _selectPlot(FarmPlot plot) async {
    await FarmSiteService.setActivePlotId(plot.id);
    if (!mounted) return;
    setState(() => _activePlotId = plot.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('القطعة النشطة الآن: ${plot.name}')),
    );
  }

  Future<void> _deletePlot(FarmPlot plot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القطعة'),
        content: Text('حذف «${plot.name}»؟ المهام والمواسم المرتبطة بها تبقى في السجل.'),
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
    await FarmSiteService.deletePlot(plot);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مزارعي وقطع الأرض',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addSite,
        backgroundColor: _green,
        icon: const Icon(Icons.add_location_alt),
        label: const Text('مزرعة جديدة'),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline,
                              color: Colors.red, size: 60),
                          const SizedBox(height: 12),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                          ),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                      children: [
                        _header(),
                        if (_sites.isEmpty) _emptyState(),
                        for (final site in _sites)
                          _siteCard(site, isDark),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _header() {
    final active = _plots.where((plot) => plot.id == _activePlotId).toList();
    final area = _plots.fold<double>(0, (sum, plot) => sum + plot.areaFeddan);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF047857), Color(0xFF0D9488)],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${_sites.length} مزرعة · ${_plots.length} قطعة · ${area.toStringAsFixed(2)} فدان',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            active.isEmpty
                ? 'اختر قطعة لتكون النشطة في المهام والمحاصيل.'
                : 'القطعة النشطة: ${active.first.name}',
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.map_outlined, size: 90, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('أضف مزرعتك الأولى',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            const SizedBox(height: 6),
            const Text(
              'بعد إضافة المزرعة أضف قطع الأرض، وسيتم ربط المهام والمحاصيل بها.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _siteCard(FarmSite site, bool isDark) {
    final plots = _plots.where((plot) => plot.siteId == site.id).toList();
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.agriculture, color: _green),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(site.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    if (site.governorate.isNotEmpty)
                      Text(site.governorate,
                          style: const TextStyle(
                              fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              TextButton.icon(
                onPressed: () => _addPlot(site),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('قطعة'),
              ),
            ],
          ),
          if (plots.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text('لا توجد قطع بعد.',
                  style: TextStyle(fontSize: 12, color: Colors.grey)),
            )
          else
            ...plots.map((plot) => _plotTile(plot)),
        ],
      ),
    );
  }

  Widget _plotTile(FarmPlot plot) {
    final selected = plot.id == _activePlotId;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: () => _selectPlot(plot),
      onLongPress: () => _deletePlot(plot),
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? _green : Colors.grey,
      ),
      title: Text(plot.name,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: selected ? _green : null,
          )),
      subtitle: Text(
        '${plot.areaFeddan.toStringAsFixed(2)} فدان'
        '${plot.crop.isEmpty ? '' : ' · ${plot.crop}'}'
        '${plot.irrigationMethod.isEmpty ? '' : ' · ${plot.irrigationMethod}'}',
        style: const TextStyle(fontSize: 11),
      ),
    );
  }

  Future<_SiteDraft?> _showSiteDialog() {
    final name = TextEditingController();
    final governorate = TextEditingController();
    final notes = TextEditingController();
    return showDialog<_SiteDraft>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('مزرعة جديدة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'اسم المزرعة',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: governorate,
                  decoration: const InputDecoration(
                    labelText: 'المحافظة / المركز',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: notes,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () {
                final value = name.text.trim();
                if (value.isEmpty) return;
                Navigator.pop(
                  context,
                  _SiteDraft(
                    name: value,
                    governorate: governorate.text.trim(),
                    notes: notes.text.trim(),
                  ),
                );
              },
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PlotDraft?> _showPlotDialog() {
    final name = TextEditingController();
    final crop = TextEditingController();
    final area = TextEditingController(text: '1');
    String method = 'تنقيط';
    return showDialog<_PlotDraft>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('قطعة أرض جديدة'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: name,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'اسم القطعة',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: crop,
                    decoration: const InputDecoration(
                      labelText: 'المحصول الحالي',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: area,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'المساحة بالفدان',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: method,
                    decoration: const InputDecoration(
                      labelText: 'طريقة الري',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'تنقيط', child: Text('تنقيط')),
                      DropdownMenuItem(value: 'رش', child: Text('رش')),
                      DropdownMenuItem(value: 'سطحي', child: Text('سطحي')),
                      DropdownMenuItem(value: 'محوري', child: Text('محوري')),
                    ],
                    onChanged: (value) =>
                        setState(() => method = value ?? 'تنقيط'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('إلغاء'),
              ),
              FilledButton(
                onPressed: () {
                  final value = name.text.trim();
                  if (value.isEmpty) return;
                  Navigator.pop(
                    context,
                    _PlotDraft(
                      name: value,
                      crop: crop.text.trim(),
                      area: double.tryParse(area.text.trim()) ?? 0,
                      method: method,
                    ),
                  );
                },
                child: const Text('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteDraft {
  final String name;
  final String governorate;
  final String notes;
  const _SiteDraft({
    required this.name,
    required this.governorate,
    required this.notes,
  });
}

class _PlotDraft {
  final String name;
  final String crop;
  final double area;
  final String method;
  const _PlotDraft({
    required this.name,
    required this.crop,
    required this.area,
    required this.method,
  });
}
