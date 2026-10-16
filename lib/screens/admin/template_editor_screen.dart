import 'package:flutter/material.dart';
import '../../services/calculator_service.dart';
import '../../utils/formula_evaluator.dart';
import '../../utils/number_utils.dart';
import '../../utils/template_validator.dart';

const _green = Color(0xFF047857);

/// رقم للعرض في حقول التعديل: 5.0 تظهر 5 و 2.5 تفضل 2.5
String _fmtNum(dynamic v) {
  if (v is! num) return '';
  final d = v.toDouble();
  return d == d.roundToDouble() ? d.toInt().toString() : d.toString();
}

class TemplateEditorScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  final String? templateId; // لو تعديل قالب موجود

  const TemplateEditorScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
    this.templateId,
  });

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _saving = false;
  bool _loading = false;

  bool get _isEdit => widget.templateId != null;

  // البيانات الأساسية
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _areaUnitCtrl = TextEditingController(text: 'فدان');
  final _areaLabelCtrl = TextEditingController(text: 'المساحة');

  // القوائم
  final List<Map<String, dynamic>> _fields = [];
  final List<Map<String, dynamic>> _tasks = [];
  final List<Map<String, dynamic>> _materials = [];

  // التحليل المالي
  final _expectedYieldCtrl = TextEditingController();
  final _yieldUnitCtrl = TextEditingController(text: 'طن');
  final _expectedPriceCtrl = TextEditingController();
  final _yieldFormulaCtrl = TextEditingController();
  final Map<String, TextEditingController> _costDistribution = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    for (final k in const ['تقاوي', 'أسمدة', 'مبيدات', 'عمالة', 'أخرى']) {
      _costDistribution[k] = TextEditingController();
    }
    if (_isEdit) {
      // قبل أول build عشان المحرر الفاضي ما يظهرش لحظة قبل التحميل
      _loading = true;
      _loadExisting();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _descCtrl.dispose();
    _areaUnitCtrl.dispose();
    _areaLabelCtrl.dispose();
    _expectedYieldCtrl.dispose();
    _yieldUnitCtrl.dispose();
    _expectedPriceCtrl.dispose();
    _yieldFormulaCtrl.dispose();
    _costDistribution.forEach((_, c) => c.dispose());
    super.dispose();
  }

  // ───────────────────── تحميل قالب للتعديل ─────────────────────
  Future<void> _loadExisting() async {
    final t = await CalculatorService.getTemplate(widget.templateId!);
    if (!mounted) return;

    if (t == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('تعذر تحميل القالب (ممكن يكون اتحذف)'),
        backgroundColor: Colors.red,
      ));
      Navigator.pop(context);
      return;
    }

    setState(() {
      _nameCtrl.text = t.name;
      _emojiCtrl.text = t.emoji;
      _descCtrl.text = t.description;
      _areaUnitCtrl.text = t.areaUnit;
      _areaLabelCtrl.text = t.areaUnitLabel;

      _fields
        ..clear()
        ..addAll(t.fields.map((f) => f.toMap()));
      _tasks
        ..clear()
        ..addAll(t.tasks.map((k) => k.toMap()));
      _materials
        ..clear()
        ..addAll(t.materials.map((m) => m.toMap()));

      final fin = t.financial;
      _expectedYieldCtrl.text = fin.expectedYieldPerUnit == 0
          ? ''
          : _fmtNum(fin.expectedYieldPerUnit);
      _yieldUnitCtrl.text = fin.yieldUnit;
      _expectedPriceCtrl.text = fin.expectedPricePerYieldUnit == 0
          ? ''
          : _fmtNum(fin.expectedPricePerYieldUnit);
      _yieldFormulaCtrl.text = fin.yieldFormula ?? '';

      for (final c in _costDistribution.values) {
        c.clear();
      }
      fin.costDistribution.forEach((k, v) {
        final ctrl = _costDistribution.putIfAbsent(k, TextEditingController.new);
        ctrl.text = _fmtNum(v);
      });

      _loading = false;
    });
  }

  // أسماء المتغيرات المسموحة في المعادلات
  Set<String> get _knownVars => {
        'area',
        for (final f in _fields)
          if ((f['id']?.toString() ?? '').isNotEmpty) f['id'].toString(),
      };

  void _snack(String msg, {bool error = true}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : _green,
    ));
  }

  // ───────────────────── الحفظ ─────────────────────
  Future<void> _save() async {
    // الحقول بتتبني lazily داخل التابات، فالتحقق بيتم على الـ controllers مباشرة
    if (_nameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _tabController.animateTo(0);
      _snack('ادخل اسم المحصول ووصفه (تاب الأساسيات)');
      return;
    }

    // نسب التكاليف: القيم الصفرية تتشال، ولو فيه نسب لازم مجموعها 100
    final dist = <String, double>{};
    for (final e in _costDistribution.entries) {
      final v = NumberUtils.tryParseDouble(e.value.text);
      if (e.value.text.trim().isNotEmpty && v == null) {
        _tabController.animateTo(0);
        _snack('نسبة "${e.key}" غير صالحة');
        return;
      }
      if (v != null && v > 0) dist[e.key] = v;
    }
    final distSum = dist.values.fold<double>(0, (a, b) => a + b);
    if (dist.isNotEmpty && (distSum - 100).abs() > 0.5) {
      _tabController.animateTo(0);
      _snack('مجموع نسب التكاليف لازم يساوي 100% (الحالي ${_fmtNum(distSum)}%)');
      return;
    }

    final expectedYield =
        NumberUtils.tryParseDouble(_expectedYieldCtrl.text) ?? 0;
    final expectedPrice =
        NumberUtils.tryParseDouble(_expectedPriceCtrl.text) ?? 0;
    final yieldFormula = _yieldFormulaCtrl.text.trim();

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'emoji': _emojiCtrl.text.trim().isEmpty ? '🌱' : _emojiCtrl.text.trim(),
      'description': _descCtrl.text.trim(),
      'area_unit':
          _areaUnitCtrl.text.trim().isEmpty ? 'فدان' : _areaUnitCtrl.text.trim(),
      'area_unit_label': _areaLabelCtrl.text.trim().isEmpty
          ? 'المساحة'
          : _areaLabelCtrl.text.trim(),
      'fields': _fields,
      'tasks': _tasks,
      'materials': _materials,
      'financial': <String, dynamic>{
        'expected_yield': expectedYield,
        'yield_unit':
            _yieldUnitCtrl.text.trim().isEmpty ? 'طن' : _yieldUnitCtrl.text.trim(),
        'expected_price': expectedPrice,
        'cost_distribution': dist,
        if (yieldFormula.isNotEmpty) 'yield_formula': yieldFormula,
      },
    };

    // نفس فحص الاستيراد: نرفض أي حاجة هتبوّظ القالب عند القراءة
    final problems = TemplateValidator.validate(data);
    if (problems.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('في أخطاء لازم تتصلح'),
          content: SingleChildScrollView(
            child: Text(problems.take(8).map((e) => '• $e').join('\n') +
                (problems.length > 8
                    ? '\n... و${problems.length - 8} خطأ آخر'
                    : '')),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const Text('حسنًا')),
          ],
        ),
      );
      return;
    }

    // تنبيه (مش خطأ): قالب فيه حقول بدون حقل مساحة = الكميات هتتحسب لوحدة واحدة
    final hasArea =
        _fields.any((f) => (f['id']?.toString().toLowerCase() ?? '').contains('area'));
    if (_fields.isNotEmpty && !hasArea) {
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('مفيش حقل مساحة'),
          content: const Text(
              'القالب فيه حقول لكن ما فيهوش حقل id بتاعه area.\n'
              'الكميات هتتحسب لوحدة مساحة واحدة بس. تضيف حقل المساحة؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('رجوع وإضافة الحقل')),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('حفظ رغم ذلك')),
          ],
        ),
      );
      if (!mounted) return;
      if (proceed != true) {
        _tabController.animateTo(1);
        return;
      }
    }

    if (!mounted) return;
    setState(() => _saving = true);

    bool ok;
    if (_isEdit) {
      ok = await CalculatorService.updateTemplate(widget.templateId!, data);
    } else {
      final id = await CalculatorService.addTemplate(
        sectionId: widget.sectionId,
        name: data['name'] as String,
        emoji: data['emoji'] as String,
        description: data['description'] as String,
        areaUnit: data['area_unit'] as String,
        areaUnitLabel: data['area_unit_label'] as String,
        fields: _fields,
        tasks: _tasks,
        materials: _materials,
        financial: data['financial'] as Map<String, dynamic>,
      );
      ok = id != null;
    }

    if (!mounted) return;
    setState(() => _saving = false);

    if (ok) {
      _snack('✅ تم حفظ القالب بنجاح', error: false);
      Navigator.pop(context);
    } else {
      _snack('❌ فشل الحفظ، حاول مرة أخرى');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${_isEdit ? 'تعديل قالب' : 'قالب جديد'} - ${widget.sectionName}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: _green,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: const Color(0xFFFDE68A),
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.info), text: 'الأساسيات'),
            Tab(icon: Icon(Icons.edit_note), text: 'الحقول'),
            Tab(icon: Icon(Icons.timeline), text: 'المهام'),
            Tab(icon: Icon(Icons.shopping_cart), text: 'المشتريات'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.save, color: Colors.white),
            onPressed: (_saving || _loading) ? null : _save,
            tooltip: 'حفظ القالب',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                controller: _tabController,
                children: [
                  _buildBasicsTab(),
                  _buildFieldsTab(),
                  _buildTasksTab(),
                  _buildMaterialsTab(),
                ],
              ),
      ),
    );
  }

  InputDecoration _dec(String label,
          {String? hint, IconData? icon, String? suffix, String? helper}) =>
      InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        helperMaxLines: 3,
        suffixText: suffix,
        prefixIcon: icon == null ? null : Icon(icon),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      );

  Widget _hintBox(Color bg, Color fg, String text) => Container(
        padding: const EdgeInsets.all(12),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: fg, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
          ],
        ),
      );

  Widget _emptyBox(IconData icon, String text) => Container(
        padding: const EdgeInsets.all(30),
        alignment: Alignment.center,
        child: Column(
          children: [
            Icon(icon, size: 60, color: Colors.grey.shade400),
            const SizedBox(height: 10),
            Text(text, style: const TextStyle(color: Colors.grey)),
          ],
        ),
      );

  Widget _addButton(String label, VoidCallback onPressed) =>
      ElevatedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.add),
        label: Text(label),
        style: ElevatedButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(50),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );

  // ============ تاب 1: الأساسيات ============
  Widget _buildBasicsTab() {
    const numKb = TextInputType.numberWithOptions(decimal: true);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: _nameCtrl,
          decoration: _dec('اسم المحصول *', hint: 'مثال: قمح', icon: Icons.eco),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emojiCtrl,
          decoration:
              _dec('إيموجي', hint: 'مثال: 🌾', icon: Icons.emoji_emotions),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: _dec('وصف المحصول *',
              hint: 'مثال: برنامج زراعة القمح من خدمة الأرض للحصاد',
              icon: Icons.description),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _areaUnitCtrl,
                decoration: _dec('وحدة المساحة', hint: 'فدان'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _areaLabelCtrl,
                decoration: _dec('تسمية المساحة', hint: 'المساحة'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(),
        const SizedBox(height: 12),
        const Text('💰 التحليل المالي (اختياري)',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _expectedYieldCtrl,
                keyboardType: numKb,
                decoration: _dec('الإنتاج المتوقع / وحدة مساحة'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _yieldUnitCtrl,
                decoration: _dec('الوحدة', hint: 'طن'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _yieldFormulaCtrl,
          decoration: _dec('معادلة الإنتاج الكلي (اختياري)',
              hint: 'مثال: area * 18',
              icon: Icons.functions,
              helper: 'لو فاضية: الإنتاج = الإنتاج لكل وحدة × المساحة'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _expectedPriceCtrl,
          keyboardType: numKb,
          decoration:
              _dec('سعر بيع الوحدة (جنيه)', icon: Icons.attach_money),
        ),
        const SizedBox(height: 16),
        const Text('توزيع نسب التكاليف (%) - المجموع لازم 100:',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ..._costDistribution.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextField(
                controller: e.value,
                keyboardType: numKb,
                decoration: InputDecoration(
                  labelText: e.key,
                  suffixText: '%',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 12),
                ),
              ),
            )),
      ],
    );
  }

  // ============ تاب 2: الحقول ============
  Widget _buildFieldsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hintBox(
          Colors.blue.shade50,
          Colors.blue,
          'الحقول اللي المستخدم هيملاها قبل الحساب. لو ضفت حقول لازم تضيف حقل '
          'اسمه (ID) area للمساحة. من غير حقول، حقل المساحة بيظهر تلقائي.',
        ),
        const SizedBox(height: 16),
        if (_fields.isEmpty)
          _emptyBox(Icons.edit_note, 'لا يوجد حقول بعد')
        else
          ...List.generate(_fields.length, (i) {
            final f = _fields[i];
            final isDropdown = f['type'] == 'dropdown';
            final optionsCount = (f['options'] is List) ? (f['options'] as List).length : 0;
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _editField(i),
                leading: const Icon(Icons.input, color: _green),
                title: Text(f['label']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('النوع: ${f['type']}  •  ID: ${f['id']}'
                    '${isDropdown ? '  •  $optionsCount خيار' : ''}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _fields.removeAt(i)),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        _addButton('إضافة حقل جديد', () => _editField(null)),
      ],
    );
  }

  Future<void> _editField(int? index) async {
    final taken = <String>{
      for (var i = 0; i < _fields.length; i++)
        if (i != index) (_fields[i]['id']?.toString() ?? '').trim(),
    };
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _FieldDialog(
        initial: index == null ? null : _fields[index],
        takenIds: taken,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _fields.add(result);
      } else {
        _fields[index] = result;
      }
    });
  }

  // ============ تاب 3: المهام ============
  Widget _buildTasksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hintBox(Colors.amber.shade50, Colors.orange,
            'المهام اللي هتظهر في الجدول الزمني (يوم من بداية الزراعة)'),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          _emptyBox(Icons.timeline, 'لا يوجد مهام بعد')
        else
          ...List.generate(_tasks.length, (i) {
            final t = _tasks[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _editTask(i),
                leading: CircleAvatar(
                  backgroundColor: _green.withValues(alpha: 0.15),
                  child: Text('${t['day_from_start']}',
                      style: const TextStyle(
                          color: _green, fontWeight: FontWeight.bold)),
                ),
                title: Text(t['title']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${t['category']} • ${t['description']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _tasks.removeAt(i)),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        _addButton('إضافة مهمة جديدة', () => _editTask(null)),
      ],
    );
  }

  Future<void> _editTask(int? index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _TaskDialog(initial: index == null ? null : _tasks[index]),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _tasks.add(result);
      } else {
        _tasks[index] = result;
      }
    });
  }

  // ============ تاب 4: المواد ============
  Widget _buildMaterialsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _hintBox(Colors.green.shade50, Colors.green,
            'قائمة المشتريات: التقاوي، الأسمدة، المبيدات المطلوبة (لكل وحدة مساحة، أو بمعادلة)'),
        const SizedBox(height: 16),
        if (_materials.isEmpty)
          _emptyBox(Icons.shopping_cart, 'لا يوجد مواد بعد')
        else
          ...List.generate(_materials.length, (i) {
            final m = _materials[i];
            final formula = m['quantity_formula']?.toString() ?? '';
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                onTap: () => _editMaterial(i),
                leading: const Icon(Icons.shopping_bag, color: _green),
                title: Text(m['name']?.toString() ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(formula.isNotEmpty
                    ? '${m['category']} • الكمية = $formula ${m['unit']}'
                    : '${m['category']} • ${_fmtNum(m['quantity_per_unit'])} ${m['unit']} / وحدة'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _materials.removeAt(i)),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        _addButton('إضافة مادة جديدة', () => _editMaterial(null)),
      ],
    );
  }

  Future<void> _editMaterial(int? index) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _MaterialDialog(
        initial: index == null ? null : _materials[index],
        knownVars: _knownVars,
      ),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (index == null) {
        _materials.add(result);
      } else {
        _materials[index] = result;
      }
    });
  }
}

