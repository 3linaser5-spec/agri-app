import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ضعف في الاتصال بالشبكة، يرجى المحاولة مرة أخرى.')),
      );
    } finally {
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
          BottomNavigationBarItem(icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.camera_alt), label: 'فحص الآفات'),
          BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'الموسوعة'),
        ],
      ),
    );
  }
}

// ---------------- 3. الرئيسية والطقس الفعلي والوصول السريع ----------------
class HomeDashboard extends StatefulWidget {
  final String userName;
  const HomeDashboard({super.key, required this.userName});

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String weatherTemp = "--";
  String weatherHumidity = "--";
  String weatherStatusText = "جاري تحديد موقعك وجلب الطقس...";
  bool isWeatherLoaded = false;

  @override
  void initState() {
    super.initState();
    _fetchWeatherByLocation();
  }

  Future<void> _fetchWeatherByLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => weatherStatusText = "برجاء إعطاء صلاحية الموقع لمعرفة الطقس");
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final url = Uri.parse('https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m');
      
      final response = await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherTemp = data['current']['temperature_2m'].toString();
          weatherHumidity = data['current']['relative_humidity_2m'].toString();
          weatherStatusText = "درجة الحرارة: $weatherTemp°م | الرطوبة: $weatherHumidity%";
          isWeatherLoaded = true;
        });
      } else {
        setState(() => weatherStatusText = "تعذر جلب بيانات الطقس حالياً");
      }
    } catch (e) {
      setState(() => weatherStatusText = "برجاء تشغيل الـ GPS (الموقع) في هاتفك");
    }
  }

  Widget _buildQuickActionCard({required IconData icon, required Color color, required String title, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('مرحباً بك، ${widget.userName}', style: const TextStyle(color: Colors.white, fontSize: 16)),
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
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('حالة الطقس في موقعك', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(weatherStatusText, style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                    const Divider(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.water_drop, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            isWeatherLoaded 
                                ? (double.parse(weatherTemp) > 30 
                                    ? 'توصية الري: الطقس حار، يفضل الري في الصباح الباكر أو ليلاً لتجنب تبخر المياه.'
                                    : 'توصية الري: اعتدال الطقس مناسب للري، يرجى مراقبة رطوبة التربة.')
                                : 'جاري تحليل التوصية...',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('الوصول السريع', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.menu_book,
                    color: const Color(0xFF047857),
                    title: 'برامج التسميد',
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ArticlesAndGuidesScreen()));
                    }
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                    icon: Icons.chat,
                    color: const Color(0xFF25D366),
                    title: 'الدعم الفني',
                    onTap: () async {
                      final uri = Uri.parse("https://wa.me/201126920209");
                      try {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('حدث خطأ أثناء فتح الواتساب')));
                      }
                    }
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('نصيحة اليوم 💡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
            const SizedBox(height: 12),
            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              color: Colors.amber[50],
              elevation: 0,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.eco, color: Colors.amber[800], size: 28),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'تجنب رش المبيدات في وقت الظهيرة أو عند ارتفاع درجات الحرارة لتفادي احتراق الأوراق، وأفضل وقت للرش هو الصباح الباكر أو بعد كسر حدة الشمس عصراً.',
                        style: TextStyle(fontSize: 13, height: 1.6, color: Colors.black87),
                      ),
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

