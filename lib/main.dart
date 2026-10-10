import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
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
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:convert';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/offline_service.dart';
import 'services/notification_service.dart';
import 'services/calculator_service.dart';
import 'services/encyclopedia_service.dart';
import 'models/encyclopedia_model.dart';
import 'screens/admin/admin_panel_screen.dart';
import 'screens/calculators/calculator_hub_screen.dart';
import 'screens/farm/my_farm_screen.dart';
import 'utils/validators.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    await ThemeController.load();

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

// ---------------- VersionService ----------------
class VersionService {
  static const String versionUrl =
      "https://raw.githubusercontent.com/3linaser5-spec/agri-app/main/version.json";

  static Future<Map<String, dynamic>?> fetchVersionInfo() async {
    try {
      final response = await http
          .get(Uri.parse(versionUrl))
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        return json.decode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      debugPrint("❌ خطأ في قراءة معلومات النسخة: $e");
      return null;
    }
  }

  static Future<Map<String, dynamic>?> checkUpdate() async {
    try {
      final info = await fetchVersionInfo();
      if (info == null) return null;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final latestVersion = info['latest_version'] as String? ?? currentVersion;
      final minVersion = info['min_version'] as String? ?? currentVersion;

      final hasNewVersion = _compareVersions(latestVersion, currentVersion) > 0;
      final isMandatory = _compareVersions(currentVersion, minVersion) < 0;

      if (hasNewVersion || isMandatory) {
        return {
          'mandatory': isMandatory,
          'version': latestVersion,
          'downloadUrl': info['download_url'] ?? '',
          'changelog': info['changelog'] ?? '',
        };
      }
      return null;
    } catch (e) {
      debugPrint("❌ خطأ في فحص التحديث: $e");
      return null;
    }
  }

  static int _compareVersions(String v1, String v2) {
    final a = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final b = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final len = a.length > b.length ? a.length : b.length;
    for (int i = 0; i < len; i++) {
      final x = i < a.length ? a[i] : 0;
      final y = i < b.length ? b[i] : 0;
      if (x != y) return x - y;
    }
    return 0;
  }

  static Future<void> downloadAndInstall({
    required String url,
    required Function(double progress) onProgress,
    required Function(String filePath) onComplete,
    required Function(String error) onError,
  }) async {
    try {
      if (Platform.isAndroid) {
        final installStatus = await Permission.requestInstallPackages.status;
        if (!installStatus.isGranted) {
          await Permission.requestInstallPackages.request();
        }
      }

      final dir = await getExternalStorageDirectory();
      final filePath = "${dir!.path}/app-release.apk";

      final oldFile = File(filePath);
      if (await oldFile.exists()) {
        await oldFile.delete();
      }

      final dio = Dio();
      await dio.download(
        url,
        filePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            onProgress(received / total);
          }
        },
      );

      onComplete(filePath);
      await OpenFilex.open(filePath);
    } catch (e) {
      onError(e.toString());
    }
  }
}

// ---------------- UpdateDialog ----------------
class UpdateDialog extends StatefulWidget {
  final String version;
  final String changelog;
  final String downloadUrl;
  final bool mandatory;

  const UpdateDialog({
    super.key,
    required this.version,
    required this.changelog,
    required this.downloadUrl,
    required this.mandatory,
  });