// ═══════════════════════════════════════════════════════════
// حوار الحقل (Stateful عشان الـ controllers تتخلص منها صح)
// ═══════════════════════════════════════════════════════════
class _FieldDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final Set<String> takenIds;
  const _FieldDialog({this.initial, required this.takenIds});

  @override
  State<_FieldDialog> createState() => _FieldDialogState();
}

class _FieldDialogState extends State<_FieldDialog> {
  static final _idRegex = RegExp(r'^[A-Za-z_][A-Za-z0-9_]*$');
  // مفاتيح بيستخدمها النموذج نفسه
  static const _reserved = {'governorate', 'climate_zone'};

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _id;
  late final TextEditingController _label;
  late final TextEditingController _unit;
  late final TextEditingController _options;
  late final TextEditingController _min;
  late final TextEditingController _max;
  late final TextEditingController _default;
  late String _type;
  late bool _required;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const <String, dynamic>{};
    _id = TextEditingController(text: i['id']?.toString() ?? '');
    _label = TextEditingController(text: i['label']?.toString() ?? '');
    _unit = TextEditingController(text: i['unit']?.toString() ?? '');
    final opts = (i['options'] is List) ? (i['options'] as List) : const [];
    _options = TextEditingController(
      text: opts.whereType<Map>().map((o) {
        final v = o['value']?.toString() ?? '';
        final l = o['label']?.toString() ?? '';
        return v == l ? l : '$v|$l';
      }).join('\n'),
    );
    _min = TextEditingController(text: _fmtNum(i['min']));
    _max = TextEditingController(text: _fmtNum(i['max']));
    _default = TextEditingController(text: _fmtNum(i['default']));
    final t = i['type']?.toString() ?? 'number';
    // slider بيتعرض كحقل رقم في النموذج، لكن لازم نحافظ على نوعه لو كان
    // موجود في قالب قديم (قبل كده كان بيتحوّل لـ number بدون ما حد يلاحظ)
    _type = const ['number', 'text', 'dropdown', 'slider'].contains(t)
        ? t
        : 'number';
    _required = i['required'] is bool ? i['required'] as bool : true;
  }

  @override
  void dispose() {
    _id.dispose();
    _label.dispose();
    _unit.dispose();
    _options.dispose();
    _min.dispose();
    _max.dispose();
    _default.dispose();
    super.dispose();
  }

  // كل سطر: "القيمة|الاسم الظاهر" أو "الاسم" فقط (القيمة = الاسم)
  List<Map<String, String>> _parseOptions() {
    final result = <Map<String, String>>[];
    for (final raw in _options.text.split('\n')) {
      final line = raw.trim();
      if (line.isEmpty) continue;
      final bar = line.indexOf('|');
      if (bar == -1) {
        result.add({'value': line, 'label': line});
      } else {
        final v = line.substring(0, bar).trim();
        final l = line.substring(bar + 1).trim();
        if (v.isNotEmpty && l.isNotEmpty) result.add({'value': v, 'label': l});
      }
    }
    return result;
  }

  String? _optionalNumber(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return NumberUtils.tryParseDouble(v) == null ? 'رقم غير صالح' : null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    // نبدأ من الحقل الأصلي عشان أي مفاتيح تانية (زي hint) ما تتمسحش عند التعديل
    final map = <String, dynamic>{
      if (widget.initial != null) ...widget.initial!,
      'id': _id.text.trim(),
      'label': _label.text.trim(),
      'type': _type,
      'unit': _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      'required': _required,
    };
    // نشيل المفاتيح اللي ما تنفعش مع النوع الحالي
    if (_type == 'dropdown') {
      map['options'] = _parseOptions();
    } else {
      map.remove('options');
    }
    if (_type == 'number' || _type == 'slider') {
      final mn = NumberUtils.tryParseDouble(_min.text);
      final mx = NumberUtils.tryParseDouble(_max.text);
      final df = NumberUtils.tryParseDouble(_default.text);
      // لو المستخدم مسح القيمة لازم تتشال، مش تفضل القيمة القديمة
      if (mn != null) {
        map['min'] = mn;
      } else {
        map.remove('min');
      }
      if (mx != null) {
        map['max'] = mx;
      } else {
        map.remove('max');
      }
      if (df != null) {
        map['default'] = df;
      } else {
        map.remove('default');
      }
    } else {
      map
        ..remove('min')
        ..remove('max')
        ..remove('default');
    }
    Navigator.pop(context, map);
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة حقل جديد' : 'تعديل الحقل'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _id,
                  decoration: const InputDecoration(
                    labelText: 'ID الحقل (إنجليزي)',
                    hintText: 'مثال: area',
                  ),
                  validator: (v) {
                    final id = v?.trim() ?? '';
                    if (id.isEmpty) return 'ادخل الـ ID';
                    if (!_idRegex.hasMatch(id)) {
                      return 'حروف إنجليزية وأرقام و _ فقط، ويبدأ بحرف';
                    }
                    if (_reserved.contains(id)) return 'الـ ID ده محجوز للنظام';
                    if (widget.takenIds.contains(id)) return 'الـ ID مستخدم قبل كده';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _label,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحقل بالعربي',
                    hintText: 'مثال: المساحة',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'ادخل اسم الحقل' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'نوع الحقل'),
                  items: [
                    const DropdownMenuItem(value: 'number', child: Text('رقم')),
                    const DropdownMenuItem(value: 'text', child: Text('نص')),
                    const DropdownMenuItem(
                        value: 'dropdown', child: Text('قائمة منسدلة')),
                    // يظهر فقط لو الحقل الأصلي slider (عشان ما يتحوّلش بالغلط)
                    if (widget.initial?['type'] == 'slider')
                      const DropdownMenuItem(
                          value: 'slider', child: Text('شريط تمرير')),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'number'),
                ),
                if (_type == 'dropdown') ...[
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _options,
                    maxLines: 5,
                    decoration: const InputDecoration(
                      labelText: 'الخيارات (كل خيار في سطر)',
                      hintText: 'طينية\nرملية\ncalcareous|جيرية',
                      helperText: 'الصيغة: القيمة|الاسم الظاهر، أو الاسم فقط',
                      helperMaxLines: 2,
                    ),
                    validator: (v) {
                      final opts = _parseOptions();
                      if (opts.isEmpty) return 'ادخل خيار واحد على الأقل';
                      final values = opts.map((o) => o['value']).toList();
                      if (values.toSet().length != values.length) {
                        return 'فيه قيم مكررة بين الخيارات';
                      }
                      return null;
                    },
                  ),
                ],
                const SizedBox(height: 10),
                TextFormField(
                  controller: _unit,
                  decoration: const InputDecoration(
                    labelText: 'الوحدة (اختياري)',
                    hintText: 'مثال: فدان',
                  ),
                ),
                if (_type == 'number' || _type == 'slider') ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _min,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'أقل قيمة'),
                          validator: _optionalNumber,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _max,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration:
                              const InputDecoration(labelText: 'أكبر قيمة'),
                          validator: (v) {
                            final e = _optionalNumber(v);
                            if (e != null) return e;
                            final mn = NumberUtils.tryParseDouble(_min.text);
                            final mx = NumberUtils.tryParseDouble(v);
                            if (mn != null && mx != null && mx < mn) {
                              return 'أقل من الحد الأدنى';
                            }
                            return null;
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _default,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                        labelText: 'القيمة الافتراضية (اختياري)'),
                    validator: _optionalNumber,
                  ),
                ],
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('حقل إجباري'),
                  value: _required,
                  onChanged: (v) => setState(() => _required = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: Text(widget.initial == null ? 'إضافة' : 'حفظ',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// حوار المهمة
// ═══════════════════════════════════════════════════════════
class _TaskDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  const _TaskDialog({this.initial});

  @override
  State<_TaskDialog> createState() => _TaskDialogState();
}

class _TaskDialogState extends State<_TaskDialog> {
  static const _base = ['ري', 'تسميد', 'رش', 'خدمة', 'حصاد'];
  static const _icons = {
    'ري': 'ري 💧',
    'تسميد': 'تسميد 🧪',
    'رش': 'رش 🧴',
    'خدمة': 'خدمة 🚜',
    'حصاد': 'حصاد 🌾',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  late final TextEditingController _day;
  late String _category;
  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const <String, dynamic>{};
    _title = TextEditingController(text: i['title']?.toString() ?? '');
    _desc = TextEditingController(text: i['description']?.toString() ?? '');
    _day = TextEditingController(
        text: i['day_from_start'] == null ? '0' : _fmtNum(i['day_from_start']));
    final cat = i['category']?.toString() ?? '';
    // لو التصنيف القديم مش من القائمة (قالب مستورد مثلاً) نضيفه بدل ما الـ dropdown يرمي خطأ
    _categories = [..._base, if (cat.isNotEmpty && !_base.contains(cat)) cat];
    _category = cat.isNotEmpty ? cat : 'ري';
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _day.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(context, {
      'title': _title.text.trim(),
      'description': _desc.text.trim(),
      'day_from_start': NumberUtils.tryParseInt(_day.text) ?? 0,
      'category': _category,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة مهمة' : 'تعديل المهمة'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'اسم المهمة',
                    hintText: 'مثال: رية المحاياة',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'ادخل اسم المهمة' : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _desc,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'تفاصيل المهمة',
                  ),
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _day,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'اليوم من بداية الزراعة',
                    hintText: 'مثال: 21',
                  ),
                  validator: (v) {
                    final n = NumberUtils.tryParseInt(v);
                    if (n == null || n < 0) return 'ادخل رقم 0 أو أكبر';
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: _categories
                      .map((c) => DropdownMenuItem(
                          value: c, child: Text(_icons[c] ?? c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'ري'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: Text(widget.initial == null ? 'إضافة' : 'حفظ',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// حوار المادة (مع معادلة اختيارية للكمية)
// ═══════════════════════════════════════════════════════════
class _MaterialDialog extends StatefulWidget {
  final Map<String, dynamic>? initial;
  final Set<String> knownVars;
  const _MaterialDialog({this.initial, required this.knownVars});

  @override
  State<_MaterialDialog> createState() => _MaterialDialogState();
}

class _MaterialDialogState extends State<_MaterialDialog> {
  static const _base = ['تقاوي', 'سماد', 'مبيد', 'عمالة'];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _qty;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _formula;
  late String _category;
  late final List<String> _categories;

  @override
  void initState() {
    super.initState();
    final i = widget.initial ?? const <String, dynamic>{};
    _name = TextEditingController(text: i['name']?.toString() ?? '');
    _qty = TextEditingController(text: _fmtNum(i['quantity_per_unit']));
    _unit = TextEditingController(text: i['unit']?.toString() ?? 'كجم');
    _price = TextEditingController(text: _fmtNum(i['price_per_unit']));
    _formula =
        TextEditingController(text: i['quantity_formula']?.toString() ?? '');
    final cat = i['category']?.toString() ?? '';
    _categories = [..._base, if (cat.isNotEmpty && !_base.contains(cat)) cat];
    _category = cat.isNotEmpty ? cat : 'تقاوي';
  }

  @override
  void dispose() {
    _name.dispose();
    _qty.dispose();
    _unit.dispose();
    _price.dispose();
    _formula.dispose();
    super.dispose();
  }

  String? _nonNegative(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    final n = NumberUtils.tryParseDouble(v);
    if (n == null) return 'رقم غير صالح';
    if (n < 0) return 'لا يقل عن صفر';
    return null;
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final formula = _formula.text.trim();
    Navigator.pop(context, <String, dynamic>{
      'name': _name.text.trim(),
      'category': _category,
      'quantity_per_unit': NumberUtils.tryParseDouble(_qty.text) ?? 0,
      'unit': _unit.text.trim().isEmpty ? 'كجم' : _unit.text.trim(),
      'price_per_unit': NumberUtils.tryParseDouble(_price.text) ?? 0,
      if (formula.isNotEmpty) 'quantity_formula': formula,
    });
  }

  @override
  Widget build(BuildContext context) {
    final vars = (widget.knownVars.toList()..sort()).join('، ');
    return Directionality(
      textDirection: TextDirection.rtl,
      child: AlertDialog(
        title: Text(widget.initial == null ? 'إضافة مادة' : 'تعديل المادة'),
        content: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة',
                    hintText: 'مثال: بذور قمح',
                  ),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'ادخل اسم المادة' : null,
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(labelText: 'التصنيف'),
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _category = v ?? 'تقاوي'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _qty,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                        decoration:
                            const InputDecoration(labelText: 'الكمية / وحدة'),
                        validator: _nonNegative,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _unit,
                        decoration: const InputDecoration(labelText: 'الوحدة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: 'السعر التقديري للوحدة'),
                  validator: _nonNegative,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _formula,
                  decoration: InputDecoration(
                    labelText: 'معادلة الكمية الكلية (اختياري)',
                    hintText: 'مثال: area * seed_rate / 1000',
                    helperText:
                        'لو فاضية: الكمية = الكمية/وحدة × المساحة.\nالمتغيرات: $vars',
                    helperMaxLines: 4,
                  ),
                  validator: (v) =>
                      FormulaEvaluator.validate(v ?? '', widget.knownVars),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _submit,
            style: ElevatedButton.styleFrom(backgroundColor: _green),
            child: Text(widget.initial == null ? 'إضافة' : 'حفظ',
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
