import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/offline_service.dart';
import 'services/notification_service.dart';
import 'utils/validators.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    try {
      await NotificationService.initialize();
      await NotificationService.subscribeToPestAlerts();
      final token = await NotificationService.getToken();
      debugPrint("🔑 FCM Token: $token");
    } catch (e) {
      debugPrint("خطأ في تهيئة الإشعارات: $e");
    }

  } catch (e) {
    debugPrint("Firebase initialization error: $e");
  }

  runApp(const AgriConsultantApp());
}

// ---------------- AgriConsultantApp ----------------
class AgriConsultantApp extends StatefulWidget {
  const AgriConsultantApp({super.key});

  @override
  State<AgriConsultantApp> createState() => _AgriConsultantAppState();
}

class _AgriConsultantAppState extends State<AgriConsultantApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasNet = !results.contains(ConnectivityResult.none);
      if (hasNet) {
        debugPrint("🌐 عاد الاتصال بالإنترنت، جاري المزامنة...");
        final synced = await OfflineService.syncPendingDiagnoses();
        if (synced > 0) {
          debugPrint("✅ تمت مزامنة $synced تشخيص");
        }
      } else {
        debugPrint("📴 انقطع الاتصال بالإنترنت");
      }
    });
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'نباتي',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF047857)),
        useMaterial3: true,
        fontFamily: 'Cairo',
      ),
      home: const SplashScreen(), // ✅ شاشة البداية
    );
  }
}

// ---------------- Splash Screen ----------------
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AuthWrapper()),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF047857),
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/icon/app_icon.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                const Text(
                  'نباتي',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 2,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'مستشارك الزراعي الذكي',
                  style: TextStyle(
                    fontSize: 16,
                    color: Color(0xFFFDE68A),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 50),
                const SizedBox(
                  width: 30,
                  height: 30,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
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

// ---------------- 0. التحقق من حالة تسجيل الدخول ----------------
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF047857)),
            ),
          );
        }

        if (snapshot.hasData && snapshot.data != null) {
          final user = snapshot.data!;
          
          String phone = "غير معروف";
          if (user.email != null && user.email!.contains('@')) {
            phone = user.email!.split('@').first;
          }

          String name = user.displayName ?? "مزارع";

          return MainNavigationScreen(
            userName: name,
            userPhone: phone,
          );
        }

        return const AuthScreen();
      },
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
                  const Icon(Icons.eco, size: 80, color: Color(0xFF047857)),
                  const SizedBox(height: 10),
                  const Text(
                    'نباتي',
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                  ),
                  const Text('مستشارك الزراعي الذكي',
                      style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 4),
                  const Text('إشراف: م. علي الدهشوري',
                      style: TextStyle(color: Color(0xFF047857), fontSize: 12)),
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
      HomeDashboard(userName: widget.userName, userPhone: widget.userPhone),
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
  final String userPhone;
  const HomeDashboard({super.key, required this.userName, required this.userPhone});

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
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => weatherStatusText = "⚠️ برجاء تشغيل GPS في هاتفك");
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() => weatherStatusText = "برجاء إعطاء صلاحية الموقع لمعرفة الطقس");
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => weatherStatusText = "⚠️ تم رفض صلاحية الموقع نهائياً، برجاء تفعيلها من الإعدادات");
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      debugPrint("📍 الإحداثيات: ${position.latitude}, ${position.longitude}");

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
      debugPrint("❌ خطأ في جلب الموقع: $e");
      setState(() => weatherStatusText = "⚠️ برجاء تشغيل GPS والانتظار قليلاً");
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
            const Text('نباتي - مستشارك الزراعي الذكي',
                style: TextStyle(color: Color(0xFFFDE68A), fontSize: 11)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProfileScreen(
                    userName: widget.userName,
                    userPhone: widget.userPhone,
                  ),
                ),
              );
            },
          ),
        ],
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
                      icon: Icons.history,
                      color: const Color(0xFFF59E0B),
                      title: 'سجل التشخيصات',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const HistoryScreen()));
                      }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
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
                const SizedBox(width: 12),
                const Expanded(child: SizedBox()),
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
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                'اختر مصدر الصورة',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFF047857), size: 30),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFF047857), size: 30),
              title: const Text('اختيار من المعرض'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromSource(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFromSource(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (pickedFile != null) {
        setState(() => _imageFile = File(pickedFile.path));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح الكاميرا أو المعرض')),
        );
      }
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

  Future<void> _submit() async {
    final question = _questionCtrl.text.trim();
    if (question.isEmpty && _imageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('برجاء كتابة سؤالك أو إرفاق صورة أولاً')),
      );
      return;
    }

    if (_apiKey.isEmpty) {
      setState(() {
        _diagnosis = 'خطأ في الإعدادات: مفتاح API (GEMINI_API_KEY) غير موجود.\nيرجى التأكد من تمرير المفتاح أثناء عملية البناء (Build) باستخدام --dart-define.';
      });
      return;
    }

    final hasInternet = await OfflineService.hasInternet();
    if (!hasInternet) {
      setState(() {
        _diagnosis = '⚠️ لا يوجد اتصال بالإنترنت حالياً.\nتم حفظ سؤالك وسيتم إرساله تلقائياً عند عودة الاتصال.';
      });
      await OfflineService.saveDiagnosis(
        userName: widget.userName,
        userPhone: widget.userPhone,
        question: question,
        imagePath: _imageFile?.path,
        diagnosis: 'في انتظار الاتصال بالإنترنت...',
      );
      return;
    }

    setState(() {
      _loading = true;
      _diagnosis = "";
    });

    int maxRetries = 3;
    int attempt = 0;
    bool success = false;

    while (attempt < maxRetries && !success) {
      try {
        attempt++;
        
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
        
        await OfflineService.saveDiagnosis(
          userName: widget.userName,
          userPhone: widget.userPhone,
          question: question,
          imagePath: _imageFile?.path,
          diagnosis: _diagnosis,
        );
        
        success = true;

      } catch (e) {
        if (attempt >= maxRetries) {
          setState(() {
            _diagnosis = 'عذراً، خدمة الذكاء الاصطناعي مشغولة حالياً بسبب الضغط العالي.\nبرجاء المحاولة مرة أخرى بعد قليل.';
          });
          print("❌ فشل الاتصال بالذكاء الاصطناعي بعد $attempt محاولات. الخطأ: $e");
        } else {
          print("⚠️ المحاولة رقم $attempt فشلت. جاري إعادة المحاولة...");
          await Future.delayed(const Duration(seconds: 2));
        }
      }
    }

    setState(() {
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الفحص الذكي للآفات', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryScreen()),
              );
            },
          ),
        ],
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

