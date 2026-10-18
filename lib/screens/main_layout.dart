import 'package:flutter/material.dart';
// ضيف السطر ده عشان نستدعي شاشتك القديمة اللي في فولدر farm
import 'farm/my_farm_screen.dart'; 

class MainDashboardScreen extends StatefulWidget {
  const MainDashboardScreen({Key? key}) : super(key: key);

  @override
  State<MainDashboardScreen> createState() => _MainDashboardScreenState();
}

class _MainDashboardScreenState extends State<MainDashboardScreen> {
  int _selectedIndex = 0;

  // قائمة بالشاشات اللي هتظهر في الـ body
  final List<Widget> _screens = [
    const MyFarmScreen(), // الشاشة الرئيسية بتاعتك (مزرعتي)
    const Center(child: Text('شاشة فحص الآفات', style: TextStyle(fontSize: 24))), // مؤقتاً لحد ما تعملها
  ];

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
                    _buildServiceItem(Icons.agriculture, 'مزرعتي', Colors.green),
                    _buildServiceItem(Icons.calculate, 'الحاسبات', Colors.teal),
                    _buildServiceItem(Icons.menu_book, 'الموسوعة', Colors.blue),
                    _buildServiceItem(Icons.bug_report, 'فحص الآفات', Colors.orange),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildServiceItem(IconData icon, String title, Color color) {
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      
      // هنا بنعرض الشاشة اللي إحنا مختارينها
      body: _screens[_selectedIndex],

      floatingActionButton: FloatingActionButton(
        onPressed: _showAllServicesSheet,
        backgroundColor: const Color(0xFF116B44),
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
                  Icons.home,
                  size: 30,
                  color: _selectedIndex == 0 ? const Color(0xFF116B44) : Colors.grey,
                ),
              ),
              const SizedBox(width: 40), 
              // فحص الآفات (شمال)
              IconButton(
                onPressed: () => setState(() => _selectedIndex = 1),
                icon: Icon(
                  Icons.camera_alt,
                  size: 30,
                  color: _selectedIndex == 1 ? const Color(0xFF116B44) : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
