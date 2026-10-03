import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'utils/validators.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    
    // تفعيل الحماية App Check (معلقة مؤقتاً عشان التطبيق يفتح)
    // await FirebaseAppCheck.instance.activate(
    //   androidProvider: AndroidProvider.debug,
    // );
    
  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

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

// ---------------- 1. تسجيل الدخول (محمي بـ Firebase Auth) ----------------
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  bool isLogin = true;
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  final _authService = AuthService();

  Future<void> _handleAuth() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    String? errorMessage;

    if (isLogin) {
      errorMessage = await _authService.login(
        phone: _phoneController.text,
        password: _passwordController.text,
      );
    } else {
      errorMessage = await _authService.register(
        name: _nameController.text,
        phone: _phoneController.text,
        password: _passwordController.text,
      );
    }

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
      return;
    }

    // نجاح - نروح للشاشة الرئيسية
    final displayName = isLogin
        ? 'مزارع'
        : _nameController.text.trim();

    _navigateToMain(displayName, _phoneController.text.trim());
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
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    super.dispose();
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
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.eco, size: 70, color: Color(0xFF047857)),
                  const SizedBox(height: 10),
                  const Text(
                    'المستشار الزراعي الذكي',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                  const Text('إشراف واستشارة: م. علي الدهشوري',
                      style: TextStyle(color: Colors.black54, fontSize: 13)),
                  const SizedBox(height: 30),
                  if (!isLogin) ...[
                    TextFormField(
                      controller: _nameController,
                      validator: Validators.name,
                      decoration: InputDecoration(
                        labelText: 'الاسم بالكامل',
                        prefixIcon: const Icon(Icons.person),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    validator: Validators.phone,
                    decoration: InputDecoration(
                      labelText: 'رقم الموبايل',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    validator: Validators.password,
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
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white),
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

// ---------------- 3. الرئيسية والطقس ----------------
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

      Position position =
          await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m');

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

  Widget _buildQuickActionCard(
      {required IconData icon,
      required Color color,
      required String title,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0, 2))
            ]),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(title,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
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
            Text('مرحباً بك، ${widget.userName}',
                style: const TextStyle(color: Colors.white, fontSize: 16)),
            const Text('مستشارك الزراعي بإشراف م. علي الدهشوري',
                style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11)),
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
                        Text('حالة الطقس في موقعك',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(weatherStatusText,
                        style: const TextStyle(
                            color: Colors.black87, fontWeight: FontWeight.bold)),
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
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF047857)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text('الوصول السريع',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                      icon: Icons.menu_book,
                      color: const Color(0xFF047857),
                      title: 'برامج التسميد',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const ArticlesAndGuidesScreen()));
                      }),
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
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                              content: Text('حدث خطأ أثناء فتح الواتساب')));
                        }
                      }),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const Text('نصيحة اليوم 💡',
                style: TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF047857))),
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

// ---------------- 4. شاشة الفحص الذكي ----------------
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

  // قراءة مفتاح API الخاص بـ Gemini من إعدادات البناء
  final String _apiKey = const String.fromEnvironment('GEMINI_API_KEY');

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
      if (mounted) setState(() => _isPlayingVoice = false);
    });
  }

  Future<void> _pickImage() async {
    try {
      final XFile? pickedFile =
          await _picker.pickImage(source: ImageSource.camera, imageQuality: 80);
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح الكاميرا')));
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')));
    }
  }

  @override
  void dispose() {
    _flutterTts.stop();
    _questionCtrl.dispose(); 
    super.dispose();
  }

  // ✅ دالة الإرسال بعد التعديل والإكمال
  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة سؤالك أو إرفاق صورة أولاً')),
      );
      return;
    }

    // ✅ 1. التأكد من وجود مفتاح الـ API قبل الإرسال
    if (_apiKey.isEmpty) {
      setState(() {
        _diagnosis = 'خطأ في الإعدادات: مفتاح API (GEMINI_API_KEY) غير موجود.\nيرجى التأكد من تمرير المفتاح أثناء عملية البناء (Build) باستخدام --dart-define.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _diagnosis = "";
    });

    try {
      // ✅ 2. التعديل هنا: استخدام نموذج gemini-3.8-flash
      final model = GenerativeModel(
        model: 'gemini-3.8-flash', 
        apiKey: _apiKey,
      );

      final prompt = """
أنت مهندس زراعي خبير ومستشار زراعي مصري.
قم بتشخيص الحالة التالية وقدم توصياتك الزراعية باللغة العربية وباللهجة المصرية المبسطة.
سؤال المزارع: $question
""";

      List<Part> parts = [TextPart(prompt)];

      // لو فيه صورة مرفقة، نضيفها للطلب
      if (_imageFile != null) {
        final imageBytes = await _imageFile!.readAsBytes();
        parts.add(DataPart('image/jpeg', imageBytes));
      }

      final response = await model.generateContent([
        Content.multi(parts)
      ]);

      setState(() {
        _diagnosis = response.text ?? 'لم يتمكن الذكاء الاصطناعي من تقديم تشخيص.';
      });
    } catch (e) {
      // ✅ 3. تحسين رسالة الخطأ لتكون أوضح
      setState(() {
        _diagnosis = 'حدث خطأ أثناء الاتصال بالذكاء الاصطناعي.\nتأكد من أن اسم النموذج صحيح وأن مفتاح API فعال.\nتفاصيل الخطأ: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفحص الذكي للآفات', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _questionCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'اكتب مشكلة النبات أو الآفة اللي بتواجهك...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('إرفاق صورة'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_imageFile != null)
                    const Text('تم إرفاق صورة ✅', style: TextStyle(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال للاستشارة الزراعية',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              if (_diagnosis.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  color: const Color(0xFFECFDF5),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.check_circle, color: Color(0xFF047857)),
                            SizedBox(width: 8),
                            Text('تشخيص وتوصية المستشار الزراعي:',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                    color: Color(0xFF047857))),
                          ],
                        ),
                        const Divider(),
                        Text(_diagnosis,
                            style: const TextStyle(fontSize: 14, height: 1.6)),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () => _toggleVoicePlayback(_diagnosis),
                                icon: Icon(_isPlayingVoice
                                    ? Icons.stop
                                    : Icons.volume_up),
                                label: Text(_isPlayingVoice
                                    ? 'إيقاف الصوت'
                                    : 'استمع للتشخيص (باللهجة المصرية)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          onPressed: _sendToEngineerWhatsApp,
                          icon: const Icon(Icons.chat),
                          label: const Text('تأكيد الاستشارة مع م. علي الدهشوري'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF25D366),
                            minimumSize: const Size.fromHeight(45),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- 5. شاشة المقالات ----------------
class ArticlesAndGuidesScreen extends StatelessWidget {
  const ArticlesAndGuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموسوعة الزراعية', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: const Center(
        child: Text('قسم المقالات والإرشادات الزراعية (قيد التطوير)'),
      ),
    );
  }
}