  @override
  State<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<UpdateDialog> {
  bool _downloading = false;
  double _progress = 0.0;
  String? _error;

  Future<void> _startDownload() async {
    setState(() {
      _downloading = true;
      _progress = 0.0;
      _error = null;
    });

    await VersionService.downloadAndInstall(
      url: widget.downloadUrl,
      onProgress: (progress) {
        if (mounted) setState(() => _progress = progress);
      },
      onComplete: (filePath) {
        if (mounted) {
          setState(() => _downloading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ تم التحميل! اتبع تعليمات التثبيت.'),
              backgroundColor: Color(0xFF047857),
              duration: Duration(seconds: 4),
            ),
          );
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _downloading = false;
            _error = "فشل التحميل. تأكد من الإنترنت وحاول مرة أخرى.";
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => !widget.mandatory && !_downloading,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF047857).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.system_update_alt,
                    color: Color(0xFF047857)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.mandatory ? 'تحديث إجباري متاح' : 'تحديث جديد متاح',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('الإصدار الجديد: ${widget.version}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857))),
                const SizedBox(height: 12),
                const Text('التغييرات:',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(widget.changelog,
                    style: const TextStyle(fontSize: 13, height: 1.6)),
                const SizedBox(height: 16),
                if (_downloading) ...[
                  const Text('جاري التحميل...',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _progress,
                      minHeight: 10,
                      backgroundColor: Colors.grey.shade200,
                      color: const Color(0xFF047857),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text('${(_progress * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.bold)),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_error!,
                              style: const TextStyle(
                                  fontSize: 12, color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                ],
                if (widget.mandatory && !_downloading) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: const [
                        Icon(Icons.warning_amber_rounded,
                            color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'هذا التحديث ضروري لاستمرار استخدام التطبيق',
                            style: TextStyle(fontSize: 12, color: Colors.red),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            if (!widget.mandatory && !_downloading)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('لاحقاً',
                    style: TextStyle(color: Colors.grey)),
              ),
            if (!_downloading)
              ElevatedButton.icon(
                onPressed: _startDownload,
                icon: const Icon(Icons.download),
                label: const Text('تحميل وتثبيت'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------- ThemeController ----------------
class ThemeController {
  static final ValueNotifier<ThemeMode> themeMode =
      ValueNotifier(ThemeMode.light);

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('dark_mode') ?? false;
    themeMode.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  static Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final isCurrentlyDark = themeMode.value == ThemeMode.dark;
    themeMode.value = isCurrentlyDark ? ThemeMode.light : ThemeMode.dark;
    await prefs.setBool('dark_mode', !isCurrentlyDark);
  }
}

// ---------------- AgriConsultantApp ----------------
class AgriConsultantApp extends StatefulWidget {
  const AgriConsultantApp({super.key});

  @override
  State<AgriConsultantApp> createState() => _AgriConsultantAppState();
}

class _AgriConsultantAppState extends State<AgriConsultantApp> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    Future.delayed(const Duration(seconds: 3), () => _checkForUpdate());
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasNet = !results.contains(ConnectivityResult.none);
      if (hasNet) {
        debugPrint("🌐 عاد الاتصال بالإنترنت، جاري المزامنة...");
        final synced = await OfflineService.syncPendingDiagnoses();
        if (synced > 0) debugPrint("✅ تمت مزامنة $synced تشخيص");
        _checkForUpdate();
      } else {
        debugPrint("📴 انقطع الاتصال بالإنترنت");
      }
    });
  }

  Future<void> _checkForUpdate() async {
    final update = await VersionService.checkUpdate();
    if (update == null) return;
    if (_navigatorKey.currentContext == null) return;

    showDialog(
      context: _navigatorKey.currentContext!,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        version: update['version'],
        changelog: update['changelog'],
        downloadUrl: update['downloadUrl'],
        mandatory: update['mandatory'],
      ),
    );
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: ThemeController.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'نباتي',
          navigatorKey: _navigatorKey,
          themeMode: mode,
          theme: ThemeData(
            colorScheme:
                ColorScheme.fromSeed(seedColor: const Color(0xFF047857)),
            useMaterial3: true,
            fontFamily: 'Cairo',
            brightness: Brightness.light,
          ),
          darkTheme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: const Color(0xFF047857),
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
            fontFamily: 'Cairo',
            brightness: Brightness.dark,
          ),
          home: const SplashScreen(),
        );
      },
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

// ---------------- AuthWrapper ----------------
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
          return MainNavigationScreen(userName: name, userPhone: phone);
        }

        return const AuthScreen();
      },
    );
  }
}

// ---------------- AuthScreen ----------------
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
                    style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF047857)),
                  ),
                  const Text('مستشارك الزراعي الذكي',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w500)),
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
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _isLoading ? null : _handleAuth,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF047857),
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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
                      isLogin
                          ? 'ليس لديك حساب؟ سجل الآن'
                          : 'لديك حساب بالفعل؟ تسجيل الدخول',
                      style: const TextStyle(
                          color: Color(0xFF047857), fontWeight: FontWeight.bold),
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

// ---------------- MainNavigationScreen ----------------
class MainNavigationScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const MainNavigationScreen(
      {super.key, required this.userName, required this.userPhone});

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
      const EncyclopediaScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF047857),
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => _currentIndex = index),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.home_filled), label: 'الرئيسية'),
          BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt), label: 'فحص الآفات'),
          BottomNavigationBarItem(
              icon: Icon(Icons.menu_book), label: 'الموسوعة'),
        ],
      ),
    );
  }
}
// ---------------- HomeDashboard ----------------
class HomeDashboard extends StatefulWidget {
  final String userName;
  final String userPhone;
  const HomeDashboard({
    super.key,
    required this.userName,
    required this.userPhone,
  });

  @override
  State<HomeDashboard> createState() => _HomeDashboardState();
}

class _HomeDashboardState extends State<HomeDashboard> {
  String weatherTemp = "--";
  String weatherHumidity = "--";
  String weatherStatusText = "جاري تحديد موقعك وجلب الطقس...";
  String locationName = "";
  bool isWeatherLoaded = false;
  bool _refreshing = false;
  String _selectedGovernorate = "";
  List<Map<String, dynamic>> _governorates = [];

  @override
  void initState() {
    super.initState();
    _loadCachedWeather();
  }

  bool _isAdmin() {
    final email = FirebaseAuth.instance.currentUser?.email;
    return CalculatorService.isAdmin(email);
  }

