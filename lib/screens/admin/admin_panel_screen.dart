import 'package:flutter/material.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';
import 'template_editor_screen.dart';
import 'json_import_screen.dart';
import 'encyclopedia_admin_screen.dart';

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
                  // ============ بانر الترحيب ============
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

                  // ============ إدارة المحتوى ============
                  const Text('📚 إدارة المحتوى:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  _buildAdminActionCard(
                    icon: Icons.menu_book,
                    color: const Color(0xFF0EA5E9),
                    title: 'إدارة الموسوعة الشاملة',
                    subtitle: 'أضف / عدل / احذف الأقسام والعناصر',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const EncyclopediaAdminScreen(),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ============ حاسبات ومخططات المزرعة ============
                  const Text('🌾 حاسبات ومخططات المزرعة:',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  ..._sections.map((s) => _buildSectionTile(s)),
                ],
              ),
      ),
    );
  }

  // ============ كارت إجراء إداري ============
  Widget _buildAdminActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: Colors.grey)),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 16, color: color),
            ],
          ),
        ),
      ),
    );
  }

  // ============ بطاقة قسم حاسبة ============
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
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'json_import',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => JsonImportScreen(section: widget.section),
                ),
              );
              _loadTemplates();
            },
            backgroundColor: Colors.blue.shade700,
            icon: const Icon(Icons.cloud_upload, color: Colors.white),
            label: const Text('استيراد JSON',
                style: TextStyle(color: Colors.white)),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'add_template',
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
            label: const Text('إضافة قالب',
                style: TextStyle(color: Colors.white)),
          ),
        ],
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
                        Text('دوس "إضافة قالب" أو "استيراد JSON" لتبدأ',
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
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.description,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 12)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _chip('${t.fields.length} حقول', Colors.blue),
                                  const SizedBox(width: 4),
                                  _chip('${t.tasks.length} مهام', Colors.orange),
                                  const SizedBox(width: 4),
                                  _chip('${t.materials.length} مواد',
                                      Colors.green),
                                ],
                              ),
                            ],
                          ),
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

  Widget _chip(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
