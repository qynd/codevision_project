import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/constants/app_constants.dart';
import 'core/constants/app_theme.dart';
import 'presentation/auth/splash_screen.dart';

import 'providers/wireframe_provider.dart';
import 'core/theme/wireframe_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Menyiapkan format tanggal bahasa Indonesia sebelum aplikasi jalan
  await initializeDateFormatting('id_ID', null);

  // --- INISIALISASI SUPABASE (dengan timeout agar tidak stuck saat offline) ---
  try {
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    // Tetap lanjut meski koneksi timeout/gagal (offline mode)
    debugPrint('⚠️ Supabase initialize gagal: $e');
  }
  // ---------------------------------------------------------------------------

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => WireframeProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<WireframeProvider>(
      builder: (context, wireframeProv, child) {
        return MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,

          // Setup tema dinamis
          theme: wireframeProv.isWireframe ? WireframeTheme.theme : CodevisionTheme.lightTheme,

          // Arahkan ke SplashScreen untuk pengecekan sesi
          home: const SplashScreen(),
          
          // Builder global untuk menyematkan toggle Wireframe secara melayang (overlay)
          builder: (context, appNavigator) {
            Widget currentApp = appNavigator ?? const SizedBox();
            
            // Mengubah seluruh aplikasi menjadi Hitam-Putih (Grayscale)
            if (wireframeProv.isWireframe) {
              currentApp = ColorFiltered(
                colorFilter: const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0,      0,      0,      1, 0,
                ]),
                child: currentApp,
              );
            }

            return Directionality(
              textDirection: TextDirection.ltr,
              child: Stack(
                children: [
                  currentApp,
                  
                  // Tombol Global Floating Mode Wireframe
                  Positioned(
                    bottom: 24, // Agak naik agar tidak menabrak BottomNavigationBar
                    right: 20,
                    child: SafeArea(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            context.read<WireframeProvider>().toggleWireframe();
                          },
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: wireframeProv.isWireframe ? Colors.black : Colors.indigo.shade100,
                              border: wireframeProv.isWireframe 
                                  ? Border.all(color: Colors.white, width: 2) 
                                  : null,
                              boxShadow: const [
                                BoxShadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 2))
                              ],
                            ),
                            child: Icon(
                              Icons.architecture_rounded, // Ikon pensil/arsitek
                              color: wireframeProv.isWireframe ? Colors.white : Colors.indigo.shade900,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

