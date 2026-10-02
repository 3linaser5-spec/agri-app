import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AgriConsultantApp());
}

class AgriConsultantApp extends StatelessWidget {
  const AgriConsultantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'المستشار الزراعي',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF047857)),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const AuthScreen(),
    );
  }
}

// ---------------- 1. تسجيل الدخول ----------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _handleAuth() async {
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final name = _nameController.text.trim();

    if (phone.isEmpty || password.isEmpty || (!isLogin && name.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى ملء جميع الحقول المطلوبة')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final userDoc = FirebaseFirestore.instance.collection('users').doc(phone);
      
      if (isLogin) {
        // تم إضافة حد زمني (Timeout) لمنع التعليق
        final snapshot = await userDoc.get().timeout(const Duration(seconds: 10));
        
        if (snapshot.exists && snapshot.data()?['password'] == password) {
          userDoc.update({'lastLogin': FieldValue.serverTimestamp()});
          _navigateToMain(snapshot.data()?['name'] ?? 'مزارع', phone);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('رقم الموبايل أو كلمة المرور غير صحيحة')),
          );
        }
      } else {
        // تم إضافة حد زمني (Timeout) لمنع التعليق
        await userDoc.set({
          'name': name,
          'phone': phone,
          'password': password,
          'createdAt': FieldValue.serverTimestamp(),
          'lastLogin': FieldValue.serverTimestamp(),
        }).timeout(const Duration(seconds: 10));
        
        _navigateToMain(name, phone);
      }
    } catch (e) {
      // إظهار رسالة عند ضعف الإنترنت أو انتهاء الوقت
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ضعف في الاتصال بالشبكة، يرجى المحاولة مرة أخرى.')),
      );
    } finally {
      // إيقاف مؤشر التحميل بأمان
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _navigateToMain(String name, String phone) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MainNavigationScreen(userName: name, userPhone: phone),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.eco, size: 70, color: Color(0xFF047857)),
                const SizedBox(height: 10),
                const Text(
                  'المستشار الزراعي الذكي',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                ),
                const Text('إشراف واستشارة: م. علي الدهشوري', style: TextStyle(color: Colors.black54, fontSize: 13)),
                const SizedBox(height: 30),
                if (!isLogin) ...[
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'الاسم بالكامل',
                      prefixIcon: const Icon(Icons.person),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: 'رقم الموبايل',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'كلمة المرور',
                    prefixIcon: const Icon(Icons.lock),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleAuth,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF047857),
                    minimumSize: const Size.fromHeight(50),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isLogin ? 'تسجيل الدخول' : 'إنشاء حساب جديد',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
                const SizedBox(height: 14),
                TextButton(
                  onPressed: () => setState(() => isLogin = !isLogin),
                  child: Text(
                    isLogin ? 'ليس لديك حساب؟ سجل الآن' : 'لديك حساب بالفعل؟ تسجيل الدخول',
                    style: const TextStyle(color: Color(0xFF047857), fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- 2. شاشات التنقل ----------------
class MainNavigationScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const MainNavigationScreen({super.key, required this.userName, required this.userPhone});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final screens = [
      HomeDashboard(userName: widget.userName),
      AiScannerScreen(userName: widget.userName, userPhone: widget.userPhone),
      const ArticlesAndGuidesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF047857),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية والطقس'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'فحص الآفات الذكي'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'المقالات والتسميد'),
        ],
      ),
    );
  }
}

