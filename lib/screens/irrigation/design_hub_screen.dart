import 'package:material_ui/material_ui.dart';

import '../../services/design_comparison_service.dart';
import '../../services/irrigation_bom_service.dart';
import '../calculators/irrigation_bom_screen.dart';
import '../../services/design_version_service.dart';
import '../../services/farm_report_service.dart';
import '../../services/farm_share_service.dart';
import '../../services/irrigation_export_service.dart';
import '../../services/irrigation_project_service.dart';

/// مركز التصاميم المحفوظة: تصدير PDF/Excel، مشاركة، مقارنة تصميمين، وأرشيف
/// النسخ.
class DesignHubScreen extends StatefulWidget {
  const DesignHubScreen({super.key});

  @override
  State<DesignHubScreen> createState() => _DesignHubScreenState();
}

class _DesignHubScreenState extends State<DesignHubScreen> {
  static const Color _green = Color(0xFF047857);

  List<SavedIrrigationProject> _designs = const [];
  final Set<String> _selected = {};
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
      final designs = await IrrigationProjectService.list();
      if (!mounted) return;
      setState(() {
        _designs = designs;
        _selected.removeWhere(
          (id) => !designs.any((design) => design.documentId == id),
        );
        _loading = false;
      });
    } on IrrigationProjectException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذر تحميل التصاميم المحفوظة.';
        _loading = false;
      });
    }
  }

  void _toggleSelection(String documentId) {
    setState(() {
      if (_selected.contains(documentId)) {
        _selected.remove(documentId);
      } else {
        if (_selected.length >= 2) _selected.remove(_selected.first);
        _selected.add(documentId);
      }
    });
  }

  Future<void> _exportCsv(SavedIrrigationProject design) async {
    try {
      final bundle = IrrigationExportService.exportProject(design.project);
      await FarmShareService.shareCsv(
        fileName: 'BOQ_${design.name}',
        content: bundle.boqCsv,
        subject: 'قائمة مشتريات ${design.name}',
      );
    } on IrrigationExportValidationException catch (error) {
      _snack('التصميم غير مكتمل: ${error.errors.first}');
    } catch (_) {
      _snack('تعذر تصدير الملف.');
    }
  }

  /// بوليصة مشتريات بكل خامات التصميم المحفوظ.
  void _openBom(SavedIrrigationProject design) {
    final bom = IrrigationBomService.buildFromProject(
      design.project,
      name: design.name,
    );
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => IrrigationBomScreen(bom: bom)),
    );
  }

  Future<void> _shareSummary(SavedIrrigationProject design) async {
    await FarmShareService.shareText(
      FarmReportService.designSummaryText(design.project),
      subject: 'تصميم ري — ${design.name}',
    );
  }

  Future<void> _openVersions(SavedIrrigationProject design) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VersionsSheet(design: design),
    );
  }

  Future<void> _delete(SavedIrrigationProject design) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف التصميم'),
        content: Text('حذف «${design.name}» من حسابك؟'),
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
    try {
      await IrrigationProjectService.delete(design.documentId);
      await _load();
    } on IrrigationProjectException catch (error) {
      _snack(error.message);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  void _openComparison() {
    final picked = _designs
        .where((design) => _selected.contains(design.documentId))
        .toList(growable: false);
    if (picked.length != 2) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DesignComparisonScreen(
          first: picked[0],
          second: picked[1],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('تصاميمي والتقارير',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'تحديث',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: _selected.length == 2
            ? PreferredSize(
                preferredSize: const Size.fromHeight(48),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _green,
                      ),
                      onPressed: _openComparison,
                      icon: const Icon(Icons.compare_arrows),
                      label: const Text('مقارنة التصميمين المحددين'),
                    ),
                  ),
                ),
              )
            : null,
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
                          const Icon(Icons.folder_off_outlined,
                              color: Colors.grey, size: 64),
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
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                      children: [
                        _hint(),
                        if (_designs.isEmpty) _emptyState(),
                        for (final design in _designs)
                          _designCard(design, isDark),
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _hint() => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'من هنا تصدّر تصميمك PDF أو Excel، تشاركه على واتساب، تقارن تصميمين، '
          'أو ترجع لنسخة قديمة. اختر تصميمين للمقارنة.',
          style: TextStyle(fontSize: 11),
        ),
      );

  Widget _emptyState() => Padding(
        padding: const EdgeInsets.symmetric(vertical: 50),
        child: Column(
          children: [
            Icon(Icons.design_services_outlined,
                size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            const Text('لا توجد تصاميم محفوظة',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 6),
            const Text(
              'افتح مصمم الري واحفظ تصميمك، ثم سيظهر هنا للتصدير والمقارنة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );

  Widget _designCard(SavedIrrigationProject design, bool isDark) {
    final selected = _selected.contains(design.documentId);
    final project = design.project;
    final area = project.siteBoundary.declaredArea;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: selected
              ? _green
              : (isDark ? Colors.grey.shade800 : Colors.grey.shade200),
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          ListTile(
            onTap: () => _toggleSelection(design.documentId),
            onLongPress: () => _delete(design),
            leading: Icon(
              selected ? Icons.check_circle : Icons.water_drop_outlined,
              color: _green,
            ),
            title: Text(design.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
              '${project.zones.length} منطقة · '
              '${project.pipes.length} ماسورة · '
              '${area == null ? 'مساحة غير محددة' : '${area.toStringAsFixed(0)} م²'}'
              '${design.updatedAt == null ? '' : ' · آخر تحديث ${_date(design.updatedAt!)}'}',
              style: const TextStyle(fontSize: 11),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                _action(Icons.receipt_long, 'المشتريات', () => _openBom(design)),
                _action(Icons.picture_as_pdf, 'PDF',
                    () => FarmShareService.shareDesignPdf(project)),
                _action(Icons.table_view, 'Excel', () => _exportCsv(design)),
                _action(Icons.share, 'مشاركة', () => _shareSummary(design)),
                _action(Icons.history, 'النسخ', () => _openVersions(design)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            children: [
              Icon(icon, size: 20, color: _green),
              const SizedBox(height: 3),
              Text(label, style: const TextStyle(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }

  String _date(DateTime date) => '${date.day}/${date.month}/${date.year}';
}

/// شاشة مقارنة تصميمين.
class DesignComparisonScreen extends StatefulWidget {
  final SavedIrrigationProject first;
  final SavedIrrigationProject second;

  const DesignComparisonScreen({
    super.key,
    required this.first,
    required this.second,
  });

  @override
  State<DesignComparisonScreen> createState() => _DesignComparisonScreenState();
}

class _DesignComparisonScreenState extends State<DesignComparisonScreen> {
  static const Color _green = Color(0xFF047857);
  DesignCostRates _rates = const DesignCostRates();

  Future<void> _editPipePrice() async {
    final controller =
        TextEditingController(text: _rates.pipeMeterPrice.toStringAsFixed(0));
    final value = await showDialog<double>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('سعر متر الماسورة'),
          content: TextField(
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'جنيه لكل متر',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(
                context,
                double.tryParse(controller.text.trim()),
              ),
              child: const Text('تطبيق'),
            ),
          ],
        ),
      ),
    );
    if (value == null || value <= 0) return;
    setState(() {
      _rates = DesignCostRates(
        pipeMeterPrice: value,
        valvePrice: _rates.valvePrice,
        equipmentPrice: _rates.equipmentPrice,
        plantPrice: _rates.plantPrice,
        pumpPrice: _rates.pumpPrice,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final result = const DesignComparisonService().compare(
      widget.first.project,
      widget.second.project,
      rates: _rates,
    );
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('مقارنة تصميمين',
            style: TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'تعديل سعر المتر',
            icon: const Icon(Icons.tune),
            onPressed: _editPipePrice,
          ),
          IconButton(
            tooltip: 'مشاركة المقارنة',
            icon: const Icon(Icons.share),
            onPressed: () => FarmShareService.shareText(
              _shareText(result),
              subject: 'مقارنة تصميمين',
            ),
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(child: _designHeader(result.a.name, 'أ')),
                const SizedBox(width: 8),
                Expanded(child: _designHeader(result.b.name, 'ب')),
              ],
            ),
            const SizedBox(height: 16),
            ...result.rows.map((row) => _row(row, isDark)),
            const SizedBox(height: 12),
            const Text(
              'التكلفة تقديرية بأسعار افتراضية (ماسورة 60 ج.م/م، محبس 350 ج.م...). '
              'عدّلها من زر الضبط أعلاه لمقارنة أقرب لواقعك.',
              style: TextStyle(fontSize: 10, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _designHeader(String name, String badge) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: _green,
              foregroundColor: Colors.white,
              child: Text(badge),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      );

  Widget _row(ComparisonRow row, bool isDark) {
    final betterColor = _green;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(row.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(
                row.better == 'tie'
                    ? 'متساوي'
                    : row.better == 'a'
                        ? 'أفضل: أ'
                        : 'أفضل: ب',
                style: TextStyle(
                  fontSize: 10,
                  color: row.better == 'tie' ? Colors.grey : betterColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${_num(row.valueA)} ${row.unit}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: row.better == 'a' ? betterColor : null,
                    fontWeight:
                        row.better == 'a' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${_num(row.valueB)} ${row.unit}',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: row.better == 'b' ? betterColor : null,
                    fontWeight:
                        row.better == 'b' ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${row.percentDifference >= 0 ? '+' : ''}'
                  '${row.percentDifference.toStringAsFixed(0)}%',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _num(double value) {
    if (value.abs() >= 1000) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }

  String _shareText(DesignComparisonResult result) {
    final buffer = StringBuffer()
      ..writeln('🌱 مقارنة تصميمين')
      ..writeln('أ: ${result.a.name}')
      ..writeln('ب: ${result.b.name}');
    for (final row in result.rows) {
      buffer.writeln(
        '• ${row.label}: ${_num(row.valueA)} مقابل ${_num(row.valueB)} ${row.unit}'
        ' — ${row.better == 'tie' ? 'متساوي' : row.better == 'a' ? 'أفضل أ' : 'أفضل ب'}',
      );
    }
    return buffer.toString();
  }
}

class _VersionsSheet extends StatefulWidget {
  final SavedIrrigationProject design;
  const _VersionsSheet({required this.design});

  @override
  State<_VersionsSheet> createState() => _VersionsSheetState();
}

class _VersionsSheetState extends State<_VersionsSheet> {
  List<SavedDesignVersion> _versions = const [];
  bool _loading = true;
  String? _error;
  bool _busy = false;

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
      final versions =
          await DesignVersionService.listVersions(widget.design.documentId);
      if (!mounted) return;
      setState(() {
        _versions = versions;
        _loading = false;
      });
    } on DesignVersionException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  Future<void> _saveVersion() async {
    final labelController = TextEditingController();
    final label = await showDialog<String>(
      context: context,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: const Text('حفظ نسخة من التصميم'),
          content: TextField(
            controller: labelController,
            decoration: const InputDecoration(
              labelText: 'وصف النسخة (اختياري)',
              hintText: 'مثال: قبل تعديل الشبكة',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('إلغاء'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(context, labelController.text.trim()),
              child: const Text('حفظ'),
            ),
          ],
        ),
      ),
    );
    if (label == null) return;
    setState(() => _busy = true);
    try {
      await DesignVersionService.saveVersion(
        projectId: widget.design.documentId,
        project: widget.design.project,
        label: label,
      );
      await _load();
    } on DesignVersionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _restore(SavedDesignVersion version) async {
    setState(() => _busy = true);
    try {
      await IrrigationProjectService.save(
        version.project,
        documentId: widget.design.documentId,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('تمت استعادة النسخة ${version.number}.')),
      );
      Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر استعادة النسخة.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.history, color: Color(0xFF047857)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'نسخ «${widget.design.name}»',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                if (_busy)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'احفظ لقطة قبل أي تعديل كبير، وارجع لها وقت ما تحتاج.',
              style: TextStyle(fontSize: 11, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                ),
                onPressed: _busy ? null : _saveVersion,
                icon: const Icon(Icons.save),
                label: const Text('حفظ نسخة الآن'),
              ),
            ),
            const SizedBox(height: 12),
            if (_loading)
              const Center(child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(),
              ))
            else if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red))
            else if (_versions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('لا توجد نسخ محفوظة بعد.',
                    style: TextStyle(fontSize: 12, color: Colors.grey)),
              )
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _versions.length,
                  itemBuilder: (context, index) {
                    final version = _versions[index];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            const Color(0xFF047857).withValues(alpha: 0.12),
                        child: Text(
                          '${version.number}',
                          style: const TextStyle(
                              fontSize: 11, color: Color(0xFF047857)),
                        ),
                      ),
                      title: Text(
                        version.label.isEmpty
                            ? 'نسخة ${version.number}'
                            : version.label,
                        style: const TextStyle(fontSize: 13),
                      ),
                      subtitle: version.createdAt == null
                          ? null
                          : Text(
                              '${version.createdAt!.day}/${version.createdAt!.month}/${version.createdAt!.year}',
                              style: const TextStyle(fontSize: 10),
                            ),
                      trailing: TextButton(
                        onPressed: _busy ? null : () => _restore(version),
                        child: const Text('استعادة',
                            style: TextStyle(fontSize: 11)),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
