import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../config/app_config.dart';


// ---------------- AboutScreen ----------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openWhatsApp(BuildContext context) async {
    final url = AppConfig.whatsappUrl;
    if (url == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('رقم التواصل غير متاح في هذه النسخة')));
      return;
    }
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('تعذر فتح واتساب');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            const Text('عن التطبيق', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Center(
              child: Text(
                'نباتي',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF047857),
                ),
              ),
            ),
            const Center(
              child: Text(
                'مستشارك الزراعي الذكي',
                style: TextStyle(fontSize: 15, color: Colors.grey),
              ),
            ),
            const SizedBox(height: 6),
            Center(
              child: FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => Text(
                  snap.hasData ? 'الإصدار ${snap.data!.version}' : 'الإصدار',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.eco, color: Color(0xFF047857)),
                        SizedBox(width: 8),
                        Text('عن نباتي',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text(
                      'نباتي هو تطبيق زراعي ذكي يساعد المزارعين على تشخيص أمراض وآفات النباتات باستخدام الذكاء الاصطناعي، وتقديم توصيات زراعية دقيقة باللهجة المصرية.',
                      style: TextStyle(fontSize: 14, height: 1.7),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.star, color: Color(0xFFF59E0B)),
                        SizedBox(width: 8),
                        Text('المميزات',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    SizedBox(height: 12),
                    Text('• تشخيص فوري للآفات بالذكاء الاصطناعي',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• حاسبات ومخططات زراعية شاملة',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• حفظ البرامج في مزرعتي ومتابعتها',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• تصدير البرامج كملفات PDF',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• موسوعة زراعية شاملة ومتجددة',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• العمل بدون إنترنت مع المزامنة التلقائية',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                    Text('• تنبيهات فورية عن الآفات',
                        style: TextStyle(fontSize: 13, height: 1.8)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.support_agent, color: Color(0xFF047857)),
                        SizedBox(width: 8),
                        Text('التواصل والدعم',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Text('إشراف واستشارة:',
                        style: TextStyle(fontSize: 13, color: Colors.grey)),
                    const SizedBox(height: 4),
                    const Text('م. علي الدهشوري',
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openWhatsApp(context),
                        icon: const Icon(Icons.chat),
                        label: const Text('تواصل عبر واتساب'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF25D366),
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(45),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                '© ${DateTime.now().year} نباتي - جميع الحقوق محفوظة',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
