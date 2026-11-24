import 'package:material_ui/material_ui.dart';
import 'app/agri_consultant_app.dart';
import 'app/theme_controller.dart';
import 'app/firebase_bootstrap.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await ThemeController.load();
  } catch (e) {
    debugPrint("تعذر تحميل الثيم: $e");
  }

  final error = await initFirebase();
  runApp(AgriConsultantApp(firebaseReady: error == null, firebaseError: error));
}
