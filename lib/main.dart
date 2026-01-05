// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- 1. TAMBAHKAN IMPORT INI ---
import 'package:intl/date_symbol_data_local.dart'; 
// -------------------------------

import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart'; // Import Theme Baru
import 'presentation/auth/splash_screen.dart'; 

void main() async {
  WidgetsFlutterBinding.ensureInitialized(); 

  // --- 2. TAMBAHKAN KODE INI ---
  // Menyiapkan format tanggal bahasa Indonesia sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null);
  // -----------------------------

  // --- INISIALISASI SUPABASE ---
  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
  );
  // -----------------------------
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp( // Hapus 'const' di sini jika themes berubah dinamis, tapi 'const' oke jika statis
      title: APP_NAME,
      debugShowCheckedModeBanner: false,
      
      // Setup tema dasar agar konsisten
      theme: CodevisionTheme.lightTheme,

      // Arahkan ke SplashScreen untuk pengecekan sesi
      home: const SplashScreen(), 
    );
  }
}