  // ✅ تحميل قائمة المحافظات
  Future<void> _loadGovernorates() async {
    if (_governorates.isNotEmpty) return;
    try {
      final jsonString =
          await rootBundle.loadString('assets/data/governorates.json');
      final data = json.decode(jsonString) as Map<String, dynamic>;
      final list =
          (data['governorates'] as List).cast<Map<String, dynamic>>();
      setState(() {
        _governorates = list;
      });
    } catch (e) {
      debugPrint("❌ خطأ في تحميل المحافظات: $e");
    }
  }

  // ✅ عرض قائمة اختيار المحافظة
  Future<void> _showGovernoratePicker() async {
    await _loadGovernorates();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(16),
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Row(
                children: [
                  Icon(Icons.location_city, color: Color(0xFF047857)),
                  SizedBox(width: 8),
                  Text('اختر المحافظة',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ListTile(
                  leading: const Icon(Icons.my_location,
                      color: Color(0xFF047857)),
                  title: const Text('تحديد تلقائي (GPS)',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('استخدام موقعك الحالي',
                      style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(context);
                    await _fetchWeatherByLocation(manual: true);
                  },
                ),
              ),
              const Divider(),
              Expanded(
                child: _governorates.isEmpty
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        itemCount: _governorates.length,
                        itemBuilder: (context, index) {
                          final gov = _governorates[index];
                          final name = gov['name'] as String? ?? '';
                          final isSelected = name == _selectedGovernorate;
                          return ListTile(
                            leading: Icon(
                              Icons.location_on,
                              color: isSelected
                                  ? const Color(0xFF047857)
                                  : Colors.grey,
                            ),
                            title: Text(name),
                            trailing: isSelected
                                ? const Icon(Icons.check,
                                    color: Color(0xFF047857))
                                : null,
                            onTap: () async {
                              Navigator.pop(context);
                              await _fetchWeatherForGovernorate(
                                name,
                                (gov['lat'] as num).toDouble(),
                                (gov['lon'] as num).toDouble(),
                              );
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ جلب الطقس لمحافظة
  Future<void> _fetchWeatherForGovernorate(
    String govName,
    double lat,
    double lon,
  ) async {
    setState(() {
      _refreshing = true;
      _selectedGovernorate = govName;
      locationName = govName;
    });

    try {
      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon&current=temperature_2m,relative_humidity_2m');
      final response =
          await http.get(url).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherTemp = data['current']['temperature_2m'].toString();
          weatherHumidity =
              data['current']['relative_humidity_2m'].toString();
          weatherStatusText =
              "درجة الحرارة: $weatherTemp°م | الرطوبة: $weatherHumidity%";
          isWeatherLoaded = true;
        });

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('selected_gov', govName);
        await _saveWeatherCache();
      } else {
        setState(() => weatherStatusText = "تعذر جلب بيانات الطقس حالياً");
      }
    } catch (e) {
      debugPrint("❌ خطأ: $e");
      setState(() => weatherStatusText = "⚠️ تعذر الاتصال بالخدمة");
    }

    if (mounted) setState(() => _refreshing = false);
  }

  Future<void> _loadCachedWeather() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedGovernorate = prefs.getString('selected_gov') ?? "";
    final cached = prefs.getString('weather_data');
    if (cached != null) {
      try {
        final data = json.decode(cached) as Map<String, dynamic>;
        setState(() {
          weatherTemp = data['temp'] ?? "--";
          weatherHumidity = data['humidity'] ?? "--";
          weatherStatusText = data['status'] ?? "";
          locationName = data['location'] ?? "";
          isWeatherLoaded = data['loaded'] ?? false;
        });
      } catch (_) {}
    }
    if (!isWeatherLoaded) {
      _fetchWeatherByLocation();
    }
  }

  Future<void> _saveWeatherCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        'weather_data',
        json.encode({
          'temp': weatherTemp,
          'humidity': weatherHumidity,
          'status': weatherStatusText,
          'location': locationName,
          'loaded': isWeatherLoaded,
        }));
  }

  Future<String> _getCityName(
    double lat,
    double lon, {
    String fallback = "",
  }) async {
    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json&accept-language=ar&zoom=10');
      final resp = await http.get(url, headers: {
        'User-Agent': 'Nabati-App/1.0',
      }).timeout(const Duration(seconds: 8));

      if (resp.statusCode == 200) {
        final data = json.decode(resp.body);
        final address = data['address'] ?? {};
        final city = address['city'] ??
            address['town'] ??
            address['municipality'] ??
            address['county'] ??
            address['village'] ??
            address['suburb'] ??
            address['neighbourhood'] ??
            address['city_district'] ??
            address['state_district'];
        if (city != null && city.toString().trim().isNotEmpty) {
          return city.toString();
        }
        final state =
            address['state'] ?? address['governorate'] ?? address['region'];
        if (state != null && state.toString().trim().isNotEmpty) {
          return state.toString();
        }
      }
    } catch (e) {
      debugPrint("Nominatim error: $e");
    }
    if (fallback.isNotEmpty) return fallback;
    return '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
  }

  Future<void> _fetchWeatherByLocation({bool manual = false}) async {
    if (manual) setState(() => _refreshing = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() => weatherStatusText = "⚠️ برجاء تشغيل GPS في هاتفك");
        if (manual) setState(() => _refreshing = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() =>
              weatherStatusText = "برجاء إعطاء صلاحية الموقع لمعرفة الطقس");
          if (manual) setState(() => _refreshing = false);
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() => weatherStatusText =
            "⚠️ تم رفض صلاحية الموقع نهائياً، برجاء تفعيلها من الإعدادات");
        if (manual) setState(() => _refreshing = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.best,
        timeLimit: const Duration(seconds: 20),
      );

      String cityName = await _getCityName(
        position.latitude,
        position.longitude,
        fallback: locationName,
      );

      final url = Uri.parse(
          'https://api.open-meteo.com/v1/forecast?latitude=${position.latitude}&longitude=${position.longitude}&current=temperature_2m,relative_humidity_2m');

      final response =
          await http.get(url).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          weatherTemp = data['current']['temperature_2m'].toString();
          weatherHumidity =
              data['current']['relative_humidity_2m'].toString();
          locationName = cityName;
          _selectedGovernorate = "";
          weatherStatusText =
              "درجة الحرارة: $weatherTemp°م | الرطوبة: $weatherHumidity%";
          isWeatherLoaded = true;
        });
        await _saveWeatherCache();
      } else {
        setState(() => weatherStatusText = "تعذر جلب بيانات الطقس حالياً");
      }
    } catch (e) {
      debugPrint("❌ خطأ في جلب الموقع: $e");
      if (!isWeatherLoaded) {
        setState(
            () => weatherStatusText = "⚠️ برجاء تشغيل GPS والانتظار قليلاً");
      }
    }

    if (manual) setState(() => _refreshing = false);
  }

  void _showAllActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  margin: const EdgeInsets.symmetric(vertical: 10),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 6, 16, 16),
                  child: Row(
                    children: [
                      Icon(Icons.apps, color: Color(0xFF047857), size: 24),
                      SizedBox(width: 10),
                      Text('كل الخدمات',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 17)),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: GridView.count(
                    shrinkWrap: true,
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    physics: const NeverScrollableScrollPhysics(),
                    childAspectRatio: 1.1,
                    children: [
                      if (_isAdmin())
                        _buildActionItem(
                            icon: Icons.admin_panel_settings,
                            color: Colors.amber.shade700,
                            title: 'لوحة الأدمن',
                            onTap: () {
                              Navigator.pop(context);
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const AdminPanelScreen()));
                            }),
                      _buildActionItem(
                          icon: Icons.calculate,
                          color: const Color(0xFF047857),
                          title: 'حاسبات ومخططات',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const CalculatorHubScreen()));
                          }),
                      _buildActionItem(
                          icon: Icons.agriculture,
                          color: const Color(0xFF10B981),
                          title: 'مزرعتي',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const MyFarmScreen()));
                          }),
                      _buildActionItem(
                          icon: Icons.menu_book,
                          color: const Color(0xFF0EA5E9),
                          title: 'الموسوعة',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const EncyclopediaScreen()));
                          }),
                      _buildActionItem(
                          icon: Icons.history,
                          color: const Color(0xFFF59E0B),
                          title: 'السجل',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const HistoryScreen()));
                          }),
                      _buildActionItem(
                          icon: Icons.bar_chart,
                          color: const Color(0xFF6366F1),
                          title: 'إحصائيات',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const StatisticsScreen()));
                          }),
                      _buildActionItem(
                          icon: Icons.chat,
                          color: const Color(0xFF25D366),
                          title: 'الدعم الفني',
                          onTap: () async {
                            Navigator.pop(context);
                            final uri =
                                Uri.parse("https://wa.me/201284172047");
                            try {
                              await launchUrl(uri,
                                  mode: LaunchMode.externalApplication);
                            } catch (e) {}
                          }),
                      _buildActionItem(
                          icon: Icons.info_outline,
                          color: const Color(0xFF8B5CF6),
                          title: 'عن التطبيق',
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => const AboutScreen()));
                          }),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 6),
            Text(title,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                    color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActionCard({
    required IconData icon,
    required Color color,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: color, size: 30),
            ),
            const SizedBox(height: 10),
            Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }

  Widget _buildTipCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.amber.shade50,
            Colors.orange.shade50,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.lightbulb,
                color: Colors.amber.shade800, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'نصيحة اليوم 💡',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.amber.shade900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'تجنب رش المبيدات في وقت الظهيرة أو عند ارتفاع درجات الحرارة لتفادي احتراق الأوراق، وأفضل وقت للرش هو الصباح الباكر أو بعد كسر حدة الشمس عصراً.',
                  style: TextStyle(
                      fontSize: 12, height: 1.6, color: Colors.black87),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeatherCard() {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: const Color(0xFFECFDF5),
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text('حالة الطقس في موقعك',
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
                // ✅ زر اختيار المحافظة
                InkWell(
                  onTap: _showGovernoratePicker,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                          color: const Color(0xFF047857).withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on,
                            size: 12, color: Color(0xFF047857)),
                        const SizedBox(width: 3),
                        Text(
                          locationName.isNotEmpty
                              ? locationName
                              : 'اختر المحافظة',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF047857)),
                        ),
                        const SizedBox(width: 3),
                        const Icon(Icons.arrow_drop_down,
                            size: 16, color: Color(0xFF047857)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                _refreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Color(0xFF047857),
                        ),
                      )
                    : IconButton(
                        icon: const Icon(Icons.refresh,
                            size: 22, color: Color(0xFF047857)),
                        onPressed: () =>
                            _fetchWeatherByLocation(manual: true),
                        tooltip: 'تحديث الموقع والطقس',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                const SizedBox(width: 8),
                const Icon(Icons.wb_sunny, color: Colors.orange, size: 28),
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
          if (_isAdmin())
            IconButton(
              icon: const Icon(Icons.admin_panel_settings,
                  color: Colors.amber),
              tooltip: 'لوحة الأدمن',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const AdminPanelScreen()),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.bar_chart, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => const StatisticsScreen()),
              );
            },
          ),
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
            _buildWeatherCard(),
            const SizedBox(height: 16),
            _buildTipCard(),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                      icon: Icons.calculate,
                      color: const Color(0xFF047857),
                      title: 'حاسبات ومخططات المزرعة',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const CalculatorHubScreen()));
                      }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                      icon: Icons.agriculture,
                      color: const Color(0xFF10B981),
                      title: 'مزرعتي',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => const MyFarmScreen()));
                      }),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _buildQuickActionCard(
                      icon: Icons.menu_book,
                      color: const Color(0xFF0EA5E9),
                      title: 'الموسوعة',
                      onTap: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    const EncyclopediaScreen()));
                      }),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildQuickActionCard(
                      icon: Icons.apps,
                      color: const Color(0xFF6366F1),
                      title: 'كل الخدمات',
                      onTap: _showAllActions),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
