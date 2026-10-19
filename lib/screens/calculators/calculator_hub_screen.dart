import 'package:flutter/material.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';
import 'irrigation_calculator_screen.dart';
import 'section_screen.dart';
import '../../utils/color_utils.dart';

class CalculatorHubScreen extends StatefulWidget {
  const CalculatorHubScreen({super.key});

  @override
  State<CalculatorHubScreen> createState() => _CalculatorHubScreenState();
}

class _CalculatorHubScreenState extends State<CalculatorHubScreen> {
  List<CalculatorSection> _sections = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
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

  Color _hexColor(String hex, {Color fallback = const Color(0xFF047857)}) =>
      ColorUtils.fromHex(hex, fallback: fallback);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('الحاسبات الزراعية',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _buildErrorState()
                : RefreshIndicator(
                    onRefresh: _loadSections,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF047857), Color(0xFF10B981)],
                              begin: Alignment.topRight,
                              end: Alignment.bottomLeft,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 60,
                                height: 60,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                alignment: Alignment.center,
                                child: const Icon(Icons.calculate,
                                    color: Colors.white, size: 34),
                              ),
                              const SizedBox(width: 14),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('اختر القسم',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 20)),
                                    SizedBox(height: 4),
                                    Text('برامج زراعية شاملة من الخدمة للحصاد',
                                        style: TextStyle(
                                            color: Colors.white70, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        
                        // Irrigation Calculator Card
                        Card(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          child: ListTile(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const IrrigationCalculatorScreen()),
                            ),
                            leading: const Icon(Icons.water_drop,
                                color: Color(0xFF0284C7), size: 30),
                            title: Text('تصميم شبكات الري',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                )),
                            subtitle: Text(
                                'تنقيط، رش، سطحي، محوري + المضخة وتصدير DXF',
                                style: TextStyle(
                                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                                )),
                            trailing: Icon(Icons.chevron_left, 
                              color: isDark ? Colors.white : Colors.black87),
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        Text('الأقسام المتاحة',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, 
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 10),

                        // Sections list
                        if (_sections.isEmpty)
                          Container(
                            padding: const EdgeInsets.all(30),
                            alignment: Alignment.center,
                            child: Column(
                              children: [
                                Icon(Icons.inbox,
                                    size: 60, color: Colors.grey.shade400),
                                const SizedBox(height: 10),
                                const Text('لا يوجد أقسام متاحة',
                                    style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          )
                        else
                          ..._sections.map((s) => _buildSectionCard(s)),
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

  Widget _buildSectionCard(CalculatorSection section) {
    // استخدام NumberUtils أو SafeParse لو الألوان جاية من Firestore كنصوص غريبة
    final primary = _hexColor(section.primaryColor);
    final secondary = _hexColor(section.secondaryColor, fallback: primary);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => SectionScreen(section: section),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [primary, secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
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
                child: Text(section.emoji,
                    style: const TextStyle(fontSize: 32)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(section.name,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(section.subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 12)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios,
                  color: Colors.white, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
