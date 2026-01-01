import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/main_navigation.dart'; // Halaman Pegawai
import '../admin/admin_home_screen.dart'; // Halaman Admin
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    // Beri jeda sedikit biar logo kelihatan (opsional)
    await Future.delayed(const Duration(seconds: 2));

    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      // 1. Jika belum login -> Ke Login Screen
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    } else {
      // 2. Jika sudah login -> CEK ROLE USER
      try {
        final user = Supabase.instance.client.auth.currentUser;
        
        final userData = await Supabase.instance.client
            .from('users')
            .select('role') // Ambil kolom role
            .eq('id', user!.id)
            .single();

        final role = userData['role'] ?? 'pegawai'; // Default pegawai

        if (mounted) {
          if (role == 'admin') {
            // Arahkan ke Admin Dashboard
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const AdminHomeScreen()));
          } else {
            // Arahkan ke Pegawai Dashboard
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const MainNavigation()));
          }
        }
      } catch (e) {
        // Jika error (misal koneksi putus), logoutkan saja biar aman
        await Supabase.instance.client.auth.signOut();
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Colors.indigo,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.code, size: 80, color: Colors.white), // Ganti dengan Logo Anda
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 20),
            Text("Memuat Data...", style: TextStyle(color: Colors.white)),
          ],
        ),
      ),
    );
  }
}