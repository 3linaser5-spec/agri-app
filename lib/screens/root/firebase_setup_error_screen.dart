import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../app/agri_consultant_app.dart';
import '../../app/firebase_bootstrap.dart';


class FirebaseSetupErrorScreen extends StatefulWidget {
  final String? error;
  const FirebaseSetupErrorScreen({super.key, this.error});

  @override
  State<FirebaseSetupErrorScreen> createState() =>
      _FirebaseSetupErrorScreenState();
}

class _FirebaseSetupErrorScreenState extends State<FirebaseSetupErrorScreen> {
  bool _retrying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _error = widget.error;
  }

  Future<void> _retry() async {
    setState(() => _retrying = true);
    final error = await initFirebase();
    if (error == null) {
      runApp(const AgriConsultantApp(firebaseReady: true));
      return;
    }
    if (!mounted) return;
    setState(() {
      _retrying = false;
      _error = error;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'تعذر الاتصال بخدمات Firebase. تأكد من الإنترنت (وإن وضع الطيران مقفول) ثم أعد المحاولة.',
                  textAlign: TextAlign.center,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  const Text('تفاصيل الخطأ (للمطور):',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  SelectableText(
                    _error!,
                    textDirection: TextDirection.ltr,
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  onPressed: _retrying ? null : _retry,
                  icon: _retrying
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.refresh),
                  label: const Text('إعادة المحاولة'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
