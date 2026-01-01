import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:geolocator/geolocator.dart';

import '../profile/profile_screen.dart';
import '../attendance/permission_screen.dart';
import '../attendance/attendance_history_screen.dart'; // Pastikan import ini ada

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

  // --- FUNGSI LOAD DATA UTAMA ---
  Future<void> _loadDashboardData() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      // 1. Profil User
      final userResponse = await supabase
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      
      if (userResponse != null && mounted) {
        setState(() {
          _userName = userResponse['nama'] ?? 'Pegawai';
          _userJabatan = userResponse['jabatan'] ?? 'Staf';
          _userAvatarUrl = userResponse['avatar_url'];
        });
      }

      // 2. Data Absensi Hari Ini
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      
      // Cek Absensi (Hadir/Telat)
      final attendanceRes = await supabase
          .from('attendances')
          .select()
          .eq('user_id', user.id)
          .eq('tanggal', today)
          .maybeSingle();

      // Cek Surat (Izin/Sakit/Cuti) yang Approved
      final letterRes = await supabase
          .from('letters')
          .select()
          .eq('user_id', user.id)
          .lte('tanggal_mulai', today) 
          .gte('tanggal_selesai', today) 
          .eq('status', 'Approved') 
          .maybeSingle();

      if (mounted) {
        setState(() {
          // Prioritas 1: Surat Izin
          if (letterRes != null) {
            _attendanceStatus = letterRes['jenis_surat'] ?? 'Izin';
            _checkInTime = '-';
            _checkOutTime = '-';
          } 
          // Prioritas 2: Data Absensi
          else if (attendanceRes != null) {
            final statusDb = attendanceRes['status'];
            
            if (statusDb == 'Hadir') {
              // --- PERBAIKAN: HAPUS .toLocal() AGAR SINKRON DENGAN ATTENDANCE SCREEN ---
              if (attendanceRes['check_in_time'] != null) {
                 _checkInTime = DateFormat('HH:mm').format(
                    DateTime.parse(attendanceRes['check_in_time']) // Hapus .toLocal()
                 );
              }

              if (attendanceRes['check_out_time'] != null) {
                _checkOutTime = DateFormat('HH:mm').format(
                    DateTime.parse(attendanceRes['check_out_time']) // Hapus .toLocal()
                );
                _attendanceStatus = 'Sudah Pulang';
              } else {
                _attendanceStatus = 'Sudah Masuk';
              }
            } else {
              _attendanceStatus = statusDb; 
              _checkInTime = '-';
              _checkOutTime = '-';
            }
          } 
          // Prioritas 3: Belum Absen
          else {
            _attendanceStatus = 'Belum Absen';
            _checkInTime = '--:--';
            _checkOutTime = '--:--';
          }
        });
      }

      // 3. Data Tugas
      final taskResponse = await supabase
          .from('tasks')
          .select('status')
          .eq('assigned_to', user.id);

      final List<dynamic> tasks = taskResponse;
      int pending = 0;
      int completed = 0;

      for (var task in tasks) {
        if (task['status'] == 'Done') completed++; else pending++;
      }

      if (mounted) {
        setState(() {
          _pendingTasks = pending;
          _completedTasks = completed;
        });
      }
    } catch (e) {
      debugPrint("Error loading dashboard: $e");
    }
  }

  // --- LOGIKA GPS ---
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

  // --- LOGIKA TOMBOL ABSEN ---
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
          'user_id': user!.id,
          'tanggal': today,
          'check_in_time': now.toIso8601String(),
          'check_in_lat': position.latitude,
          'check_in_long': position.longitude,
          'status': 'Hadir',
        });
        
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Berhasil Absen Masuk!")));
      
      } else if (_attendanceStatus == 'Sudah Masuk') {
        await supabase.from('attendances').update({
          'check_out_time': now.toIso8601String(),
        }).eq('user_id', user!.id).eq('tanggal', today);
        
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
    Color cardColor = Colors.grey.shade800;
    IconData icon = Icons.fingerprint;
    String message = "Jangan lupa Check-in hari ini!";
    String buttonText = "ABSEN MASUK (GPS)";
    bool isButtonDisabled = false;
    bool showTime = true; 

    if (_attendanceStatus == 'Sudah Masuk') {
      cardColor = Colors.green.shade700;
      icon = Icons.timer;
      message = "Selamat bekerja! Semangat!";
      buttonText = "ABSEN PULANG";
    } else if (_attendanceStatus == 'Sudah Pulang') {
      cardColor = Colors.indigo.shade700;
      icon = Icons.check_circle;
      message = "Terima kasih atas kerja kerasmu!";
      buttonText = "SELESAI";
      isButtonDisabled = true;
    } else if (_attendanceStatus != 'Belum Absen') {
      // Sakit / Izin / Cuti
      cardColor = Colors.orange.shade800;
      icon = Icons.local_hospital;
      message = "Status: $_attendanceStatus";
      buttonText = "SEDANG ${_attendanceStatus.toUpperCase()}";
      isButtonDisabled = true;
      showTime = false;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: cardColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.white, size: 30),
              const SizedBox(width: 10),
              Text(_attendanceStatus, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 15),
          Text(message, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 20),
          
          if (showTime) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Masuk", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(_checkInTime, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(width: 1, height: 30, color: Colors.white24),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text("Pulang", style: TextStyle(color: Colors.white54, fontSize: 12)),
                    Text(_checkOutTime, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],

          SizedBox(
            width: double.infinity,
            height: 45,
            child: ElevatedButton(
              onPressed: (isButtonDisabled || _isLoadingAbsen) ? null : _handleAttendance,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: cardColor,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: _isLoadingAbsen 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) 
                : Text(buttonText, style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTaskStats() {
    return Row(
      children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.orange.shade50, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.pending_actions, color: Colors.orange),
                const SizedBox(height: 10),
                Text("$_pendingTasks Tugas", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Text("Perlu Diselesaikan", style: TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.task_alt, color: Colors.green),
                const SizedBox(height: 10),
                Text("$_completedTasks Selesai", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
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
          icon: Icons.assignment_outlined, label: "Tugas Saya", color: Colors.orange,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Fitur Tugas segera hadir")))
        ),
        _menuItem(
          icon: Icons.calendar_month_outlined, label: "Izin / Cuti", color: Colors.blue,
          onTap: () async {
             // Refresh saat kembali dari halaman Izin
             final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => const PermissionScreen()));
             if (result == true) _loadDashboardData();
          }
        ),
        _menuItem(
          icon: Icons.history, label: "Riwayat", color: Colors.purple,
          onTap: () async {
             // Refresh saat kembali dari Riwayat (siapa tahu ada update)
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
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateString = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            InkWell(
              onTap: () async {
                await Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                _loadDashboardData();
              },
              child: CircleAvatar(
                backgroundColor: Colors.indigo.shade100,
                backgroundImage: _userAvatarUrl != null ? NetworkImage(_userAvatarUrl!) : null,
                child: _userAvatarUrl == null 
                  ? Text(_userName.isNotEmpty ? _userName[0].toUpperCase() : "A", style: const TextStyle(color: Colors.indigo))
                  : null,
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Halo, $_userName", style: const TextStyle(color: Colors.black87, fontSize: 16, fontWeight: FontWeight.bold)),
                Text(_userJabatan, style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _loadDashboardData,
            icon: const Icon(Icons.refresh, color: Colors.black87),
            tooltip: "Refresh Data",
          ),
        ],
      ),
      // REFRESH INDICATOR (Tarik layar ke bawah untuk refresh)
      body: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(dateString, style: TextStyle(color: Colors.grey.shade600)),
              const SizedBox(height: 20),
              _buildAttendanceCard(),
              const SizedBox(height: 30),
              const Text("Menu Cepat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildQuickMenu(),
              const SizedBox(height: 30),
              const Text("Ringkasan Tugas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildTaskStats(),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}