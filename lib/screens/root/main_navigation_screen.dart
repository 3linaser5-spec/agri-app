import 'package:material_ui/material_ui.dart';
import '../calculators/calculator_hub_screen.dart';
import '../farm/my_farm_screen.dart';
import '../satellite/satellite_access_gate_screen.dart';
import './home_dashboard.dart';
import './ai_scanner_screen.dart';
import './history_screen.dart';
import './profile_screen.dart';
import './about_screen.dart';
import './encyclopedia_screen.dart';
import './statistics_screen.dart';


// ---------------- MainNavigationScreen (تم تعديله) ----------------
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

  // الشاشات التي سيتم التنقل بينها
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeDashboard(userName: widget.userName, userPhone: widget.userPhone),
      AiScannerScreen(userName: widget.userName, userPhone: widget.userPhone),
    ];
  }

  // قائمة الخدمات المنبثقة
  void _showAllActions() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Directionality(
        textDirection: TextDirection.rtl,
        child: Container(
          height: MediaQuery.of(context).size.height * 0.65,
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
                    _buildActionItem(Icons.agriculture, 'مزرعتي', const Color(0xFF10B981), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const MyFarmScreen()));
                    }),
                    _buildActionItem(Icons.satellite_alt, 'رصد الأقمار', const Color(0xFF0F766E), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const SatelliteMonitoringScreen()));
                    }),
                    _buildActionItem(Icons.calculate, 'الحاسبات', const Color(0xFF047857), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const CalculatorHubScreen()));
                    }),
                    _buildActionItem(Icons.menu_book, 'الموسوعة', const Color(0xFF0EA5E9), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EncyclopediaScreen()));
                    }),
                    _buildActionItem(Icons.history, 'السجل', const Color(0xFFF59E0B), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HistoryScreen()));
                    }),
                    _buildActionItem(Icons.bar_chart, 'إحصائيات', const Color(0xFF6366F1), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const StatisticsScreen()));
                    }),
                    _buildActionItem(Icons.info_outline, 'عن التطبيق', const Color(0xFF8B5CF6), () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const AboutScreen()));
                    }),
                    _buildActionItem(Icons.person, 'حسابي', Colors.blueGrey, () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userName: widget.userName, userPhone: widget.userPhone)));
                    }),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      
      // الزر العائم في المنتصف
      floatingActionButton: FloatingActionButton(
        onPressed: _showAllActions,
        backgroundColor: const Color(0xFF047857),
        elevation: 4,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, color: Colors.white, size: 32),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,

      // الشريط السفلي الجديد مع النصوص
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        notchMargin: 8.0,
        color: Colors.white,
        elevation: 10,
        child: SizedBox(
          height: 65, // زودنا الارتفاع عشان النص
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // الرئيسية (يمين)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.home_filled,
                        size: 26,
                        color: _currentIndex == 0 ? const Color(0xFF047857) : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'الرئيسية',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _currentIndex == 0 ? FontWeight.bold : FontWeight.normal,
                          color: _currentIndex == 0 ? const Color(0xFF047857) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(width: 40), // مساحة للزر العائم
              
              // فحص الآفات (شمال)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _currentIndex = 1),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.camera_alt,
                        size: 26,
                        color: _currentIndex == 1 ? const Color(0xFF047857) : Colors.grey,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'فحص الآفات',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: _currentIndex == 1 ? FontWeight.bold : FontWeight.normal,
                          color: _currentIndex == 1 ? const Color(0xFF047857) : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
