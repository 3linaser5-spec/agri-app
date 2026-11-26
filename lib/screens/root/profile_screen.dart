import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import '../../services/weather_push_service.dart';
import '../../app/theme_controller.dart';
import './about_screen.dart';
import './statistics_screen.dart';


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
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({'name': newName}, SetOptions(merge: true));
        } catch (e) {
          debugPrint('تعذر تحديث اسم المستخدم في Firestore');
        }
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
          const SnackBar(content: Text('حدث خطأ أثناء الحفظ')),
        );
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _changePassword() async {
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغيير كلمة المرور'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
            controller: currentCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الحالية'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: newCtrl,
            obscureText: true,
            decoration: const InputDecoration(labelText: 'كلمة المرور الجديدة'),
          ),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      currentCtrl.dispose();
      newCtrl.dispose();
      return;
    }
    setState(() => _saving = true);
    final error = await _authService.changePassword(
      currentPassword: currentCtrl.text,
      newPassword: newCtrl.text,
    );
    currentCtrl.dispose();
    newCtrl.dispose();
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(error ?? '✅ تم تغيير كلمة المرور بنجاح'),
      backgroundColor: error == null ? const Color(0xFF047857) : null,
    ));
  }

  Future<void> _deleteAccount() async {
    final passwordCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف الحساب'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
                'سيتم حذف حسابك وبياناتك الشخصية نهائيًا. لا يمكن التراجع عن هذه الخطوة.'),
            const SizedBox(height: 8),
            TextField(
              controller: passwordCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'كلمة المرور للتأكيد'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('حذف نهائي', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      passwordCtrl.dispose();
      return;
    }
    setState(() => _saving = true);
    final error = await _authService.deleteAccount(password: passwordCtrl.text);
    passwordCtrl.dispose();
    if (!mounted) return;
    setState(() => _saving = false);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error), backgroundColor: Colors.red),
      );
      return;
    }
    Navigator.of(context).popUntil((r) => r.isFirst);
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
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        try {
          await WeatherPushService.disable(uid);
        } catch (error) {
          debugPrint('تعذر إلغاء تسجيل طقس الجهاز قبل الخروج');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'تعذر إلغاء اشتراك الطقس من الخادم. تحقق من الاتصال ثم أعد تسجيل الخروج.',
                ),
              ),
            );
          }
          return;
        }
      }
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
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
                backgroundColor: const Color(0xFF047857).withValues(alpha: 0.15),
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
                    activeThumbColor: const Color(0xFF047857),
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
            const SizedBox(height: 16),
            Card(
              shape:
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 2,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.lock_reset,
                        color: Color(0xFF047857)),
                    title: const Text('تغيير كلمة المرور',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _saving ? null : _changePassword,
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading:
                        const Icon(Icons.delete_forever, color: Colors.red),
                    title: const Text('حذف الحساب',
                        style: TextStyle(
                            fontWeight: FontWeight.bold, color: Colors.red)),
                    subtitle:
                        const Text('حذف نهائي للحساب والبيانات الشخصية'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: _saving ? null : _deleteAccount,
                  ),
                ],
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
