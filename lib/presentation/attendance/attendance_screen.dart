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
  int _hariKe = 1;

  // --- STATE BARU: Konfigurasi Absensi ---
  Map<String, dynamic>? _todaySchedule;
  List<Map<String, dynamic>> _officeLocations = [];
  bool _checkoutRequireGps = false;
  bool _isOffDay = false;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('id_ID', null).then((_) {
      _loadAttendanceConfig().then((_) {
        _getTodayAttendance();
      });
    });
  }

  // --- BARU: Muat konfigurasi absensi dari database ---
  Future<void> _loadAttendanceConfig() async {
    try {
      final dayOfWeek = DateTime.now().weekday; // 1=Senin...7=Minggu

      // Ambil jadwal hari ini
      final scheduleData = await supabase
          .from('work_schedules')
          .select()
          .eq('day_of_week', dayOfWeek)
          .limit(1)
          .maybeSingle();

      // Ambil lokasi kantor aktif
      final locationsData = await supabase
          .from('office_locations')
          .select()
          .eq('is_active', true);

      // Ambil pengaturan umum
      final settingsData = await supabase
          .from('attendance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _todaySchedule = scheduleData;
          _officeLocations = List<Map<String, dynamic>>.from(locationsData);
          _checkoutRequireGps = settingsData?['checkout_require_gps'] ?? false;
          _isOffDay = !(scheduleData?['is_active'] ?? true);
        });
      }
    } catch (e) {
      debugPrint("Error loading attendance config: $e");
    }
  }

  // --- Helper: Parse waktu dari string "HH:mm" ---
  DateTime _parseTimeToday(String timeStr) {
    final now = DateTime.now();
    final parts = timeStr.split(':');
    return DateTime(now.year, now.month, now.day, 
        int.parse(parts[0]), int.parse(parts[1]));
  }

  // --- Helper: Cek apakah dalam jam kerja ---
  bool _isWithinWorkHours() {
    if (_todaySchedule == null) return true;
    final now = DateTime.now();
    final jamBuka = _parseTimeToday(_todaySchedule!['jam_buka_absen'] ?? '07:00');
    final jamPulang = _parseTimeToday(_todaySchedule!['jam_pulang'] ?? '16:00');
    return !now.isBefore(jamBuka) && now.isBefore(jamPulang);
  }

  // --- Helper: Validasi GPS terhadap lokasi kantor ---
  /// Returns null jika valid, atau pesan error jika di luar radius
  String? _validateGpsAgainstOffices(Position pos) {
    if (_officeLocations.isEmpty) return null; // Tidak ada lokasi = tidak perlu validasi

    double nearestDistance = double.infinity;
    String nearestName = '';

    for (final loc in _officeLocations) {
      final distance = Geolocator.distanceBetween(
        pos.latitude, pos.longitude,
        (loc['latitude'] as num).toDouble(),
        (loc['longitude'] as num).toDouble(),
      );
      final radius = (loc['radius_meter'] as num?)?.toDouble() ?? 100.0;

      if (distance <= radius) {
        return null; // Dalam radius, valid
      }
      if (distance < nearestDistance) {
        nearestDistance = distance;
        nearestName = loc['nama'] ?? 'Unknown';
      }
    }

    return "Anda di luar area kantor. Lokasi terdekat: $nearestName (${nearestDistance.toStringAsFixed(0)}m)";
  }

  Future<void> _getTodayAttendance() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 1. Cek Data Absensi (Hadir/Telat)
      final attendanceData = await supabase
          .from('attendances')
          .select()
          .eq('user_id', user.id)
          .eq('tanggal', today)
          .limit(1)
          .maybeSingle();

      // 2. Cek Data Izin/Sakit/Cuti (Letters)
      final letterData = await supabase
          .from('letters')
          .select()
          .eq('user_id', user.id)
          .lte('tanggal_mulai', today)
          .gte('tanggal_selesai', today)
          .neq('status', 'Rejected') // UBAH QUERY: Ambil juga yang Pending
          .limit(1)
          .maybeSingle();

      if (mounted) {
        setState(() {
          if (attendanceData != null) {
            _attendanceId = attendanceData['id'];
            _checkInTime = DateTime.parse(attendanceData['check_in_time']);
            _currentStatus = attendanceData['status'] ?? 'Hadir';
            _durasiCuti = attendanceData['durasi'] ?? 1;

            if (_currentStatus == 'Cuti' && letterData != null) {
              try {
                final start = DateTime.parse(letterData['tanggal_mulai']);
                final end = DateTime.parse(letterData['tanggal_selesai']);
                final todayDate = DateTime.parse(today);
                
                final int calculatedTotal = end.difference(start).inDays + 1;
                _durasiCuti = calculatedTotal > 0 ? calculatedTotal : 1;
                
                _hariKe = (todayDate.difference(start).inDays + 1).clamp(1, _durasiCuti);
              } catch (e) {
                debugPrint("Error parsing leave dates: $e");
              }
            }

            if (attendanceData['check_out_time'] != null) {
              _checkOutTime = DateTime.parse(attendanceData['check_out_time']);
            }
          } else if (letterData != null) {
            // Jika tidak ada absen tapi ada Izin/Sakit
            String jenis = letterData['jenis_surat'] ?? 'Izin';
            String status = letterData['status'] ?? 'Pending';
            _currentStatus = status == 'Pending' ? "$jenis (Menunggu)" : jenis;
            _attendanceId = null; // Tidak ada ID absen
            _checkInTime = null;
            _checkOutTime = null;
          } else {
            // Reset jika tidak ada data sama sekali
            _attendanceId = null;
            _checkInTime = null;
            _checkOutTime = null;
            _currentStatus = '';
          }
        });
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
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleCheckIn() async {
    setState(() => _isLoading = true);

    // --- VALIDASI HARI LIBUR ---
    if (_isOffDay) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Hari ini libur, absensi tidak dibuka."),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // --- VALIDASI WAKTU ---
    if (_todaySchedule != null) {
      final now = DateTime.now();
      final jamBukaStr = _todaySchedule!['jam_buka_absen'] as String? ?? '07:00';
      final jamPulangStr = _todaySchedule!['jam_pulang'] as String? ?? '16:00';
      final jamBuka = _parseTimeToday(jamBukaStr);
      final jamPulang = _parseTimeToday(jamPulangStr);

      if (now.isBefore(jamBuka)) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Absensi belum dibuka. Silakan coba setelah jam $jamBukaStr."),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      if (!now.isBefore(jamPulang)) {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Waktu absensi sudah ditutup (setelah jam $jamPulangStr)."),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // --- AMBIL LOKASI GPS ---
    final pos = await _getCurrentLocation();

    if (pos == null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Gagal mengambil lokasi. Pastikan GPS aktif."),
          ),
        );
      }
      return;
    }

    // --- VALIDASI GPS GEOFENCING ---
    final gpsError = _validateGpsAgainstOffices(pos);
    if (gpsError != null) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(gpsError),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    try {
      final user = supabase.auth.currentUser!;
      final now = DateTime.now();
      final today = DateFormat('yyyy-MM-dd').format(now);

      // --- CEK APAKAH SEDANG IZIN/SAKIT/CUTI (Pre-Check) ---
      final letterRes = await supabase
          .from('letters')
          .select()
          .eq('user_id', user.id)
          .lte('tanggal_mulai', today)
          .gte('tanggal_selesai', today)
          .neq('status', 'Rejected')
          .limit(1)
          .maybeSingle();

      if (letterRes != null) {
        if (mounted) {
          final jenis = letterRes['jenis_surat'] ?? 'Izin';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "GAGAL: Anda sedang status $jenis. Tidak dapat Absen Masuk.",
              ),
              backgroundColor: Colors.red,
            ),
          );
          _getTodayAttendance();
        }
        setState(() => _isLoading = false);
        return;
      }
      // -----------------------------------------------------

      // --- CEK DUPLIKASI ---
      final existingCheck = await supabase
          .from('attendances')
          .select()
          .eq('user_id', user.id)
          .eq('tanggal', today)
          .limit(1)
          .maybeSingle();
      if (existingCheck != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data diperbarui (Anda sudah absen)."),
            ),
          );
        }
        _getTodayAttendance(); // Refresh UI
        return;
      }
      // --------------------

      // --- TENTUKAN STATUS: HADIR atau TELAT ---
      String checkInStatus = 'Hadir';
      if (_todaySchedule != null) {
        final jamMasukStr = _todaySchedule!['jam_masuk'] as String? ?? '08:00';
        final toleransi = (_todaySchedule!['toleransi_menit'] as num?)?.toInt() ?? 15;
        final masukParts = jamMasukStr.split(':');
        final batasTelat = DateTime(
          now.year, now.month, now.day,
          int.parse(masukParts[0]),
          int.parse(masukParts[1]) + toleransi,
        );
        if (now.isAfter(batasTelat)) {
          checkInStatus = 'Telat';
        }
      }

      final response = await supabase
          .from('attendances')
          .insert({
            'user_id': user.id,
            'tanggal': today,
            'check_in_time': now.toIso8601String(),
            'check_in_lat': pos.latitude,
            'check_in_long': pos.longitude,
            'status': checkInStatus,
            'durasi': 1,
          })
          .select()
          .single();

      if (mounted) {
        setState(() {
          _attendanceId = response['id'];
          _checkInTime = now;
          _currentStatus = checkInStatus;
        });
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(
          content: Text(checkInStatus == 'Telat' 
            ? "Check-in berhasil, tapi Anda TERLAMBAT!" 
            : "Berhasil Check-in!"),
          backgroundColor: checkInStatus == 'Telat' ? Colors.orange : null,
        ));
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
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text("Error: $e")));
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleCheckOut() async {
    if (_attendanceId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Error: ID Absensi tidak ditemukan. Silakan refresh halaman.",
            ),
          ),
        );
      }
      await _getTodayAttendance(); // Coba ambil lagi siapa tahu ada
      return;
    }
    setState(() => _isLoading = true);
    try {
      // --- CEK APAKAH SUDAH CHECK OUT ---
      final existingData = await supabase
          .from('attendances')
          .select('check_out_time')
          .eq('id', _attendanceId!)
          .limit(1)
          .maybeSingle();

      if (existingData != null && existingData['check_out_time'] != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Data diperbarui (Anda sudah pulang)."),
            ),
          );
          setState(
            () =>
                _checkOutTime = DateTime.parse(existingData['check_out_time']),
          );
        }
        return;
      }
      // ----------------------------------

      // --- VALIDASI GPS CHECK-OUT (jika diaktifkan admin) ---
      if (_checkoutRequireGps) {
        final pos = await _getCurrentLocation();
        if (pos == null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Gagal mengambil lokasi. Pastikan GPS aktif."),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        final gpsError = _validateGpsAgainstOffices(pos);
        if (gpsError != null) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text("Check-out harus di area kantor. ${gpsError.replaceFirst('Anda di luar area kantor. ', '')}"),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }
      // -------------------------------------------------------

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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error check-out: $e")),
        );
      }
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

    // --- HEADLINE TEXT LOGIC (UPDATED) ---
    String headlineText = "Silakan Check-in";
    Color headlineColor = Colors.indigo;

    if (_isOffDay && _checkInTime == null && _currentStatus == '') {
      headlineText = "Hari Ini Libur 🏖️";
      headlineColor = Colors.blue;
    } else if (_checkInTime != null) {
      if (_currentStatus == 'Hadir' || _currentStatus == 'Telat') {
        if (_checkOutTime != null) {
          headlineText = "Selesai Bekerja";
          headlineColor = Colors.green;
        } else {
          headlineText = _currentStatus == 'Telat' ? "Sedang Bekerja (Telat)" : "Sedang Bekerja";
          headlineColor = _currentStatus == 'Telat' ? Colors.orange : Colors.indigo;
        }
      } else if (_currentStatus == 'Cuti') {
        if (_durasiCuti > 1) {
          headlineText = "Cuti (Hari ke-$_hariKe dari $_durasiCuti Hari)";
        } else {
          headlineText = "Cuti (1 Hari)";
        }
        headlineColor = Colors.orange;
      } else {
        headlineText = "Sedang $_currentStatus";
        headlineColor = Colors.orange;
      }
    } else if (_todaySchedule != null && _currentStatus == '') {
      final now = DateTime.now();
      final jamBukaStr = _todaySchedule!['jam_buka_absen'] as String? ?? '07:00';
      final jamPulangStr = _todaySchedule!['jam_pulang'] as String? ?? '16:00';
      final jamBuka = _parseTimeToday(jamBukaStr);
      final jamPulang = _parseTimeToday(jamPulangStr);

      if (now.isBefore(jamBuka)) {
        headlineText = "Absensi Dibuka Jam $jamBukaStr";
        headlineColor = Colors.grey;
      } else if (!now.isBefore(jamPulang)) {
        headlineText = "Waktu Absensi Sudah Lewat";
        headlineColor = Colors.red;
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
                      color: headlineColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    DateFormat(
                      'EEEE, d MMMM yyyy',
                      'id_ID',
                    ).format(DateTime.now()),
                    style: const TextStyle(color: Colors.grey),
                  ),

                  // --- BARU: Info Jam Kerja ---
                  if (_todaySchedule != null && !_isOffDay)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            "Jam Kerja: ${_todaySchedule!['jam_buka_absen'] ?? '07:00'} - ${_todaySchedule!['jam_pulang'] ?? '16:00'}",
                            style: const TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 40),

                  // --- BARU: Info Hari Libur ---
                  if (_isOffDay && _currentStatus == '' && _checkInTime == null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      margin: const EdgeInsets.symmetric(vertical: 20),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: const Column(
                        children: [
                          Icon(Icons.beach_access, color: Colors.blue, size: 50),
                          SizedBox(height: 10),
                          Text(
                            "Hari ini adalah hari libur.\nAbsensi tidak dibuka.",
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.blue),
                          ),
                        ],
                      ),
                    ),

                  if ((_currentStatus == 'Hadir' || _currentStatus == 'Telat' || _currentStatus == '') ||
                      (_checkInTime == null && _currentStatus == ''))
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

                  if (_currentStatus != 'Hadir' && _currentStatus != 'Telat' && _checkInTime != null)
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
                            "Anda telah mengajukan $_currentStatus${_currentStatus == 'Cuti' ? (_durasiCuti > 1 ? " (Hari ke-$_hariKe dari $_durasiCuti Hari)." : " selama 1 hari.") : "."}",
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 50),

                  // --- UPDATED: Tombol Check-in hanya tampil jika dalam jam kerja & bukan hari libur ---
                  if (_checkInTime == null && _currentStatus == '' && !_isOffDay && _isWithinWorkHours()) ...[
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
                  ] else if ((_currentStatus == 'Hadir' || _currentStatus == 'Telat') &&
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
