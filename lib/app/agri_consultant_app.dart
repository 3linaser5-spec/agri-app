import 'dart:async';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    hide GlobalMaterialLocalizations, GlobalCupertinoLocalizations;
import '../config/build_flags.dart';
import '../services/offline_service.dart';
import '../services/version_service.dart';
import '../widgets/update_dialog.dart';
import './theme_controller.dart';
import '../screens/root/firebase_setup_error_screen.dart';
import '../screens/root/splash_screen.dart';


// ---------------- AgriConsultantApp ----------------
class AgriConsultantApp extends StatefulWidget {
  final bool firebaseReady;
  final String? firebaseError;
  const AgriConsultantApp(
      {super.key, required this.firebaseReady, this.firebaseError});

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
    // نسخة المتجر بتتحدّث من Google Play، فمفيش فحص تحديث ولا شبكة هنا.
    if (!BuildFlags.storeBuild) {
      Future.delayed(const Duration(seconds: 3), () => _checkForUpdate());
    }
  }

  void _setupConnectivityListener() {
    _connectivitySub = Connectivity()
        .onConnectivityChanged
        .listen((List<ConnectivityResult> results) async {
      final hasNet = !results.contains(ConnectivityResult.none);
      if (hasNet) {
        if (widget.firebaseReady) {
          debugPrint("عاد الاتصال بالإنترنت، جاري المزامنة...");
          final synced = await OfflineService.syncPendingDiagnoses();
          if (synced > 0) debugPrint("تمت مزامنة $synced تشخيص");
        }
        if (!BuildFlags.storeBuild) _checkForUpdate();
      } else {
        debugPrint("انقطع الاتصال بالإنترنت");
      }
    });
  }

  bool _updateDialogShowing = false;

  Future<void> _checkForUpdate() async {
    if (_updateDialogShowing) return;
    final update = await VersionService.checkUpdate();
    if (update == null || _updateDialogShowing) return;
    final ctx = _navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    _updateDialogShowing = true;
    await showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => UpdateDialog(
        version: update['version'].toString(),
        changelog: update['changelog'].toString(),
        downloadUrl: update['downloadUrl'].toString(),
        sha256: update['sha256']?.toString(),
        mandatory: update['mandatory'] == true,
      ),
    );
    _updateDialogShowing = false;
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
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
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
          home: widget.firebaseReady
              ? const SplashScreen()
              : FirebaseSetupErrorScreen(error: widget.firebaseError),
        );
      },
    );
  }
}
