import 'package:codevision_project/presentation/admin/letters/admin_letter_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart'; // Import Login
import 'employee/employee_list_screen.dart';
import 'project/admin_project_list_screen.dart';
import '../attendance/admin_attendance_screen.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  final supabase = Supabase.instance.client;

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor:
            Colors.indigo.shade900, // Warna lebih gelap untuk Admin
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: GridView.count(
        padding: const EdgeInsets.all(20),
        crossAxisCount: 2, // 2 Kolom
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildAdminMenu(
            icon: Icons.people,
            label: "Kelola Pegawai",
            color: Colors.blue,
            onTap: () {
              // Navigasi sudah benar mengarah ke lokasi baru
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const EmployeeListScreen(),
                ),
              );
            },
          ),
          _buildAdminMenu(
            icon: Icons.calendar_month, // Icon kalender cocok untuk absensi
            label: "Monitoring Absensi",
            color: Colors.teal,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Arahkan ke screen yang tadi kamu buat
                  builder: (context) => const AdminAttendanceScreen(),
                ),
              );
            },
          ),
          _buildAdminMenu(
            icon: Icons.assignment_add,
            label: "Kelola Proyek",
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminProjectListScreen(),
                ),
              );
            },
          ),
          _buildAdminMenu(
            icon: Icons.mark_email_read,
            label: "Validasi Surat",
            color: Colors.green,
            onTap: () {
              // Navigasi ke Halaman Validasi Surat
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AdminLetterListScreen(),
                ),
              );
            },
          ),
          _buildAdminMenu(
            icon: Icons.print,
            label: "Cetak Laporan",
            color: Colors.purple,
            onTap: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Fitur Laporan segera hadir")),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAdminMenu({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade200,
              blurRadius: 5,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 16),
            Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
