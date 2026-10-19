import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../config/app_config.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';
import '../../utils/safe_parse.dart'; // ✅ لضمان قراءة النصوص بأمان
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
  String? _error;
  bool _authorized = false;

  @override
  void initState() {
    super.initState();
    _checkAuthAndLoad();
  }

  // ✅ التحقق من صلاحية الأدمن قبل التحميل
  void _checkAuthAndLoad() {
    final user = FirebaseAuth.instance.currentUser;
    final email = user?.email ?? '';
    
    // التحقق: هل الإيميل ضمن الليستة؟
    if (!AppConfig.adminEmails.contains(email)) {
      setState(() {
        _loading = false;
        _error = 'ليس لديك صلاحية للوصول للوحة التحكم';
        _authorized = false;
      });
      return;
    }
    
    _authorized = true;
    _loadSections();
  }

  Future<void> _loadSections() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final sections = await CalculatorService.getSections();
      if (mounted) {
        setState(() {
          _sections = sections;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل الأقسام. تأكد من اتصالك بالإنترنت.';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // ✅ حماية الصفحة لو مش أدمن
    if (!_authorized && !_loading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('غير مصرح', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 80, color: Colors.red),
                const SizedBox(height: 16),
                Text(_error ?? 'ليس لديك صلاحية',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
      );
    }

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
            : _error != null
                ? _buildErrorState()
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
                      Text('📚 إدارة المحتوى:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87)),
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
                      Text('🌾 حاسبات ومخططات المزرعة:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87)),
                      const SizedBox(height: 10),
                      ..._sections.map((s) => _buildSectionTile(s, isDark)),
                    ],
                  ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 60),
            const SizedBox(height: 16),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadSections,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF047857),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
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
                  color: color.withValues(alpha: 0.15),
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
                        style: TextStyle(
                            fontWeight: FontWeight.bold, 
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: TextStyle(
                            fontSize: 11, 
                            color: isDark ? Colors.grey[400] : Colors.grey)),
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

  Widget _buildSectionTile(CalculatorSection section, bool isDark) {
    // ✅ SafeParse للتعامل مع أي null
    final name = SafeParse.string(section.name, 'بدون اسم');
    final subtitle = SafeParse.string(section.subtitle, '');
    final emoji = SafeParse.string(section.emoji, '📚');

    return Card(
      color: isDark ? const Color(0xFF1E1E1E) : null, // ✅ دعم الوضع الليلي
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF047857).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(emoji, style: const TextStyle(fontSize: 26)),
        ),
        title: Text(name,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            )),
        subtitle: Text(subtitle,
            style: TextStyle(
              fontSize: 12, 
              color: isDark ? Colors.grey[400] : Colors.grey,
            )),
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
  bool _deleting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list =
          await CalculatorService.getTemplatesBySection(widget.section.id);
      if (mounted) {
        setState(() {
          _templates = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'تعذر تحميل القوالب. تأكد من الاتصال.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteTemplate(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف القالب'),
        content: const Text('هل أنت متأكد من الحذف؟ لا يمكن التراجع.'),
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
    
    if (confirm == true && mounted) {
      // ✅ إظهار مؤشر التحميل
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final ok = await CalculatorService.deleteTemplate(id);
        
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop(); // إخفاء الـ loading

        if (!ok) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('فشل حذف القالب، حاول مرة تانية'),
                backgroundColor: Colors.red),
          );
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('✅ تم حذف القالب بنجاح'),
                backgroundColor: Color(0xFF047857)),
          );
          _loadTemplates();
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('حدث خطأ أثناء الحذف'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
              if (!mounted) return;
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
              if (!mounted) return;
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
            : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red, size: 60),
                          const SizedBox(height: 16),
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 20),
                          ElevatedButton.icon(
                            onPressed: _loadTemplates,
                            icon: const Icon(Icons.refresh),
                            label: const Text('إعادة المحاولة'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF047857),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : _templates.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text('لا يوجد قوالب في هذا القسم',
                                style: TextStyle(
                                    fontSize: 16, 
                                    color: isDark ? Colors.grey[400] : Colors.grey)),
                            const SizedBox(height: 8),
                            Text('دوس "إضافة قالب" أو "استيراد JSON" لتبدأ',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: isDark ? Colors.grey[400] : Colors.grey)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _templates.length,
                        itemBuilder: (context, index) {
                          final t = _templates[index];
                          final name = SafeParse.string(t.name, 'بدون اسم');
                          final description = SafeParse.string(t.description, '');
                          final emoji = SafeParse.string(t.emoji, '📄');
                          
                          return Card(
                            color: isDark ? const Color(0xFF1E1E1E) : null,
                            margin: const EdgeInsets.only(bottom: 10),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12)),
                            child: ListTile(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TemplateEditorScreen(
                                      sectionId: widget.section.id,
                                      sectionName: widget.section.name,
                                      templateId: t.id,
                                    ),
                                  ),
                                );
                                if (!mounted) return;
                                _loadTemplates();
                              },
                              leading: Text(emoji,
                                  style: const TextStyle(fontSize: 30)),
                              title: Text(name,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87,
                                  )),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(description,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? Colors.grey[400] : null,
                                      )),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      _chip('${t.fields.length} حقول', Colors.blue),
                                      const SizedBox(width: 4),
                                      _chip('${t.tasks.length} مهام', Colors.orange),
                                      const SizedBox(width: 4),
                                      _chip('${t.materials.length} مواد', Colors.green),
                                    ],
                                  ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.edit,
                                      size: 18, color: Colors.grey),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.red),
                                    onPressed: () => _deleteTemplate(t.id),
                                  ),
                                ],
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
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: TextStyle(
              fontSize: 10, color: color, fontWeight: FontWeight.bold)),
    );
  }
}