// ---------------- 4. شاشة الفحص بالكاميرا + الصوت عبر الاتصال المباشر ----------------
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
  File? _imageFile;
  final ImagePicker _picker = ImagePicker();

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
      if(mounted) setState(() => _isPlayingVoice = false);
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح الكاميرا')));
    }
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
    const engineerPhone = "201126920209"; 
    final message = """
السلام عليكم يا بشمهندس علي، معي استشارة زراعية:
🌱 *اسم المزارع:* ${widget.userName}
❓ *المشكلة الزراعية:* ${_questionCtrl.text.trim()}
📋 *تشخيص المستشار الذكي:*
$_diagnosis
""";
    
    final uri = Uri.parse("https://wa.me/$engineerPhone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')));
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('الرجاء كتابة سؤال أو التقاط صورة')));
      return;
    }

    if (_isPlayingVoice) {
      await _flutterTts.stop();
      setState(() => _isPlayingVoice = false);
    }

    setState(() {
      _loading = true;
      _diagnosis = "";
    });

    try {
      const apiKey = "AQ.Ab8RN6LCnJxwm9EYrmcpesabXdBU-hkkn25pz6mKQGbx3T-9Fw";
      final url = Uri.parse('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent?key=$apiKey');

      final promptText = """
أنت مستشار زراعي خبير تعمل تحت إشراف وتوجيهات المهندس علي الدهشوري.
سؤال المزارع: ${question.isEmpty ? "قم بفحص هذه الصورة وتحديد المشكلة الزراعية" : question}
اشرح للمزارع التشخيص بدقة وبلهجة مصرية عامية واضحة ومبسطة.
اذكر اسم المرض، العلاج المقترح، وجرعة الرش ونصيحة التسميد والري بالعامية.
""";

      List<Map<String, dynamic>> parts = [
        {"text": promptText}
      ];

      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        final base64Image = base64Encode(bytes);
        parts.add({
          "inline_data": {
            "mime_type": "image/jpeg",
            "data": base64Image
          }
        });
      }

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": parts
            }
          ]
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final answer = data['candidates'][0]['content']['parts'][0]['text'] ?? "تعذر استخراج التشخيص.";

        await FirebaseFirestore.instance.collection('ai_queries').add({
          'userId': widget.userPhone,
          'userName': widget.userName,
          'question': question,
          'hasImage': _imageFile != null,
          'aiDiagnosis': answer,
          'timestamp': FieldValue.serverTimestamp(),
        });

        setState(() => _diagnosis = answer);
      } else {
        setState(() => _diagnosis = "خطأ من السيرفر (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      setState(() => _diagnosis = "سبب الخطأ: $e");
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
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextField(
                    controller: _questionCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'اكتب وصفاً للمشكلة أو الأعراض...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: _pickImage,
                  child: Container(
                    height: 85,
                    width: 70,
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      border: Border.all(color: const Color(0xFF047857)),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.camera_alt, color: Color(0xFF047857), size: 30),
                        SizedBox(height: 4),
                        Text('تصوير', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_imageFile != null) ...[
              const SizedBox(height: 10),
              Stack(
                alignment: Alignment.topRight,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(_imageFile!, height: 150, width: double.infinity, fit: BoxFit.cover),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                    onPressed: () => setState(() => _imageFile = null),
                  )
                ],
              ),
            ],
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _loading ? null : _submit,
              icon: const Icon(Icons.send, color: Colors.white),
              label: Text(_loading ? 'جاري الفحص الدقيق...' : 'إرسال للاستشارة الزراعية', style: const TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF047857), padding: const EdgeInsets.all(14)),
            ),
            if (_diagnosis.isNotEmpty) ...[
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(14), border: Border.all(color: Colors.green)),
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
                      icon: Icon(_isPlayingVoice ? Icons.stop_circle : Icons.volume_up_rounded, color: Colors.white),
                      label: Text(_isPlayingVoice ? 'إيقاف الصوت' : '🔊 استمع للتشخيص (باللهجة المصرية)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: _isPlayingVoice ? Colors.red[700] : const Color(0xFF047857), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    ),
                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _sendToEngineerWhatsApp,
                      icon: const Icon(Icons.chat, color: Colors.white),
                      label: const Text('💬 تأكيد الاستشارة مع م. علي الدهشوري', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
                      style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF25D366), padding: const EdgeInsets.symmetric(vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
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
        'content': 'لنجاح زراعة الطماطم، يجب البدء بتنشيط الجذور باستخدام حامض الفوسفوريك وهيومات البوتاسيوم بمعدل 2 لتر للفدان. بعد أسبوعين نبدأ بالتسميد النيتروجيني لزيادة المجموع الخضري. في مرحلة التزهير، من الضروري الاهتمام برش الكالسيوم والبورون لمنع تشوه الثمار وتقليل تساقط الأزهار، مع تقليل الري تدريجياً لتجنب عفن الجذور.'
      },
      {
        'title': 'القواعد الذهبية لري أشجار الموالح في الصيف',
        'category': 'إرشادات الري',
        'readTime': '3 دقائق',
        'content': 'أشجار الموالح حساسة جداً للإجهاد الحراري في الصيف. القاعدة الأهم هي الري في الصباح الباكر جداً أو ليلاً، وتجنب فترات الظهيرة تماماً لأن المياه الساخنة تؤدي لاختناق الجذور وتساقط الثمار الصغيرة (الخف الصيفي). يفضل تقريب فترات الري مع تقليل الكمية في كل مرة بدلاً من التعطيش ثم الغمر.'
      },
      {
        'title': 'دليل مكافحة سوسة النخيل الحمراء',
        'category': 'وقاية ومكافحة',
        'readTime': '5 دقائق',
        'content': 'سوسة النخيل هي العدو الأول للنخل. تبدأ المكافحة بالمتابعة الدورية كل أسبوعين لقواعد النخيل. يجب سد أي جروح فوراً بعد التقليم باستخدام الطين أو عجينة بوردو لمنع الحشرة من وضع البيض. في حالة اكتشاف إصابة، يجب الحقن الفوري بالمبيدات الجهازية المعتمدة وتغطية مكان الحقن جيداً لمنع خروج الأبخرة.'
      },
      {
        'title': 'أسباب إصفرار أوراق المانجو وعلاجها',
        'category': 'أمراض وعلاج',
        'readTime': '3 دقائق',
        'content': 'إصفرار أوراق المانجو الحديثة غالباً ما يكون بسبب نقص عنصر الحديد أو الزنك، خاصة في الأراضي الجيرية. يتم العلاج برش الحديد المخلبي (EDDHA) بمعدل 1.5 جرام لكل لتر ماء. أما إذا كان الإصفرار في الأوراق السفلية القديمة، فهو غالباً نقص نيتروجين، ويحتاج لدعم سمادي في مياه الري.'
      },
      {
        'title': 'كيفية تجهيز التربة قبل زراعة المحاصيل الشتوية',
        'category': 'تجهيز التربة',
        'readTime': '4 دقائق',
        'content': 'التجهيز الجيد يبدأ بالحرث العميق المتعامد لتهوية التربة وتعريضها للشمس للقضاء على بذور الحشائش والآفات. يجب إضافة السماد البلدي المتحلل بمعدل 20 متر مكعب للفدان مع السوبر فوسفات والكبريت الزراعي قبل التخطيط، مما يضمن تدفئة الجذور وتوفير العناصر الغذائية تدريجياً للنبات.'
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
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ArticleDetailScreen(article: item),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item['category']!, style: const TextStyle(color: Color(0xFF047857), fontSize: 11, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 4),
                            Text(item['title']!, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                            const SizedBox(height: 6),
                            Text(item['content']!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ---------------- 6. شاشة تفاصيل المقال ----------------
class ArticleDetailScreen extends StatelessWidget {
  final Map<String, String> article;
  const ArticleDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(article['category']!, style: const TextStyle(color: Colors.white, fontSize: 16)),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(article['title']!, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF047857))),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 16, color: Colors.grey),
                  const SizedBox(width: 6),
                  Text('مدة القراءة: ${article['readText'] ?? article['readTime']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                ],
              ),
              const Divider(height: 30, thickness: 1),
              Text(article['content']!, style: const TextStyle(fontSize: 16, height: 1.9, color: Colors.black87)),
            ],
          ),
        ),
      ),
    );
  }
}
