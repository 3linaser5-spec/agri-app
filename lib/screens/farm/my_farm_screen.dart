import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/my_farm_model.dart';
import '../../services/my_farm_service.dart';
import '../../utils/safe_parse.dart'; // ✅ لضمان قراءة النصوص بأمان
import 'program_details_screen.dart';

class MyFarmScreen extends StatefulWidget {
  const MyFarmScreen({super.key});

  @override
  State<MyFarmScreen> createState() => _MyFarmScreenState();
}

class _MyFarmScreenState extends State<MyFarmScreen> {
  // إدارة الـ Stream باستخدام متغير عشان نقدر نغيره لو المستخدم اتغير
  Stream<List<MyFarmProgram>>? _programsStream;

  @override
  void initState() {
    super.initState();
    _updateStream();
  }

  // نتحقق من الـ User كل مرة ونجيب الـ Stream بتاعه
  void _updateStream() {
    final user = FirebaseAuth.instance.currentUser;
    setState(() {
      _programsStream = user == null 
          ? null 
          : MyFarmService.getUserPrograms(user.uid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('مزرعتي 🌱',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: user == null
            ? const Center(child: Text('الرجاء تسجيل الدخول'))
            : StreamBuilder<List<MyFarmProgram>>(
                stream: _programsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 60, color: Colors.red),
                            const SizedBox(height: 12),
                            Text('حدث خطأ: ${snapshot.error}',
                                textAlign: TextAlign.center),
                          ],
                        ),
                      ),
                    );
                  }

                  final programs = snapshot.data ?? [];

                  if (programs.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.agriculture,
                                size: 100, color: Colors.grey.shade400),
                            const SizedBox(height: 20),
                            Text('مزرعتك فاضية 🌾',
                                style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: isDark ? Colors.white : Colors.black87)),
                            const SizedBox(height: 8),
                            const Text(
                              'ابدأ بإضافة برنامج زراعي من الحاسبات الزراعية',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  fontSize: 13, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      // ✅ نستخدم الطريقة عشان نحدث الـ Stream
                      _updateStream();
                      await Future.delayed(const Duration(milliseconds: 500));
                    },
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Header
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
                              const Icon(Icons.agriculture,
                                  color: Colors.white, size: 40),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${programs.length} برنامج زراعي',
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'متابعة المحاصيل والمهام اليومية',
                                      style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        ...programs.map((p) => _buildProgramCard(context, p, isDark)),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }

  Widget _buildProgramCard(BuildContext context, MyFarmProgram program, bool isDark) {
    // ✅ استخدام SafeParse للتعامل مع أي null من Firestore
    final templateName = SafeParse.string(program.templateName, 'برنامج زراعي');
    final templateEmoji = SafeParse.string(program.templateEmoji, '🌱');
    final governorate = SafeParse.string(program.governorate, 'غير محدد');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ProgramDetailsScreen(program: program),
            ),
          );
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(14),
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
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 55,
                    height: 55,
                    decoration: BoxDecoration(
                      color: const Color(0xFF047857).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    alignment: Alignment.center,
                    child: Text(templateEmoji,
                        style: const TextStyle(fontSize: 30)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(templateName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold, 
                              fontSize: 16,
                              color: isDark ? Colors.white : Colors.black87)),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.location_on,
                                size: 12, color: Colors.grey),
                            const SizedBox(width: 3),
                            Text(governorate,
                                style: const TextStyle(
                                    fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  _buildStatusBadge(program),
                ],
              ),
              const SizedBox(height: 12),

              Row(
                children: [
                  _buildInfoChip(
                      Icons.calendar_today,
                      'اليوم ${program.daysSinceStart}',
                      Colors.blue),
                  const SizedBox(width: 6),
                  _buildInfoChip(
                      Icons.check_circle_outline,
                      '${program.doneCount}/${program.tasks.length} منجزة',
                      Colors.orange),
                  if (program.overdueTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _buildInfoChip(
                        Icons.warning_amber_rounded,
                        '${program.overdueTasks.length} متأخرة',
                        Colors.red),
                  ],
                ],
              ),

              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: program.progress,
                  minHeight: 8,
                  backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade200,
                  color: const Color(0xFF047857),
                ),
              ),
              const SizedBox(height: 6),

              if (program.nextTask != null)
                Row(
                  children: [
                    const Icon(Icons.arrow_forward,
                        size: 14, color: Color(0xFF047857)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'القادم: ${program.nextTask!['title']}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF047857),
                            fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusBadge(MyFarmProgram program) {
    final isActive = !program.isCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (isActive ? Colors.green : Colors.grey).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'نشط' : 'مكتمل',
        style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isActive ? Colors.green : Colors.grey),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(text,
              style: TextStyle(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
