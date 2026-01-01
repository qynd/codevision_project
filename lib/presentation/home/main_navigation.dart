import 'package:flutter/material.dart';
import 'home_screen.dart';
import '../attendance/attendance_screen.dart';
import '../project/project_screen.dart';
import '../letter/letter_screen.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 0;
  
  // Variabel untuk memicu refresh halaman Home
  int _homeRefreshKey = 0; 

  void _onItemTapped(int index) {
    setState(() {
      // Jika user mengklik tab Home (index 0), kita ubah key-nya
      // Perubahan key akan memaksa Flutter memuat ulang halaman tersebut
      if (index == 0) {
        _homeRefreshKey++;
      }
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          // Tambahkan Key di sini. Setiap kali _homeRefreshKey berubah, 
          // HomeScreen akan dihancurkan dan dibuat ulang (otomatis refresh data).
          HomeScreen(key: ValueKey(_homeRefreshKey)), 
          
          const AttendanceScreen(),
          const ProjectScreen(),
          const LetterScreen(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.fingerprint_rounded),
            label: 'Absensi',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment_rounded),
            label: 'Proyek',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email_rounded),
            label: 'Surat',
          ),
        ],
      ),
    );
  }
}