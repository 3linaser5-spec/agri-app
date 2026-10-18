import 'package:flutter/material.dart';
// استدعاء الشاشات بتاعتك (هتحتاج تعدل مسارات الـ import دي لو الملفات مش في نفس المكان)
import '../main.dart'; // عشان نوصل لـ HomeDashboard و AiScannerScreen
import 'farm/my_farm_screen.dart';
import 'calculators/calculator_hub_screen.dart';
import 'admin/admin_panel_screen.dart';

class MainDashboardScreen extends StatefulWidget {
  final String userName;
  final String userPhone;
  const MainDashboardScreen({super.key, required this.userName, required this.userPhone});

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedIndex = 0;

  // قائمة الشاشات اللي هتظهر
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeDashboard(userName: widget.userName, userPhone: widget.userPhone), // شاشة الرئيسية
      AiScannerScreen(userName: widget.userName, userPhone: widget.userPhone), // شاشة فحص الآفات
    ];
  }

  void _showAllServicesSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 20),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Text(
                'كل الخدمات',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 3,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  mainAxisSpacing: 20,
                  crossAxisSpacing: 20,
                  children: [
                    _buildServiceItem(Icons.agriculture, 'مزرعتي', Colors.green, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFarmScreen()));
                    }),
                    _buildServiceItem(Icons.calculate, 'الحاسبات', Colors.teal, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorHubScreen()));
                    }),
                    _buildServiceItem(Icons.menu_book, 'الموسوعة', Colors.blue, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EncyclopediaScreen()));
                    }),
                    _buildServiceItem(Icons.history, 'السجل', Colors.orange, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    }),
                    _buildServiceItem(Icons.admin_panel_settings, 'الأدمن', Colors.amber, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminPanelScreen()));
                    }),
                    _buildServiceItem(Icons.info_outline, 'عن التطبيق', Colors.purple, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
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
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 32, color: color),
          ),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      
      body: IndexedStack(index: _selectedIndex, children: _screens),

      floatingActionButton: FloatingActionButton(
        onPressed: _showAllServicesSheet,
        backgroundColor: const Color(0xFF047857), // غيرتها لنفس لون تطبيقك
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // الرئيسية (يمين)
              IconButton(
                onPressed: () => setState(() => _selectedIndex = 0),
                icon: Icon(
                  Icons.home_filled,
                  size: 30,
                  color: _selectedIndex == 0 ? const Color(0xFF047857) : Colors.grey,
                ),
              ),
              const SizedBox(width: 40), 
              // فحص الآفات (شمال)
              IconButton(
                onPressed: () => setState(() => _selectedIndex = 1),
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