// ---------------- 3. الرئيسية والطقس ----------------
class HomeDashboard extends StatelessWidget {
  final String userName;
  const HomeDashboard({super.key, required this.userName});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مرحباً بك، $userName', style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Text('مستشارك الزراعي بإشراف م. علي الدهشوري', style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11)),
          ],
        ),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: const Color(0xFFECFDF5),
              child: const Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.between,
                      children: [
                        Text('حالة الطقس اليوم', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text('درجة الحرارة: 28°م | الرطوبة: 45%', style: TextStyle(color: Colors.black87)),
                    Divider(height: 20),
                    Row(
                      children: [
                        Icon(Icons.water_drop, color: Colors.blue, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'توصية الري: اعتدال الطقس مناسب للري الصباحي الباكر مع تجنب الري وقت الظهيرة.',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 4. شاشة الفحص + الصوت + إرسال واتساب ----------------
class AiScannerScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const AiScannerScreen({super.key, required this.userName, required this.userPhone});

  @override
  State<AiScannerScreen> createState() => _AiScannerScreenState();
}

class _AiScannerScreenState extends State<AiScannerScreen> {
  final _questionCtrl = TextEditingController();
  bool _loading = false;
  String _diagnosis = "";
  final FlutterTts _flutterTts = FlutterTts();
  bool _isPlayingVoice = false;

  @override
  void initState() {
    super.initState();
    _initVoiceSettings();
  }

  void _initVoiceSettings() async {
    await _flutterTts.setLanguage("ar-EG");
    await _flutterTts.setSpeechRate(0.45);
    await _flutterTts.setPitch(1.0);
    _flutterTts.setCompletionHandler(() {
      setState(() => _isPlayingVoice = false);
    });
  }

  Future<void> _toggleVoicePlayback(String text) async {
    if (_isPlayingVoice) {
      await _flutterTts.stop();
      setState(() => _isPlayingVoice = false);
    } else {
      if (text.isNotEmpty) {
        setState(() => _isPlayingVoice = true);
        await _flutterTts.speak(text);
      }
    }
  }

  Future<void> _sendToEngineerWhatsApp() async {
    const engineerPhone = "+201126920209"; 
    final message = """
السلام عليكم يا بشمهندس علي، معي استشارة زراعية:
🌱 *اسم المزارع:* ${widget.userName}
📞 *رقم الهاتف:* ${widget.userPhone}
❓ *المشكلة الزراعية:* ${_questionCtrl.text.trim()}
📋 *تشخيص المستشار الذكي:*
$_diagnosis
""";
    final url = "https://wa.me/$engineerPhone?text=${Uri.encodeComponent(message)}";
    final uri = Uri.parse(url);

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')),
      );
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty) return;

    if (_isPlayingVoice) {
      await _flutterTts.stop();
      setState(() => _isPlayingVoice = false);
    }

    setState(() {
      _loading = true;
      _diagnosis = "";
    });

    try {
      const apiKey = String.fromEnvironment('GEMINI_API_KEY'); 
      
      final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);
      final prompt = """
أنت مستشار زراعي خبير تعمل تحت إشراف وتوجيهات المهندس علي الدهشوري.
سؤال المزارع: $question
اشرح للمزارع التشخيص بدقة وبلهجة مصرية عامية واضحة ومبسطة وسهلة للنطق في التسجيل الصوتي.
اذكر اسم المرض أو النقص، العلاج المقترح، جرعة الرش، ونصيحة التسميد والري بالعامية المصرية.
""";

      final res = await model.generateContent([Content.text(prompt)]);
      final answer = res.text ?? "تعذر استخراج التشخيص.";

      await FirebaseFirestore.instance.collection('ai_queries').add({
        'userId': widget.userPhone,
        'userName': widget.userName,
        'phone': widget.userPhone,
        'question': question,
        'aiDiagnosis': answer,
        'timestamp': FieldValue.serverTimestamp(),
        'engineerNote': null,
      });

      setState(() => _diagnosis = answer);
    } catch (e) {
      setState(() => _diagnosis = "خطأ في الاتصال: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        title: const Text('الفحص الذكي للآفات', style: TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _questionCtrl,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: 'اكتب وصفاً للأعراض أو سؤالك الزراعي...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text(_loading ? 'جاري الفحص...' : 'إرسال للاستشارة الزراعية', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), padding: const EdgeInsets.all(14)),
            ),
            if (_diagnosis.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.green),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.verified, color: Color(0xFF047857), size: 20),
                        SizedBox(width: 8),
                        Text('تشخيص وتوصية المستشار الزراعي:', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      ],
                    ),
                    const Divider(height: 18),
                    Text(_diagnosis, style: const TextStyle(fontSize: 13, height: 1.6)),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      onPressed: () => _toggleVoicePlayback(_diagnosis),
                      icon: Icon(
                        _isPlayingVoice ? Icons.stop_circle : Icons.volume_up_rounded,
                        color: Colors.white,
                      ),
                      label: Text(
                        _isPlayingVoice ? 'إيقاف الصوت' : '🔊 استمع للتشخيص (باللهجة المصرية)',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isPlayingVoice ? Colors.red[700] : const Color(0xFF047857),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _sendToEngineerWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text(
                        '💬 تأكيد الاستشارة مع م. علي الدهشوري عبر واتساب',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ],
                ),
              )
            ]
          ],
        ),
      ),
    );
  }
}

// ---------------- 5. المقالات والتسميد ----------------
class ArticlesAndGuidesScreen extends StatelessWidget {
  const ArticlesAndGuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final articles = [
      {
        'title': 'برنامج تسميد الطماطم من الزراعة حتى الحصاد',
        'category': 'برامج التسميد',
        'readTime': '4 دقائق',
        'content': 'تنشيط الجذور أولاً بحامض الفوسفوريك وهيومات البوتاسيوم، ثم التسميد النيتروجيني مع الاهتمام بالكالسيوم والبورون لمنع تشوه الثمار...'
      },
      {
        'title': 'القواعد الذهبية لري أشجار الموالح في الصيف',
        'category': 'إرشادات الري',
        'readTime': '3 دقائق',
        'content': 'الري في الصباح الباكر أو ليلاً وتجنب فترات الظهيرة لتقليل الإجهاد الحراري ومنع تساقط الثمار الصغيرة...'
      },
      {
        'title': 'دليل مكافحة سوسة النخيل الحمراء',
        'category': 'وقاية ومكافحة',
        'readTime': '5 دقائق',
        'content': 'المتابعة الدورية لقواعد النخيل وسد الجروح بعد التقليم والحقن بالمبيدات الجهازية المعتمدة فوراً...'
      },
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        title: const Text('الموسوعة الزراعية والمدونات', style: TextStyle(color: Colors.white, fontSize: 17)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: articles.length,
          itemBuilder: (context, index) {
            final item = articles[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                title: Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(item['content']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                  ],
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
              ),
            );
          },
        ),
      ),
    );
  }
}