// ---------------- 5. شاشة سجل التشخيصات ----------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final items = await OfflineService.getAllDiagnoses();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Future<void> _deleteOne(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح التشخيص'),
        content: const Text('هل أنت متأكد من مسح هذا التشخيص؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await OfflineService.deleteDiagnosis(id);
      _loadHistory();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('سجل التشخيصات', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('مسح السجل'),
                  content: const Text('هل أنت متأكد من مسح كل السجل؟'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('إلغاء'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('مسح', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                await OfflineService.clearAll();
                _loadHistory();
              }
            },
          ),
        ],
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _items.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا يوجد سجل حتى الآن',
                            style: TextStyle(fontSize: 16, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _items.length,
                    itemBuilder: (context, index) {
                      final item = _items[index];
                      final date = item['createdAt']?.toString() ?? '';
                      String dateFormatted = date;
                      try {
                        final dt = DateTime.parse(date);
                        dateFormatted = "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute}";
                      } catch (_) {}

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.eco, color: Color(0xFF047857)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      item['question']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold, fontSize: 14),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                              const Divider(),
                              Text(
                                item['diagnosis']?.toString() ?? '',
                                style: const TextStyle(fontSize: 13, height: 1.5),
                                maxLines: 4,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(dateFormatted,
                                      style: const TextStyle(
                                          fontSize: 11, color: Colors.grey)),
                                  Row(
                                    children: [
                                      if (item['isSynced'] == 0)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 8),
                                          child: Text('⏳ في انتظار المزامنة',
                                              style: TextStyle(
                                                  fontSize: 11, color: Colors.orange)),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete,
                                            color: Colors.red, size: 20),
                                        onPressed: () =>
                                            _deleteOne(item['id'] as int),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(),
                                      ),
                                    ],
                                  ),
                                ],
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
}

// ---------------- 6. شاشة الملف الشخصي ----------------
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const ProfileScreen({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameCtrl;
  bool _saving = false;
  final _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.userName);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final newName = _nameCtrl.text.trim();
    if (newName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('الاسم لا يمكن أن يكون فارغاً')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await user.updateDisplayName(newName);
        await user.reload();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم تحديث الاسم بنجاح'),
              backgroundColor: Color(0xFF047857),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ: $e')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الخروج'),
        content: const Text('هل أنت متأكد من تسجيل الخروج؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('خروج', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _authService.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الملف الشخصي', style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: CircleAvatar(
                radius: 50,
                backgroundColor: const Color(0xFF047857).withOpacity(0.15),
                child: const Icon(Icons.person, size: 60, color: Color(0xFF047857)),
              ),
            ),
            const SizedBox(height: 24),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Color(0xFF047857)),
                        SizedBox(width: 8),
                        Text('الاسم',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _nameCtrl,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _saving ? null : _saveName,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Icon(Icons.save),
                        label: Text(_saving ? 'جاري الحفظ...' : 'حفظ الاسم'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF047857),
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
            const SizedBox(height: 16),

            Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.phone, color: Color(0xFF047857)),
                title: const Text('رقم الموبايل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.userPhone),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- 7. شاشة المقالات ----------------
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