// ---------------- AiScannerScreen ----------------
class AiScannerScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const AiScannerScreen(
      {super.key, required this.userName, required this.userPhone});

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
              child: Text('اختر مصدر الصورة',
                  style:
                      TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt,
                  color: Color(0xFF047857), size: 30),
              title: const Text('التقاط صورة بالكاميرا'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFromSource(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library,
                  color: Color(0xFF047857), size: 30),
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
        imageQuality: 70,
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
    const engineerPhone = "201284172047";
    final message = """
السلام عليكم يا بشمهندس علي، معي استشارة زراعية:
🌱 *اسم المزارع:* ${widget.userName}
❓ *المشكلة الزراعية:* ${_questionCtrl.text.trim()}
📋 *تشخيص المستشار الذكي:*
$_diagnosis
""";
    final uri = Uri.parse(
        "https://wa.me/$engineerPhone?text=${Uri.encodeComponent(message)}");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تعذر فتح تطبيق الواتساب')));
    }
  }

  Future<void> _shareDiagnosis() async {
    final text = """
🌱 *تشخيص نباتي - المستشار الزراعي الذكي*
━━━━━━━━━━━━━━━━━━
🌿 *السؤال:* ${_questionCtrl.text.trim()}

📋 *التشخيص:*
$_diagnosis

━━━━━━━━━━━━━━━━━━
📱 تطبيق نباتي - مستشارك الزراعي الذكي
""";
    await Share.share(text, subject: 'تشخيص نباتي');
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
        _diagnosis =
            'خطأ في الإعدادات: مفتاح API (GEMINI_API_KEY) غير موجود.\nيرجى التأكد من تمرير المفتاح أثناء عملية البناء (Build) باستخدام --dart-define.';
      });
      return;
    }

    final hasInternet = await OfflineService.hasInternet();
    if (!hasInternet) {
      setState(() {
        _diagnosis =
            '⚠️ لا يوجد اتصال بالإنترنت حالياً.\nتم حفظ سؤالك وسيتم إرساله تلقائياً عند عودة الاتصال.';
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
          generationConfig: GenerationConfig(
            temperature: 0.3,
            maxOutputTokens: 4096,
            topP: 0.9,
            topK: 40,
          ),
        );

        final prompt = """
أنت مهندس زراعي خبير ومستشار زراعي مصري بخبرة 20 سنة.
اسم المزارع: ${widget.userName}

المطلوب منك: تقديم تقرير زراعي شامل ومفصل عن الحالة التالية.

⚠️ قواعد الإجابة (مهمة جداً - التزم بها حرفياً):

1. ابدأ بالسلام فقط في سطر واحد:
"السلام عليكم يا ${widget.userName} 🌱"

2. بعدها اكتب تقرير مفصل بالترتيب ده بالظبط، مع استخدام الإيموجي زي ما هو مكتوب:

🔍 *المرض/الآفة:*
اكتب اسم المرض أو الآفة بالتفصيل (اسم علمي + اسم شائع إن أمكن)، ووصف مختصر للأعراض الظاهرة.

🎯 *الأسباب:*
اذكر 3-4 أسباب رئيسية لظهور المشكلة (ظروف جوية، ري، تربة، إصابات...)، كل سبب في سطر منفصل مع شرح بسيط.

💊 *العلاج:*
اذكر خطة علاجية كاملة ومفصلة تشمل:
- أسماء المبيدات أو المواد الفعالة (بالجرعات الموصى بها للفدان)
- طريقة التطبيق (رش / حقن / تسميد)
- عدد المرات والفاصل بين كل رشة
- احتياطات الأمان اللي لازم تتبع

🛡️ *الوقاية:*
اذكر 4-5 نصائح وقائية للمستقبل لمنع تكرار المشكلة.

3. لو الصورة مش واضحة أو المعلومات ناقصة، اسأل سؤال توضيحي واحد في الآخر.

4. خلي التقرير كامل ومفصل، بس مترصّص في نقاط واضحة ومقروءة.

5. متستخدمش نجوم ** كتير، استخدم الإيموجي اللي فوق بس.

سؤال/مشكلة المزارع: $question
""";

        List<Part> parts = [TextPart(prompt)];

        if (_imageFile != null) {
          final imageBytes = await _imageFile!.readAsBytes();
          parts.add(DataPart('image/jpeg', imageBytes));
        }

        final response = await model.generateContent([Content.multi(parts)]);

        setState(() {
          _diagnosis =
              response.text ?? 'لم يتمكن الذكاء الاصطناعي من تقديم تشخيص.';
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
            _diagnosis =
                'عذراً، خدمة الذكاء الاصطناعي مشغولة حالياً.\nبرجاء المحاولة مرة أخرى بعد قليل.';
          });
          debugPrint("❌ فشل بعد $attempt محاولات. الخطأ: $e");
        } else {
          debugPrint("⚠️ المحاولة رقم $attempt فشلت. جاري إعادة المحاولة...");
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
        title: const Text('الفحص الذكي للآفات',
            style: TextStyle(color: Colors.white)),
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
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
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
                    const Text('تم إرفاق صورة ✅',
                        style: TextStyle(color: Colors.green)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF047857),
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('إرسال للاستشارة الزراعية',
                        style: TextStyle(fontSize: 16, color: Colors.white)),
              ),
              const SizedBox(height: 24),
              if (_diagnosis.isNotEmpty) ...[
                Card(
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
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
                        SelectableText(
                          _diagnosis,
                          style: const TextStyle(
                            fontSize: 14,
                            height: 1.9,
                            fontFamily: 'Cairo',
                          ),
                          textAlign: TextAlign.right,
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () =>
                                    _toggleVoicePlayback(_diagnosis),
                                icon: Icon(_isPlayingVoice
                                    ? Icons.stop
                                    : Icons.volume_up),
                                label: Text(_isPlayingVoice
                                    ? 'إيقاف الصوت'
                                    : 'استمع للتشخيص'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF047857),
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _shareDiagnosis,
                                icon: const Icon(Icons.share),
                                label: const Text('مشاركة'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(45),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _sendToEngineerWhatsApp,
                                icon: const Icon(Icons.chat),
                                label: const Text('للمهندس'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF25D366),
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size.fromHeight(45),
                                ),
                              ),
                            ),
                          ],
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

// ---------------- HistoryScreen ----------------
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>> _allItems = [];
  List<Map<String, dynamic>> _filteredItems = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
    _searchCtrl.addListener(_filterItems);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final items = await OfflineService.getAllDiagnoses();
    if (mounted) {
      setState(() {
        _allItems = items;
        _filteredItems = items;
        _loading = false;
      });
    }
  }

  void _filterItems() {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filteredItems = _allItems);
    } else {
      setState(() {
        _filteredItems = _allItems.where((item) {
          final question = (item['question'] ?? '').toString().toLowerCase();
          final diagnosis = (item['diagnosis'] ?? '').toString().toLowerCase();
          return question.contains(query) || diagnosis.contains(query);
        }).toList();
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
        title: const Text('سجل التشخيصات',
            style: TextStyle(color: Colors.white)),
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
                      child: const Text('مسح',
                          style: TextStyle(color: Colors.red)),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'ابحث في السجل...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredItems.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                  _allItems.isEmpty
                                      ? Icons.history
                                      : Icons.search_off,
                                  size: 80,
                                  color: Colors.grey),
                              const SizedBox(height: 16),
                              Text(
                                _allItems.isEmpty
                                    ? 'لا يوجد سجل حتى الآن'
                                    : 'لا توجد نتائج مطابقة للبحث',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.grey),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _filteredItems.length,
                          itemBuilder: (context, index) {
                            final item = _filteredItems[index];
                            final date = item['createdAt']?.toString() ?? '';
                            String dateFormatted = date;
                            try {
                              final dt = DateTime.parse(date);
                              dateFormatted =
                                  "${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute}";
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
                                        const Icon(Icons.eco,
                                            color: Color(0xFF047857)),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            item['question']?.toString() ?? '',
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const Divider(),
                                    Text(
                                      item['diagnosis']?.toString() ?? '',
                                      style: const TextStyle(
                                          fontSize: 13, height: 1.5),
                                      maxLines: 5,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(dateFormatted,
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey)),
                                        Row(
                                          children: [
                                            if (item['isSynced'] == 0)
                                              const Padding(
                                                padding:
                                                    EdgeInsets.only(left: 8),
                                                child: Text(
                                                    '⏳ في انتظار المزامنة',
                                                    style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.orange)),
                                              ),
                                            IconButton(
                                              icon: const Icon(Icons.delete,
                                                  color: Colors.red, size: 20),
                                              onPressed: () => _deleteOne(
                                                  item['id'] as int),
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
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
          ],
        ),
      ),
    );
  }
}
// ---------------- ProfileScreen ----------------
class ProfileScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const ProfileScreen(
      {super.key, required this.userName, required this.userPhone});

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
        title:
            const Text('الملف الشخصي', style: TextStyle(color: Colors.white)),
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
                child: const Icon(Icons.person,
                    size: 60, color: Color(0xFF047857)),
              ),
            ),
            const SizedBox(height: 24),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
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
            const SizedBox(height: 16),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.phone, color: Color(0xFF047857)),
                title: const Text('رقم الموبايل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(widget.userPhone),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ValueListenableBuilder<ThemeMode>(
                valueListenable: ThemeController.themeMode,
                builder: (context, mode, _) {
                  final isDark = mode == ThemeMode.dark;
                  return SwitchListTile(
                    secondary: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      color: const Color(0xFF047857),
                    ),
                    title: const Text('الوضع الليلي',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(isDark ? 'مُفعّل' : 'مُعطّل'),
                    value: isDark,
                    activeColor: const Color(0xFF047857),
                    onChanged: (value) async {
                      await ThemeController.toggle();
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading:
                    const Icon(Icons.bar_chart, color: Color(0xFF047857)),
                title: const Text('إحصائيات',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const StatisticsScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: ListTile(
                leading: const Icon(Icons.info_outline,
                    color: Color(0xFF047857)),
                title: const Text('عن التطبيق',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const AboutScreen()),
                  );
                },
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('تسجيل الخروج',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- AboutScreen ----------------
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse("https://wa.me/201284172047");
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {}
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
                      color: Colors.black.withOpacity(0.1),
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
            const Center(
              child: Text(
                'الإصدار 1.0.0',
                style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        onPressed: _openWhatsApp,
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
            const Center(
              child: Text(
                '© 2025 نباتي - جميع الحقوق محفوظة',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- EncyclopediaScreen ----------------
class EncyclopediaScreen extends StatelessWidget {
  const EncyclopediaScreen({super.key});

  Color _hexToColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (e) {
      return const Color(0xFF047857);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الموسوعة الزراعية',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaSection>>(
          stream: EncyclopediaService.getSectionsStream(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text('حدث خطأ: ${snapshot.error}'),
                ),
              );
            }

            final sections = snapshot.data ?? [];

            if (sections.isEmpty) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(30),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.menu_book, size: 100, color: Colors.grey),
                      SizedBox(height: 16),
                      Text('الموسوعة قيد التطوير',
                          style: TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      SizedBox(height: 8),
                      Text('سيتم إضافة المحتوى قريباً',
                          style:
                              TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: sections.length,
              itemBuilder: (context, index) {
                final section = sections[index];
                final color = _hexToColor(section.color);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              EncyclopediaSectionView(section: section),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            color.withOpacity(0.1),
                            color.withOpacity(0.05),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.2),
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
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: color)),
                                const SizedBox(height: 4),
                                Text(
                                  section.description.isEmpty
                                      ? 'اضغط للاستكشاف'
                                      : section.description,
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          Icon(Icons.arrow_forward_ios,
                              size: 18, color: color),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// ---------------- EncyclopediaSectionView ----------------
class EncyclopediaSectionView extends StatelessWidget {
  final EncyclopediaSection section;
  const EncyclopediaSectionView({super.key, required this.section});

  Color _hexToColor(String hex) {
    try {
      final cleaned = hex.replaceAll('#', '');
      return Color(int.parse('FF$cleaned', radix: 16));
    } catch (e) {
      return const Color(0xFF047857);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _hexToColor(section.color);

    return Scaffold(
      appBar: AppBar(
        title: Text('${section.emoji} ${section.name}',
            style: const TextStyle(color: Colors.white)),
        backgroundColor: color,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: StreamBuilder<List<EncyclopediaItem>>(
          stream: EncyclopediaService.getItemsStream(section.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final items = snapshot.data ?? [];

            if (items.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.inbox, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    const Text('لا يوجد محتوى في هذا القسم بعد',
                        style: TextStyle(fontSize: 14, color: Colors.grey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return _buildItemCard(context, item, color);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildItemCard(
      BuildContext context, EncyclopediaItem item, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        leading: Container(
          width: 45,
          height: 45,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            IconLibrary.availableIcons[item.icon] ?? '📄',
            style: const TextStyle(fontSize: 22),
          ),
        ),
        title: Text(item.title,
            style: const TextStyle(
                fontWeight: FontWeight.bold, fontSize: 15)),
        subtitle: item.subtitle.isEmpty
            ? null
            : Text(item.subtitle,
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
        childrenPadding: const EdgeInsets.all(16),
        children: [
          if (item.content.isNotEmpty) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(item.content,
                  style: const TextStyle(fontSize: 13, height: 1.7)),
            ),
            const SizedBox(height: 12),
          ],
          ...item.sections.map((sec) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 4,
                        height: 18,
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        sec['title'] ?? '',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: color),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(sec['content'] ?? '',
                      style: const TextStyle(fontSize: 13, height: 1.6)),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
// ---------------- StatisticsScreen ----------------
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final items = await OfflineService.getAllDiagnoses();
    if (mounted) {
      setState(() {
        _items = items;
        _loading = false;
      });
    }
  }

  Map<String, int> _getTopKeywords() {
    final Map<String, int> keywords = {
      'مرض فطري': 0,
      'حشرة': 0,
      'اصفرار': 0,
      'ذبول': 0,
      'بقع': 0,
      'عفن': 0,
      'نقص تغذية': 0,
    };
    for (var item in _items) {
      final text =
          "${item['question']} ${item['diagnosis']}".toLowerCase();
      keywords.forEach((key, value) {
        if (text.contains(key)) {
          keywords[key] = value + 1;
        }
      });
    }
    final sorted = keywords.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return Map.fromEntries(sorted.take(5));
  }

  int _getSyncedCount() => _items.where((i) => i['isSynced'] == 1).length;
  int _getUnsyncedCount() => _items.where((i) => i['isSynced'] == 0).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإحصائيات',
            style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF047857),
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
                        Icon(Icons.bar_chart, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('لا توجد إحصائيات بعد',
                            style: TextStyle(
                                fontSize: 16, color: Colors.grey)),
                        SizedBox(height: 8),
                        Text('ابدأ بإجراء فحوصات لعرض الإحصائيات',
                            style: TextStyle(
                                fontSize: 13, color: Colors.grey)),
                      ],
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildStatCard(
                        icon: Icons.eco,
                        color: const Color(0xFF047857),
                        title: 'إجمالي التشخيصات',
                        value: _items.length.toString(),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.cloud_done,
                              color: const Color(0xFF3B82F6),
                              title: 'مُزامن',
                              value: _getSyncedCount().toString(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              icon: Icons.cloud_off,
                              color: const Color(0xFFF59E0B),
                              title: 'غير مُزامن',
                              value: _getUnsyncedCount().toString(),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      const Text('📊 أكثر المشاكل تكراراً',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF047857))),
                      const SizedBox(height: 12),
                      Card(
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            children: _getTopKeywords().entries.map((e) {
                              final allValues =
                                  _getTopKeywords().values.toList();
                              final max = allValues.isEmpty
                                  ? 1
                                  : (allValues.reduce(
                                              (a, b) => a > b ? a : b) ==
                                          0
                                      ? 1
                                      : allValues.reduce(
                                          (a, b) => a > b ? a : b));
                              final ratio = e.value / max;
                              return Padding(
                                padding:
                                    const EdgeInsets.only(bottom: 12),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(e.key,
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.w500)),
                                        Text('${e.value}',
                                            style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight:
                                                    FontWeight.bold,
                                                color: Color(0xFF047857))),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    LinearProgressIndicator(
                                      value: ratio,
                                      backgroundColor:
                                          Colors.grey.shade200,
                                      color: const Color(0xFF047857),
                                      minHeight: 6,
                                      borderRadius:
                                          BorderRadius.circular(3),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Card(
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 40),
            const SizedBox(height: 8),
            Text(value,
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color)),
            const SizedBox(height: 4),
            Text(title,
                style:
                    const TextStyle(fontSize: 13, color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}

// ---------------- ArticlesAndGuidesScreen ----------------
class ArticlesAndGuidesScreen extends StatelessWidget {
  const ArticlesAndGuidesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const EncyclopediaScreen();
  }
}
