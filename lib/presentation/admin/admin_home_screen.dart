import 'package:codevision_project/presentation/admin/letters/admin_letter_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart'; // Import Login
import 'employee/employee_list_screen.dart';
import 'project/admin_project_list_screen.dart';
import '../attendance/admin_attendance_screen.dart';
import 'admin_dashboard_stats.dart'; // File baru untuk statistik

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final supabase = Supabase.instance.client;
  int _selectedIndex = 0;

  // List Halaman
  final List<Widget> _pages = [
    const AdminDashboardStats(), // Halaman Dashboard diagram
    const AdminProjectListScreen(), // Halaman Proyek
    const EmployeeListScreen(), // Halaman Pegawai
    const AdminLetterListScreen(), // (Opsional) Surat
  ];

  // Judul tiap halaman
  final List<String> _titles = [
    "Dashboard",
    "Kelola Proyek",
    "Kelola Pegawai",
    "Validasi Surat",
  ];

  // Fungsi Logout Admin
  Future<void> _signOut() async {
    await supabase.auth.signOut();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.indigo.shade900, 
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.assignment),
            label: 'Proyek',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people),
            label: 'Pegawai',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.email),
            label: 'Surat',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.indigo,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed, // Agar > 3 item tetap terlihat labelnya
        onTap: _onItemTapped,
      ),
    );
  }
}
