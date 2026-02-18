// lib/main.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'presentation/auth/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menyiapkan format tanggal bahasa Indonesia sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null);

  // --- INISIALISASI SUPABASE ---
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  // -----------------------------

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,

      // Setup tema dasar
      theme: CodevisionTheme.lightTheme,

      // Arahkan ke SplashScreen untuk pengecekan sesi
      home: const SplashScreen(),
    );
  }
}
