import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_theme.dart'; // Import Theme
import '../profile/profile_screen.dart';
import '../attendance/permission_screen.dart';
import '../attendance/attendance_history_screen.dart'; 
import '../task/employee_task_list_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final supabase = Supabase.instance.client;

  // Data Dashboard
  String _userName = 'Pegawai';
  String _userJabatan = 'Staf';
  String? _userAvatarUrl;

  // Data Absensi
  String _attendanceStatus = 'Belum Absen';
  String _checkInTime = '--:--';
  String _checkOutTime = '--:--';
  bool _isLoadingAbsen = false;

  // Data Tugas
  int _pendingTasks = 0;
  int _completedTasks = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadDashboardData();
    });
  }

  // --- FUNGSI LOAD DATA UTAMA (Tidak Berubah) ---
  Future<void> _loadDashboardData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final userResponse = await supabase.from('users').select().eq('id', user.id).maybeSingle();
      
      if (userResponse != null && mounted) {
        setState(() {
          _userName = userResponse['nama'] ?? 'Pegawai';
          _userJabatan = userResponse['jabatan'] ?? 'Staf';
          _userAvatarUrl = userResponse['avatar_url'];
        });
      }

      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final attendanceRes = await supabase.from('attendances').select().eq('user_id', user.id).eq('tanggal', today).maybeSingle();
      final letterRes = await supabase.from('letters').select().eq('user_id', user.id).lte('tanggal_mulai', today).gte('tanggal_selesai', today).eq('status', 'Approved').maybeSingle();

      if (mounted) {
        setState(() {
          if (letterRes != null) {
            _attendanceStatus = letterRes['jenis_surat'] ?? 'Izin';
            _checkInTime = '-'; _checkOutTime = '-';
          } 
          else if (attendanceRes != null) {
            final statusDb = attendanceRes['status'];
            if (statusDb == 'Hadir') {
              if (attendanceRes['check_in_time'] != null) _checkInTime = DateFormat('HH:mm').format(DateTime.parse(attendanceRes['check_in_time']));
              if (attendanceRes['check_out_time'] != null) {
                _checkOutTime = DateFormat('HH:mm').format(DateTime.parse(attendanceRes['check_out_time']));
                _attendanceStatus = 'Sudah Pulang';
              } else {
                _attendanceStatus = 'Sudah Masuk';
              }
            } else {
              _attendanceStatus = statusDb; _checkInTime = '-'; _checkOutTime = '-';
            }
          } 
          else {
            _attendanceStatus = 'Belum Absen'; _checkInTime = '--:--'; _checkOutTime = '--:--';
          }
        });
      }

      final taskResponse = await supabase.from('tasks').select('status').eq('assigned_to', user.id);
      final List<dynamic> tasks = taskResponse;
      int pending = 0; int completed = 0;
      for (var task in tasks) {
        if (task['status'] == 'Done') completed++; else pending++;
      }

      if (mounted) setState(() { _pendingTasks = pending; _completedTasks = completed; });
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
    }
  }

  // --- LOGIKA GPS (Tidak Berubah) ---
  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("GPS mati. Mohon aktifkan GPS.")));
      return null;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition();
  }

  // --- LOGIKA TOMBOL ABSEN (Tidak Berubah) ---
  Future<void> _handleAttendance() async {
    setState(() => _isLoadingAbsen = true);
    try {
      final user = supabase.auth.currentUser;
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      if (_attendanceStatus == 'Belum Absen') {
        final position = await _getCurrentLocation();
        if (position == null) throw "Gagal mendapatkan lokasi.";

        await supabase.from('attendances').insert({
          'user_id': user!.id, 'tanggal': today, 'check_in_time': now.toIso8601String(),
          'check_in_lat': position.latitude, 'check_in_long': position.longitude, 'status': 'Hadir',
        });
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Absen Masuk!")));
      
      } else if (_attendanceStatus == 'Sudah Masuk') {
        await supabase.from('attendances').update({'check_out_time': now.toIso8601String()}).eq('user_id', user!.id).eq('tanggal', today);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Absen Pulang!")));
      }
      await _loadDashboardData(); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoadingAbsen = false);
    }
  }

  // --- UI WIDGETS ---
  Widget _buildAttendanceCard() {
    Color cardColor = CodevisionTheme.primaryColor; // Default ke Biru Slate Theme
    IconData icon = Icons.fingerprint;
    String message = "Jangan lupa Check-in!";
    String buttonText = "ABSEN MASUK";
    bool isButtonDisabled = false;
    bool showTime = true; 

    if (_attendanceStatus == 'Sudah Masuk') {
      cardColor = Colors.green.shade800; 
      icon = Icons.timer_outlined;
      message = "Sedang Bekerja";
      buttonText = "ABSEN PULANG";
    } else if (_attendanceStatus == 'Sudah Pulang') {
      cardColor = Colors.grey.shade700;
      icon = Icons.check_circle_outline;
      message = "Selesai Bekerja";
      buttonText = "SELESAI";
      isButtonDisabled = true;
    } else if (_attendanceStatus != 'Belum Absen') {
      cardColor = Colors.orange.shade900;
      icon = Icons.local_hospital_outlined;
      message = "Status: $_attendanceStatus";
      buttonText = "SEDANG ${_attendanceStatus.toUpperCase()}";
      isButtonDisabled = true;
      showTime = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: cardColor.withOpacity(0.4), blurRadius: 15, offset: const Offset(0, 8))
        ],
        gradient: LinearGradient(
          colors: [cardColor, cardColor.withOpacity(0.85)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              Text(_attendanceStatus, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 20),
          
          if (showTime) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildTimeColumn("Masuk", _checkInTime),
                Container(width: 1, height: 40, color: Colors.white24),
                _buildTimeColumn("Pulang", _checkOutTime),
              ],
            ),
            const SizedBox(height: 24),
          ] else ...[
             Padding(padding: const EdgeInsets.symmetric(vertical: 20), child: Text(message, style: const TextStyle(color: Colors.white70))),
          ],

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: (isButtonDisabled || _isLoadingAbsen) ? null : _handleAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: cardColor,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _isLoadingAbsen 
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTimeColumn(String label, String time) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 4),
        Text(time, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 1)),
      ],
    );
  }

  Widget _buildTaskStats() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () async {
              await Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeTaskListScreen()));
              _loadDashboardData();
            },
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                    child: const Icon(Icons.assignment_late_outlined, color: Colors.orange),
                  ),
                  const SizedBox(height: 16),
                  Text("$_pendingTasks Tugas", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CodevisionTheme.primaryColor)),
                  const Text("Perlu Diselesaikan", style: TextStyle(color: Colors.grey, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: const Icon(Icons.task_alt, color: Colors.green),
                ),
                const SizedBox(height: 16),
                Text("$_completedTasks Selesai", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CodevisionTheme.primaryColor)),
                const Text("Tugas Selesai", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickMenu() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _menuItem(
          icon: Icons.assignment, label: "Tugas Saya", color: CodevisionTheme.primaryColor,
          onTap: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeTaskListScreen()));
            _loadDashboardData();
          }
        ),
        _menuItem(
          icon: Icons.calendar_today_rounded, label: "Izin / Cuti", color: CodevisionTheme.accentColor,
          onTap: () async {
             final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PermissionScreen()));
             if (result == true) _loadDashboardData();
          }
        ),
        _menuItem(
          icon: Icons.history_rounded, label: "Riwayat", color: Colors.grey.shade700,
          onTap: () async {
             await Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceHistoryScreen()));
             _loadDashboardData();
          }
        ),
      ],
    );
  }

  Widget _menuItem({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 80,
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1), 
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: color.withOpacity(0.2))
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 8),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: CodevisionTheme.backgroundColor, 
      body: Stack(
        children: [
          // --- SILUET LOGO BACKGROUND ---
          Positioned(
            top: -50,
            right: -50,
            child: Opacity(
              opacity: 0.05, // Transparan agar jadi siluet halus
              child: Image.asset('assets/images/logo.png', width: 300, color: CodevisionTheme.primaryColor),
            ),
          ),

          // --- KONTEN UTAMA ---
          SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 20, left: 20, right: 20, bottom: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // HEADER (Logo & Profile)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                     // GANTI TEKS DENGAN LOGO KECIL & TEKS
                     Row(
                       children: [
                         Image.asset('assets/images/logo.png', height: 40),
                         const SizedBox(width: 10),
                         Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Halo, $_userName", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: CodevisionTheme.primaryColor)),
                              Text("Jabatan: $_userJabatan", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                         ),
                       ],
                     ),
                     
                     InkWell(
                        onTap: () async {
                          await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                          _loadDashboardData();
                        },
                        child: CircleAvatar(
                          radius: 20,
                          backgroundColor: CodevisionTheme.accentColor.withOpacity(0.2),
                          backgroundImage: _userAvatarUrl != null ? NetworkImage(_userAvatarUrl!) : null,
                          child: _userAvatarUrl == null 
                            ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : "A", style: const TextStyle(color: CodevisionTheme.primaryColor, fontSize: 16, fontWeight: FontWeight.bold))
                            : null,
                        ),
                     )
                  ],
                ),
                const SizedBox(height: 24),

                Text(dateString, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.grey.shade600)),
                const SizedBox(height: 12),
                
                _buildAttendanceCard(),
                
                const SizedBox(height: 32),
                
                _buildQuickMenu(),
                
                const SizedBox(height: 32),
                
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Statistik Tugas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
                    Icon(Icons.bar_chart_rounded, color: Colors.grey.shade400)
                  ],
                ),
                const SizedBox(height: 16),
                _buildTaskStats(),
                
                const SizedBox(height: 40), 
              ],
            ),
          ),
        ],
      ),
    );
  }
}