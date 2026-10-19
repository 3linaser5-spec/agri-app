import 'package:flutter/material.dart';

// ⚠️ استيراد الشاشات والخدمات بصورة صحيحة لتجنب الـ Circular Import
import 'home_dashboard_screen.dart';
import 'ai_scanner_screen.dart';
import 'farm/my_farm_screen.dart';
import 'admin/admin_panel_screen.dart';

// استيراد شاشة حاسبة شبكات الري وتصدير الكاد التي أعددناها
import '../screens/irrigation_calculator_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const MainDashboardScreen({super.key, required this.userName, required this.userPhone});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedIndex = 0;

  // قائمة الشاشات الرئيسية
  late final List<Widget?> _screens;

  @override
  void initState() {
    super.initState();
    // تحميل الشاشة الأولى فقط في البداية (Lazy Loading)
    _screens = [
      HomeDashboard(userName: widget.userName, userPhone: widget.userPhone),
      null, // شاشة فحص الآفات هتتحمل أول ما المستخدم يدوس عليها
    ];
  }

  void _onTabSelected(int index) {
    // لو الشاشة لسه متحملتش، بنحملها دلوقتي ونحفظها عشان منحملها تاني
    if (_screens[index] == null) {
      if (index == 1) {
        _screens[index] = AiScannerScreen(userName: widget.userName, userPhone: widget.userPhone);
      }
    }
    setState(() => _selectedIndex = index);
  }

  void _showAllServicesSheet() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        // تحديد أقصى ارتفاع للشيت عشان ميبقاش ضخم على التابلت
        final screenHeight = MediaQuery.of(context).size.height;
        final sheetHeight = screenHeight * 0.55 > 450 ? 450.0 : screenHeight * 0.55;

        return Container(
          height: sheetHeight,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Text(
                'كل الخدمات',
                style: TextStyle(
                  fontSize: 20, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  children: [
                    _buildServiceItem(Icons.agriculture, 'مزرعتي', Colors.green, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFarmScreen()));
                    }),
                    // ✅ تم ربط زر الحاسبات بشاشة حاسبة شبكات الري وتصدير الكاد الفعالة
                    _buildServiceItem(Icons.calculate, 'حاسبات الري', Colors.teal, () {
                      Navigator.pop(context);
                      Navigator.push(
                        context, 
                        MaterialPageRoute(builder: (_) => const IrrigationCalculatorScreen()),
                      );
                    }),
                    _buildServiceItem(Icons.menu_book, 'الموسوعة', Colors.blue, () {
                      Navigator.pop(context);
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const EncyclopediaScreen()));
                    }),
                    _buildServiceItem(Icons.history, 'السجل', Colors.orange, () {
                      Navigator.pop(context);
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    }),
                    _buildServiceItem(Icons.admin_panel_settings, 'الأدمن', Colors.amber, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                    }),
                    _buildServiceItem(Icons.info_outline, 'عن التطبيق', Colors.purple, () {
                      Navigator.pop(context);
                      // Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceItem(IconData icon, String title, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: color.withOpacity(isDark ? 0.2 : 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 28, color: color),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              fontWeight: FontWeight.w600, 
              fontSize: 13,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? null : const Color(0xFFF5F7F6),
      
      // IndexedStack محتاج List<Widget>، فبنمرر الـ null value عشان نمنع الـ Crash
      body: IndexedStack(
        index: _selectedIndex, 
        children: _screens.map((s) => s ?? const SizedBox.shrink()).toList(),
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAllServicesSheet,
        backgroundColor: const Color(0xFF047857),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              IconButton(
                onPressed: () => _onTabSelected(0),
                icon: Icon(
                  Icons.home_filled,
                  size: 30,
                  color: _selectedIndex == 0 ? const Color(0xFF047857) : Colors.grey,
                ),
              ),
              const SizedBox(width: 40), 
              IconButton(
                onPressed: () => _onTabSelected(1),
                icon: Icon(
                  Icons.camera_alt,
                  size: 30,
                  color: _selectedIndex == 1 ? const Color(0xFF047857) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
