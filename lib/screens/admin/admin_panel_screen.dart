import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';

// ================== لوحة الأدمن الرئيسية ==================
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  List<CalculatorSection> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSections();
  }

  Future<void> _loadSections() async {
    final sections = await CalculatorService.getSections();
    if (mounted) {
      setState(() {
        _sections = sections;
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('لوحة تحكم الأدمن',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // بانر ترحيبي
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF047857), Color(0xFF10B981)],
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.admin_panel_settings,
                            color: Colors.white, size: 40),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('مرحباً يا أدمن 👋',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white)),
                              Text('${_sections.length} قسم متاح',
                                  style: const TextStyle(
                                      fontSize: 13, color: Colors.white70)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text('الأقسام:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ..._sections.map((s) => _buildSectionTile(s)),
                ],
              ),
      ),
    );
  }

  Widget _buildSectionTile(CalculatorSection section) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF047857).withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(section.emoji, style: const TextStyle(fontSize: 26)),
        ),
        title: Text(section.name,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(section.subtitle,
            style: const TextStyle(fontSize: 12, color: Colors.grey)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SectionTemplatesScreen(section: section),
          ),
        ),
      ),
    );
  }
}

// ================== شاشة قوالب القسم ==================
class SectionTemplatesScreen extends StatefulWidget {
  final CalculatorSection section;
  const SectionTemplatesScreen({super.key, required this.section});

  @override
  State<SectionTemplatesScreen> createState() => _SectionTemplatesScreenState();
}

class _SectionTemplatesScreenState extends State<SectionTemplatesScreen> {
  List<CalculatorTemplate> _templates = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    setState(() => _loading = true);
    final list =
        await CalculatorService.getTemplatesBySection(widget.section.id);
    if (mounted) {
      setState(() {
        _templates = list;
        _loading = false;
      });
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القالب'),
        content: const Text('هل أنت متأكد من الحذف؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('إلغاء')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await CalculatorService.deleteTemplate(id);
      _loadTemplates();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.section.emoji} ${widget.section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => TemplateEditorScreen(
                sectionId: widget.section.id,
                sectionName: widget.section.name,
              ),
            ),
          );
          _loadTemplates();
        },
        backgroundColor: const Color(0xFF047857),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('إضافة قالب', style: TextStyle(color: Colors.white)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _templates.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا يوجد قوالب في هذا القسم',
                            style:
                                TextStyle(fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('دوس "إضافة قالب" لتبدأ',
                            style:
                                TextStyle(fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _templates.length,
                    itemBuilder: (context, index) {
                      final t = _templates[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          leading: Text(t.emoji,
                              style: const TextStyle(fontSize: 30)),
                          title: Text(t.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(t.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12)),
                          trailing: IconButton(
                            icon:
                                const Icon(Icons.delete, color: Colors.red),
                            onPressed: () => _deleteTemplate(t.id),
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}

// ================== شاشة محرر القالب ==================
class TemplateEditorScreen extends StatefulWidget {
  final String sectionId;
  final String sectionName;
  const TemplateEditorScreen({
    super.key,
    required this.sectionId,
    required this.sectionName,
  });

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emojiCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emojiCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);

    final id = await CalculatorService.addTemplate(
      sectionId: widget.sectionId,
      name: _nameCtrl.text.trim(),
      emoji: _emojiCtrl.text.trim(),
      description: _descCtrl.text.trim(),
      areaUnit: 'فدان',
      areaUnitLabel: 'المساحة',
      fields: [],
      tasks: [],
      materials: [],
      financial: {},
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
        title: Text('إضافة قالب - ${widget.sectionName}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // اسم المحصول
              TextFormField(
                controller: _nameCtrl,
                decoration: InputDecoration(
                  labelText: 'اسم المحصول',
                  hintText: 'مثال: قمح',
                  prefixIcon: const Icon(Icons.eco),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ادخل اسم المحصول' : null,
              ),
              const SizedBox(height: 16),

              // الإيموجي
              TextFormField(
                controller: _emojiCtrl,
                decoration: InputDecoration(
                  labelText: 'إيموجي (اختياري)',
                  hintText: 'مثال: 🌾',
                  prefixIcon: const Icon(Icons.emoji_emotions),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // الوصف
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'وصف المحصول',
                  hintText: 'مثال: برنامج زراعة القمح من خدمة الأرض للحصاد',
                  prefixIcon: const Icon(Icons.description),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'ادخل الوصف' : null,
              ),
              const SizedBox(height: 24),

              // ملاحظة
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
                        'بعد الحفظ، تقدر تضيف الحقول والمهام والمواد من خلال تعديل القالب',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // زر الحفظ
              ElevatedButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(_saving ? 'جاري الحفظ...' : 'حفظ القالب'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(55),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
