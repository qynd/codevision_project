import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'permission_screen.dart';
import 'attendance_history_screen.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;

  String? _attendanceId;
  DateTime? _checkInTime;
  DateTime? _checkOutTime;
  String _currentStatus = '';
  int _durasiCuti = 0;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _getTodayAttendance();
    });
  }

  Future<void> _getTodayAttendance() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final data = await supabase
          .from('attendances')
          .select()
          .eq('user_id', user.id)
          .eq('tanggal', today)
          .maybeSingle();

      if (data != null) {
        if (mounted) {
          setState(() {
            _attendanceId = data['id'];
            _checkInTime = DateTime.parse(data['check_in_time']);
            _currentStatus = data['status'] ?? 'Hadir';
            _durasiCuti = data['durasi'] ?? 1;

            if (data['check_out_time'] != null) {
              _checkOutTime = DateTime.parse(data['check_out_time']);
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error getting attendance: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<Position?> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return null;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return null;
    }

    if (permission == LocationPermission.deniedForever) return null;

    try {
      return await Geolocator.getCurrentPosition(
        timeLimit: const Duration(seconds: 10),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);
    final pos = await _getCurrentLocation();

    if (pos == null) {
      setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mengambil lokasi. Pastikan GPS aktif."),
          ),
        );
      return;
    }

    try {
      final user = supabase.auth.currentUser!;
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      final response = await supabase
          .from('attendances')
          .insert({
            'user_id': user.id,
            'tanggal': today,
            'check_in_time': now.toIso8601String(),
            'check_in_lat': pos.latitude,
            'check_in_long': pos.longitude,
            'status': 'Hadir',
            'durasi': 1,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          _attendanceId = response['id'];
          _checkInTime = now;
          _currentStatus = 'Hadir';
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil Check-in!")));
      }
    } catch (e) {
      if (e.toString().contains('duplicate key') ||
          e.toString().contains('23505')) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data sudah ada, memuat ulang...")),
          );
          await _getTodayAttendance();
        }
      } else {
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_attendanceId == null) return;
    setState(() => _isLoading = true);
    try {
      final now = DateTime.now();
      await supabase
          .from('attendances')
          .update({'check_out_time': now.toIso8601String()})
          .eq('id', _attendanceId!);

      if (mounted) {
        setState(() {
          _checkOutTime = now;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text("Berhasil Check-out!")));
      }
    } catch (e) {
      // Handle error
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _goToPermissionScreen() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const PermissionScreen()),
    );
    if (result == true) {
      _getTodayAttendance();
    }
  }

  Widget _buildTimeCard(
    String label,
    String? timeString,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.shade100,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              timeString ?? "--:--",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: timeString != null
                    ? Colors.black87
                    : Colors.grey.shade400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final timeFormat = DateFormat('HH:mm', 'id_ID');

    String headlineText = "Silakan Check-in";
    if (_checkInTime != null) {
      if (_currentStatus == 'Hadir') {
        headlineText = _checkOutTime != null
            ? "Selesai Bekerja"
            : "Sedang Bekerja";
      } else if (_currentStatus == 'Cuti') {
        headlineText = "Cuti ($_durasiCuti Hari)";
      } else {
        headlineText = "Sedang $_currentStatus";
      }
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,

      // --- PERHATIKAN STRUKTUR APPBAR INI ---
      appBar: AppBar(
        title: const Text('Absensi Harian'), // Judul ada di sini
        actions: [
          // Actions ada DI DALAM AppBar, setelah Title
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const AttendanceHistoryScreen(),
                ),
              );
            },
            icon: const Icon(Icons.history, color: Colors.black87),
            tooltip: 'Lihat Riwayat',
          ),
        ],
      ),

      // --------------------------------------
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    headlineText,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: _currentStatus == 'Hadir'
                          ? Colors.indigo
                          : Colors.orange,
                    ),
                  ),
                  Text(
                    DateFormat(
                      'EEEE, d MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.now()),
                    style: const TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 40),

                  if (_currentStatus == 'Hadir' || _checkInTime == null)
                    Row(
                      children: [
                        _buildTimeCard(
                          "Waktu Masuk",
                          _checkInTime != null
                              ? timeFormat.format(_checkInTime!)
                              : null,
                          Icons.login,
                          Colors.green,
                        ),
                        const SizedBox(width: 16),
                        _buildTimeCard(
                          "Waktu Keluar",
                          _checkOutTime != null
                              ? timeFormat.format(_checkOutTime!)
                              : null,
                          Icons.logout,
                          Colors.red,
                        ),
                      ],
                    ),

                  if (_currentStatus != 'Hadir' && _checkInTime != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 40,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            "Anda telah mengajukan $_currentStatus${_currentStatus == 'Cuti' ? " selama $_durasiCuti hari." : "."}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 50),

                  if (_checkInTime == null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _handleCheckIn,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text("CHECK-IN MASUK"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _goToPermissionScreen,
                      child: const Text("Tidak bisa hadir? Ajukan Cuti/Izin"),
                    ),
                  ] else if (_currentStatus == 'Hadir' &&
                      _checkOutTime == null) ...[
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _handleCheckOut,
                        icon: const Icon(Icons.exit_to_app),
                        label: const Text("CHECK-OUT PULANG"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}
