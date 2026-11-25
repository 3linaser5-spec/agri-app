import 'package:material_ui/material_ui.dart';
import '../../services/calculator_service.dart';
import '../../utils/number_utils.dart';
import '../../utils/template_validator.dart';
import 'template_editor_dialogs.dart';

const _green = Color(0xFF047857);

class TemplateEditorScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  final String? templateId;

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
    try {
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
            : formatTemplateNumber(fin.expectedYieldPerUnit);
        _yieldUnitCtrl.text = fin.yieldUnit;
        _expectedPriceCtrl.text = fin.expectedPricePerYieldUnit == 0
            ? ''
            : formatTemplateNumber(fin.expectedPricePerYieldUnit);
        _yieldFormulaCtrl.text = fin.yieldFormula ?? '';

        for (final c in _costDistribution.values) {
          c.clear();
        }
        fin.costDistribution.forEach((k, v) {
          final ctrl =
              _costDistribution.putIfAbsent(k, TextEditingController.new);
          ctrl.text = formatTemplateNumber(v);
        });

        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('حدث خطأ أثناء تحميل القالب'),
        backgroundColor: Colors.red,
      ));
      Navigator.pop(context);
    }
  }

  Set<String> get _knownVars => {
        'area',
        for (final f in _fields)
          if ((f['id']?.toString() ?? '').isNotEmpty) f['id'].toString(),
      };

  void _snack(String msg, {bool error = true}) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar(); // ✅ منع تراكم الرسائل
    messenger.showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? Colors.red : _green,
    ));
  }

  /// ✅ نروح للتاب الصحيح حسب نوع الخطأ
  void _goToTab(int index) {
    _tabController.animateTo(index);
  }

  // ───────────────────── الحفظ ─────────────────────
  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty || _descCtrl.text.trim().isEmpty) {
      _goToTab(0);
      _snack('ادخل اسم المحصول ووصفه (تاب الأساسيات)');
      return;
    }

    final dist = <String, double>{};
    for (final e in _costDistribution.entries) {
      final v = NumberUtils.tryParseDouble(e.value.text);
      if (e.value.text.trim().isNotEmpty &&
          (v == null || !v.isFinite || v < 0 || v > 100)) {
        _goToTab(0);
        _snack('نسبة "${e.key}" لازم تكون رقمًا بين 0 و100');
        return;
      }
      if (v != null && v > 0) dist[e.key] = v;
    }
    final distSum = dist.values.fold<double>(0, (a, b) => a + b);
    if (dist.isNotEmpty && (distSum - 100).abs() > 0.5) {
      _goToTab(0);
      _snack('مجموع نسب التكاليف لازم يساوي 100% (الحالي ${formatTemplateNumber(distSum)}%)');
      return;
    }

    final yieldText = _expectedYieldCtrl.text.trim();
    final expectedYield = NumberUtils.tryParseDouble(yieldText);
    if (yieldText.isNotEmpty &&
        (expectedYield == null ||
            !expectedYield.isFinite ||
            expectedYield < 0)) {
      _goToTab(0);
      _snack('الإنتاج المتوقع لازم يكون رقمًا 0 أو أكبر');
      return;
    }
    final priceText = _expectedPriceCtrl.text.trim();
    final expectedPrice = NumberUtils.tryParseDouble(priceText);
    if (priceText.isNotEmpty &&
        (expectedPrice == null ||
            !expectedPrice.isFinite ||
            expectedPrice < 0)) {
      _goToTab(0);
      _snack('سعر البيع لازم يكون رقمًا 0 أو أكبر');
      return;
    }
    final yieldFormula = _yieldFormulaCtrl.text.trim();

    final data = <String, dynamic>{
      'name': _nameCtrl.text.trim(),
      'emoji':
          _emojiCtrl.text.trim().isEmpty ? '🌱' : _emojiCtrl.text.trim(),
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
        'expected_yield': expectedYield ?? 0,
        'yield_unit': _yieldUnitCtrl.text.trim().isEmpty
            ? 'طن'
            : _yieldUnitCtrl.text.trim(),
        'expected_price': expectedPrice ?? 0,
        'cost_distribution': dist,
        if (yieldFormula.isNotEmpty) 'yield_formula': yieldFormula,
      },
    };

    final problems = TemplateValidator.validate(data);
    if (problems.isNotEmpty) {
      if (!mounted) return;
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

    // تنبيه (مش خطأ): قالب فيه حقول بدون حقل مساحة
    final hasArea = _fields.any((f) =>
        (f['id']?.toString().toLowerCase() ?? '').contains('area'));
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
        _goToTab(1); // ✅ نروح لتاب الحقول
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
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.save, color: Colors.white),
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
            final optionsCount =
                (f['options'] is List) ? (f['options'] as List).length : 0;
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
      builder: (_) => TemplateFieldDialog(
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
          TemplateTaskDialog(initial: index == null ? null : _tasks[index]),
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
                    : '${m['category']} • ${formatTemplateNumber(m['quantity_per_unit'])} ${m['unit']} / وحدة'),
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
      builder: (_) => TemplateMaterialDialog(
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

