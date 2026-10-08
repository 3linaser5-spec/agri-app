import 'package:flutter/material.dart';
import '../../services/calculator_service.dart';

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
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

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
  final Map<String, TextEditingController> _costDistribution = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _costDistribution['تقاوي'] = TextEditingController();
    _costDistribution['أسمدة'] = TextEditingController();
    _costDistribution['مبيدات'] = TextEditingController();
    _costDistribution['عمالة'] = TextEditingController();
    _costDistribution['أخرى'] = TextEditingController();
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
    _costDistribution.forEach((_, c) => c.dispose());
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      _tabController.animateTo(0);
      return;
    }

    setState(() => _saving = true);

    // تجميع التحليل المالي
    final financialData = <String, dynamic>{
      'expected_yield': double.tryParse(_expectedYieldCtrl.text) ?? 0,
      'yield_unit': _yieldUnitCtrl.text.trim(),
      'expected_price': double.tryParse(_expectedPriceCtrl.text) ?? 0,
      'cost_distribution': _costDistribution.map(
        (key, ctrl) => MapEntry(key, double.tryParse(ctrl.text) ?? 0),
      ),
    };

    final id = await CalculatorService.addTemplate(
      sectionId: widget.sectionId,
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim().isEmpty ? '🌱' : _emojiCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      areaUnit: _areaUnitCtrl.text.trim(),
      areaUnitLabel: _areaLabelCtrl.text.trim(),
      fields: _fields,
      tasks: _tasks,
      materials: _materials,
      financial: financialData,
    );

    if (mounted) setState(() => _saving = false);

    if (id != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ تم حفظ القالب بنجاح'),
            backgroundColor: Color(0xFF047857),
          ),
        );
        Navigator.pop(context);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ فشل الحفظ، حاول مرة أخرى'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('قالب جديد - ${widget.sectionName}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Color(0xFFFDE68A),
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
            onPressed: _saving ? null : _save,
            tooltip: 'حفظ القالب',
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildBasicsTab(),
              _buildFieldsTab(),
              _buildTasksTab(),
              _buildMaterialsTab(),
            ],
          ),
        ),
      ),
    );
  }

  // ============ تاب 1: الأساسيات ============
  Widget _buildBasicsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(
            labelText: 'اسم المحصول *',
            hintText: 'مثال: قمح',
            prefixIcon: const Icon(Icons.eco),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'ادخل اسم المحصول' : null,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _emojiCtrl,
          decoration: InputDecoration(
            labelText: 'إيموجي',
            hintText: 'مثال: 🌾',
            prefixIcon: const Icon(Icons.emoji_emotions),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descCtrl,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'وصف المحصول *',
            hintText: 'مثال: برنامج زراعة القمح من خدمة الأرض للحصاد',
            prefixIcon: const Icon(Icons.description),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'ادخل الوصف' : null,
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _areaUnitCtrl,
                decoration: InputDecoration(
                  labelText: 'وحدة المساحة',
                  hintText: 'فدان',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _areaLabelCtrl,
                decoration: InputDecoration(
                  labelText: 'تسمية المساحة',
                  hintText: 'المساحة',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
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
              child: TextFormField(
                controller: _expectedYieldCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'الإنتاج المتوقع',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _yieldUnitCtrl,
                decoration: InputDecoration(
                  labelText: 'الوحدة',
                  hintText: 'طن',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: _expectedPriceCtrl,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: 'سعر بيع الوحدة (جنيه)',
            prefixIcon: const Icon(Icons.attach_money),
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        const Text('توزيع نسب التكاليف (%):',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        ..._costDistribution.entries.map((e) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: TextFormField(
                controller: e.value,
                keyboardType: TextInputType.number,
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
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'الحقول اللي المستخدم هيملاها قبل الحساب (زي المساحة، نوع التربة...)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_fields.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.edit_note, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('لا يوجد حقول بعد',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ...List.generate(_fields.length, (i) {
            final f = _fields[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.input, color: Color(0xFF047857)),
                title: Text(f['label'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('النوع: ${f['type']}  •  ID: ${f['id']}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _fields.removeAt(i)),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showAddFieldDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة حقل جديد'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _showAddFieldDialog() {
    final idCtrl = TextEditingController();
    final labelCtrl = TextEditingController();
    final unitCtrl = TextEditingController();
    String type = 'number';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة حقل جديد'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idCtrl,
                  decoration: const InputDecoration(
                    labelText: 'ID الحقل (إنجليزي)',
                    hintText: 'مثال: area',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: labelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم الحقل بالعربي',
                    hintText: 'مثال: المساحة',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: type,
                  decoration:
                      const InputDecoration(labelText: 'نوع الحقل'),
                  items: const [
                    DropdownMenuItem(value: 'number', child: Text('رقم')),
                    DropdownMenuItem(value: 'text', child: Text('نص')),
                    DropdownMenuItem(
                        value: 'dropdown', child: Text('قائمة منسدلة')),
                  ],
                  onChanged: (v) => setDialogState(() => type = v ?? 'number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: unitCtrl,
                  decoration: const InputDecoration(
                    labelText: 'الوحدة (اختياري)',
                    hintText: 'مثال: فدان',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (idCtrl.text.trim().isEmpty ||
                    labelCtrl.text.trim().isEmpty) return;
                setState(() {
                  _fields.add({
                    'id': idCtrl.text.trim(),
                    'label': labelCtrl.text.trim(),
                    'type': type,
                    'unit': unitCtrl.text.trim().isEmpty
                        ? null
                        : unitCtrl.text.trim(),
                    'required': true,
                  });
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ تاب 3: المهام ============
  Widget _buildTasksTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.orange, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'المهام اللي هتظهر في الجدول الزمني (يوم من بداية الزراعة)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_tasks.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.timeline, size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('لا يوجد مهام بعد',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ...List.generate(_tasks.length, (i) {
            final t = _tasks[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor: const Color(0xFF047857).withOpacity(0.15),
                  child: Text('${t['day_from_start']}',
                      style: const TextStyle(
                          color: Color(0xFF047857),
                          fontWeight: FontWeight.bold)),
                ),
                title: Text(t['title'] ?? '',
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
        ElevatedButton.icon(
          onPressed: _showAddTaskDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة مهمة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _showAddTaskDialog() {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final dayCtrl = TextEditingController(text: '0');
    String category = 'ري';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مهمة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المهمة',
                    hintText: 'مثال: رية المحاياة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: descCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'الوصف',
                    hintText: 'تفاصيل المهمة',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: dayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'اليوم من بداية الزراعة',
                    hintText: 'مثال: 21',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration:
                      const InputDecoration(labelText: 'التصنيف'),
                  items: const [
                    DropdownMenuItem(value: 'ري', child: Text('ري 💧')),
                    DropdownMenuItem(
                        value: 'تسميد', child: Text('تسميد 🧪')),
                    DropdownMenuItem(value: 'رش', child: Text('رش 🧴')),
                    DropdownMenuItem(
                        value: 'خدمة', child: Text('خدمة 🚜')),
                    DropdownMenuItem(value: 'حصاد', child: Text('حصاد 🌾')),
                  ],
                  onChanged: (v) => setDialogState(() => category = v ?? 'ري'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (titleCtrl.text.trim().isEmpty) return;
                setState(() {
                  _tasks.add({
                    'title': titleCtrl.text.trim(),
                    'description': descCtrl.text.trim(),
                    'day_from_start': int.tryParse(dayCtrl.text) ?? 0,
                    'category': category,
                  });
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }

  // ============ تاب 4: المواد ============
  Widget _buildMaterialsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, color: Colors.green, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'قائمة المشتريات: التقاوي، الأسمدة، المبيدات المطلوبة (لكل وحدة مساحة)',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        if (_materials.isEmpty)
          Container(
            padding: const EdgeInsets.all(30),
            alignment: Alignment.center,
            child: Column(
              children: [
                Icon(Icons.shopping_cart,
                    size: 60, color: Colors.grey.shade400),
                const SizedBox(height: 10),
                const Text('لا يوجد مواد بعد',
                    style: TextStyle(color: Colors.grey)),
              ],
            ),
          )
        else
          ...List.generate(_materials.length, (i) {
            final m = _materials[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.shopping_bag,
                    color: Color(0xFF047857)),
                title: Text(m['name'] ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(
                    '${m['category']} • ${m['quantity_per_unit']} ${m['unit']} / وحدة'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => setState(() => _materials.removeAt(i)),
                ),
              ),
            );
          }),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: _showAddMaterialDialog,
          icon: const Icon(Icons.add),
          label: const Text('إضافة مادة جديدة'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF047857),
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }

  void _showAddMaterialDialog() {
    final nameCtrl = TextEditingController();
    final qtyCtrl = TextEditingController();
    final unitCtrl = TextEditingController(text: 'كجم');
    final priceCtrl = TextEditingController();
    String category = 'تقاوي';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('إضافة مادة'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'اسم المادة',
                    hintText: 'مثال: بذور قمح',
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: category,
                  decoration:
                      const InputDecoration(labelText: 'التصنيف'),
                  items: const [
                    DropdownMenuItem(value: 'تقاوي', child: Text('تقاوي')),
                    DropdownMenuItem(value: 'سماد', child: Text('سماد')),
                    DropdownMenuItem(value: 'مبيد', child: Text('مبيد')),
                    DropdownMenuItem(value: 'عمالة', child: Text('عمالة')),
                  ],
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? 'تقاوي'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: qtyCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'الكمية / وحدة',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: unitCtrl,
                        decoration:
                            const InputDecoration(labelText: 'الوحدة'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: priceCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'السعر التقديري للوحدة',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameCtrl.text.trim().isEmpty) return;
                setState(() {
                  _materials.add({
                    'name': nameCtrl.text.trim(),
                    'category': category,
                    'quantity_per_unit':
                        double.tryParse(qtyCtrl.text) ?? 0,
                    'unit': unitCtrl.text.trim(),
                    'price_per_unit':
                        double.tryParse(priceCtrl.text) ?? 0,
                  });
                });
                Navigator.pop(ctx);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
              ),
              child: const Text('إضافة'),
            ),
          ],
        ),
      ),
    );
  }
}
