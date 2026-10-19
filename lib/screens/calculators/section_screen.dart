import 'package:flutter/material.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';
import 'dynamic_form_screen.dart';
import '../../utils/color_utils.dart';
import '../../utils/safe_parse.dart'; // ✅ لضمان قراءة النصوص بأمان

class SectionScreen extends StatefulWidget {
  final CalculatorSection section;
  const SectionScreen({super.key, required this.section});

  @override
  State<SectionScreen> createState() => _SectionScreenState();
}

class _SectionScreenState extends State<SectionScreen> {
  List<CalculatorTemplate> _templates = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadTemplates();
  }

  Future<void> _loadTemplates() async {
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
          _error = 'تعذر تحميل المحاصيل. تأكد من اتصالك بالإنترنت.';
          _loading = false;
        });
      }
    }
  }

  Color _hexColor(String hex, {Color fallback = const Color(0xFF047857)}) =>
      ColorUtils.fromHex(hex, fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = _hexColor(widget.section.primaryColor);
    final secondary =
        _hexColor(widget.section.secondaryColor, fallback: primary);

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.section.emoji} ${widget.section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: primary,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadTemplates,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [primary, secondary],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: Text(widget.section.emoji,
                                    style: const TextStyle(fontSize: 32)),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(widget.section.name,
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text(widget.section.subtitle,
                                        style: const TextStyle(
                                            color: Colors.white70,
                                            fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text('${_templates.length} محصول متاح',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 10),

                        if (_templates.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(40),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.eco,
                                    size: 70, color: Colors.grey.shade400),
                                const SizedBox(height: 12),
                                const Text(
                                  'لا يوجد محاصيل بعد',
                                  style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'جاري إضافة المحاصيل قريباً',
                                  style: TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._templates.map(
                              (t) => _buildTemplateCard(t, primary, isDark)),
                      ],
                    ),
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
            Text(_error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadTemplates,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _hexColor(widget.section.primaryColor),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplateCard(
      CalculatorTemplate template, Color primary, bool isDark) {
    // ✅ استخدام SafeParse لضمان قراءة النصوص بأمان
    final templateName = SafeParse.string(template.name, 'بدون اسم');
    final templateDescription = SafeParse.string(template.description, '');
    final templateEmoji = SafeParse.string(template.emoji, '🌱');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => DynamicFormScreen(
                template: template,
                primaryColor: primary,
                sectionName: widget.section.name,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            // ✅ دعم الوضع الليلي
            color: isDark ? const Color(0xFF1E1E1E) : Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDark ? Colors.grey.shade800 : Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.3)
                    : Colors.grey.shade100,
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 55,
                height: 55,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(templateEmoji,
                    style: const TextStyle(fontSize: 28)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(templateName,
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: isDark ? Colors.white : Colors.black87)),
                    const SizedBox(height: 4),
                    Text(templateDescription,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey[400] : Colors.grey)),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _chip('${template.fields.length} حقول', primary),
                        const SizedBox(width: 4),
                        _chip('${template.tasks.length} مهام', primary),
                        const SizedBox(width: 4),
                        _chip('${template.materials.length} مواد', primary),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: primary, size: 16),
            ],
          ),
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
