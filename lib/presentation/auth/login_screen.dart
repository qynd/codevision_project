import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../home/main_navigation.dart'; // Halaman Utama Pegawai
import '../admin/admin_home_screen.dart'; // Halaman Utama Admin

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Inisialisasi Client Supabase
  final supabase = Supabase.instance.client;
  
  // Controller Text Field
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  // Key untuk Validasi Form
  final _formKey = GlobalKey<FormState>();
  
  // Loading State
  bool _isLoading = false;

  // --- FUNGSI LOGIN UTAMA ---
  Future<void> _login() async {
    // 1. Validasi Form (Cek kosong/tidak)
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      // 2. Proses Sign In ke Supabase Auth
      final response = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(), // trim() untuk hapus spasi tak sengaja
        password: _passwordController.text.trim(),
      );

      // 3. Jika Login Berhasil (User tidak null)
      if (response.user != null) {
        
        // --- LOGIKA CEK ROLE (RBAC) ---
        // Ambil data user dari tabel 'users' untuk melihat kolom 'role'
        final userData = await supabase
            .from('users')
            .select('role')
            .eq('id', response.user!.id)
            .single();

        // Ambil value role, jika null anggap sebagai 'pegawai'
        final role = userData['role'] ?? 'pegawai';

        if (mounted) {
          // Navigasi Berdasarkan Role
          if (role == 'admin') {
            // Jika ADMIN -> Ke Dashboard Admin
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const AdminHomeScreen())
            );
          } else {
            // Jika PEGAWAI -> Ke Dashboard Pegawai
            Navigator.pushReplacement(
              context, 
              MaterialPageRoute(builder: (context) => const MainNavigation())
            );
          }
        }
      }
    } on AuthException catch (e) {
      // Error khusus Auth (Salah password/email tidak ditemukan)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal Login: ${e.message}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Error umum lainnya (Koneksi putus, dll)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Terjadi kesalahan sistem. Cek koneksi internet."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      // Matikan loading apapun hasilnya
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo atau Icon
                const Icon(Icons.work_outline, size: 80, color: Colors.indigo),
                const SizedBox(height: 16),
                const Text(
                  "Selamat Datang",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.indigo),
                ),
                const Text(
                  "Silakan login untuk melanjutkan",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
                const SizedBox(height: 40),

                // Input Email
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: "Email",
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Email wajib diisi';
                    if (!value.contains('@')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Input Password
                TextFormField(
                  controller: _passwordController,
                  obscureText: true, // Sembunyikan text
                  decoration: const InputDecoration(
                    labelText: "Password",
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Password wajib diisi';
                    if (value.length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Tombol Login
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text("LOGIN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}