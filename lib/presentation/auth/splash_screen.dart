import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/main_navigation.dart'; 
import '../admin/admin_home_screen.dart'; 
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // Setup Animasi Fade
    _controller = AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(_controller);
    
    // Mulai animasi
    _startAnimationSequence();
  }

  Future<void> _startAnimationSequence() async {
    // 1. Fade In
    await _controller.forward();
    
    // 2. Tahan 2 detik
    await Future.delayed(const Duration(seconds: 2));
    
    // 3. Fade Out (Opsional, tapi biasanya langsung pindah juga oke)
    // await _controller.reverse(); 

    // 4. Cek Sesi
    await _checkAuth();
  }

  Future<void> _checkAuth() async {
    final session = Supabase.instance.client.auth.currentSession;

    if (session == null) {
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
    } else {
      try {
        final user = Supabase.instance.client.auth.currentUser;
        final userData = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('id', user!.id)
            .single();

        final role = userData['role'] ?? 'pegawai';

        if (mounted) {
           // Animasi transisi custom
           Navigator.of(context).pushReplacement(PageRouteBuilder(
             pageBuilder: (_, __, ___) => role == 'admin' ? const AdminHomeScreen() : const MainNavigation(),
             transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
             transitionDuration: const Duration(milliseconds: 800)
           ));
        }
      } catch (e) {
        await Supabase.instance.client.auth.signOut();
        if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen()));
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A3C54), // Deep Slate Blue sesuai tema
      body: Center(
        child: FadeTransition(
          opacity: _opacity,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Baru
              Image.asset('assets/images/logo.png', height: 120), 
              const SizedBox(height: 24),
              const Text(
                "Welcome to Codevision", 
                style: TextStyle(
                  color: Colors.white, 
                  fontSize: 24, 
                  fontWeight: FontWeight.w300, 
                  letterSpacing: 1.5
                )
              ),
              const SizedBox(height: 40),
              const CircularProgressIndicator(color: Colors.white54, strokeWidth: 2),
            ],
          ),
        ),
      ),
    );
  }
}