import 'package:flutter/material.dart';
import '../../models/calculator_models.dart';
import '../../services/calculator_service.dart';
import 'section_screen.dart';

class CalculatorHubScreen extends StatefulWidget {
  const CalculatorHubScreen({super.key});

  @override
  State<CalculatorHubScreen> createState() => _CalculatorHubScreenState();
}

class _CalculatorHubScreenState extends State<CalculatorHubScreen> {
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

  Color _hexColor(String hex, {Color fallback = const Color(0xFF047857)}) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (e) {
      return fallback;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الحاسبات الزراعية',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
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
                              color: Colors.white.withOpacity(0.2),
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
                    const SizedBox(height: 20),
                    const Text('الأقسام المتاحة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
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

  Widget _buildSectionCard(CalculatorSection section) {
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
                color: primary.withOpacity(0.3),
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
                  color: Colors.white.withOpacity(0.25),
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
