import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AttendanceSettingsScreen extends StatefulWidget {
  const AttendanceSettingsScreen({super.key});

  @override
  State<AttendanceSettingsScreen> createState() => _AttendanceSettingsScreenState();
}

class _AttendanceSettingsScreenState extends State<AttendanceSettingsScreen> {
  final _supabase = Supabase.instance.client;
  
  bool _isLoading = true;
  
  List<Map<String, dynamic>> _officeLocations = [];
  List<Map<String, dynamic>> _workSchedules = [];
  Map<String, dynamic>? _generalSettings;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final locationsFuture = _supabase
          .from('office_locations')
          .select()
          .order('created_at', ascending: true);
          
      final schedulesFuture = _supabase
          .from('work_schedules')
          .select()
          .order('day_of_week', ascending: true);
          
      final settingsFuture = _supabase
          .from('attendance_settings')
          .select()
          .limit(1)
          .maybeSingle();

      final results = await Future.wait([
        locationsFuture,
        schedulesFuture,
        settingsFuture,
      ]);

      if (!mounted) return;
      setState(() {
        _officeLocations = List<Map<String, dynamic>>.from(results[0] as List);
        _workSchedules = List<Map<String, dynamic>>.from(results[1] as List);
        _generalSettings = results[2] as Map<String, dynamic>?;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      _showErrorSnackBar('Gagal memuat data: ${e.toString()}');
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  // --- LOKASI KANTOR (GPS) ---

  Future<void> _toggleLocationActive(String id, bool currentValue) async {
    try {
      await _supabase
          .from('office_locations')
          .update({'is_active': !currentValue})
          .eq('id', id);
      _loadAllData();
      _showSuccessSnackBar('Status lokasi berhasil diubah');
    } catch (e) {
      _showErrorSnackBar('Gagal mengubah status lokasi: ${e.toString()}');
    }
  }

  Future<void> _deleteLocation(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Lokasi'),
        content: const Text('Apakah Anda yakin ingin menghapus lokasi ini?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _supabase.from('office_locations').delete().eq('id', id);
      _loadAllData();
      _showSuccessSnackBar('Lokasi berhasil dihapus');
    } catch (e) {
      _showErrorSnackBar('Gagal menghapus lokasi: ${e.toString()}');
    }
  }

  void _showLocationDialog({Map<String, dynamic>? location}) {
    final isEdit = location != null;
    final nameCtrl = TextEditingController(text: isEdit ? location['nama'] : '');
    final latCtrl = TextEditingController(text: isEdit ? location['latitude'].toString() : '');
    final lngCtrl = TextEditingController(text: isEdit ? location['longitude'].toString() : '');
    final radiusCtrl = TextEditingController(text: isEdit ? location['radius_meter'].toString() : '100');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(isEdit ? 'Edit Lokasi' : 'Tambah Lokasi'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Lokasi'),
                ),
                TextField(
                  controller: latCtrl,
                  decoration: const InputDecoration(labelText: 'Latitude'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: lngCtrl,
                  decoration: const InputDecoration(labelText: 'Longitude'),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                ),
                TextField(
                  controller: radiusCtrl,
                  decoration: const InputDecoration(labelText: 'Radius (Meter)'),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nama = nameCtrl.text.trim();
                final lat = double.tryParse(latCtrl.text);
                final lng = double.tryParse(lngCtrl.text);
                final radius = int.tryParse(radiusCtrl.text);

                if (nama.isEmpty || lat == null || lng == null || radius == null) {
                  _showErrorSnackBar('Mohon isi semua data dengan benar');
                  return;
                }

                Navigator.pop(context);

                final data = {
                  'nama': nama,
                  'latitude': lat,
                  'longitude': lng,
                  'radius_meter': radius,
                };

                try {
                  if (isEdit) {
                    await _supabase
                        .from('office_locations')
                        .update(data)
                        .eq('id', location['id']);
                    _showSuccessSnackBar('Lokasi berhasil diubah');
                  } else {
                    data['is_active'] = true;
                    await _supabase.from('office_locations').insert(data);
                    _showSuccessSnackBar('Lokasi berhasil ditambahkan');
                  }
                  _loadAllData();
                } catch (e) {
                  _showErrorSnackBar('Gagal menyimpan lokasi: ${e.toString()}');
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }

  // --- JADWAL JAM KERJA ---

  Future<void> _toggleScheduleActive(String id, bool currentValue) async {
    try {
      await _supabase
          .from('work_schedules')
          .update({'is_active': !currentValue})
          .eq('id', id);
      _loadAllData();
      _showSuccessSnackBar('Status jadwal berhasil diubah');
    } catch (e) {
      _showErrorSnackBar('Gagal mengubah status jadwal: ${e.toString()}');
    }
  }

  void _showScheduleDialog(Map<String, dynamic> schedule) {
    TimeOfDay parseTime(String? timeStr) {
      if (timeStr == null || timeStr.isEmpty) return const TimeOfDay(hour: 0, minute: 0);
      final parts = timeStr.split(':');
      if (parts.length >= 2) {
        return TimeOfDay(hour: int.tryParse(parts[0]) ?? 0, minute: int.tryParse(parts[1]) ?? 0);
      }
      return const TimeOfDay(hour: 0, minute: 0);
    }

    String formatTime(TimeOfDay time) {
      final h = time.hour.toString().padLeft(2, '0');
      final m = time.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }

    TimeOfDay bukaTime = parseTime(schedule['jam_buka_absen']);
    TimeOfDay masukTime = parseTime(schedule['jam_masuk']);
    TimeOfDay pulangTime = parseTime(schedule['jam_pulang']);
    final toleransiCtrl = TextEditingController(text: schedule['toleransi_menit']?.toString() ?? '0');

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text('Edit Jadwal - ${schedule['nama_hari']}'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ListTile(
                      title: const Text('Jam Buka Absen'),
                      trailing: Text(formatTime(bukaTime)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: bukaTime,
                        );
                        if (time != null) setDialogState(() => bukaTime = time);
                      },
                    ),
                    ListTile(
                      title: const Text('Jam Masuk'),
                      trailing: Text(formatTime(masukTime)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: masukTime,
                        );
                        if (time != null) setDialogState(() => masukTime = time);
                      },
                    ),
                    TextField(
                      controller: toleransiCtrl,
                      decoration: const InputDecoration(labelText: 'Toleransi Keterlambatan (Menit)'),
                      keyboardType: TextInputType.number,
                    ),
                    ListTile(
                      title: const Text('Jam Pulang'),
                      trailing: Text(formatTime(pulangTime)),
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: pulangTime,
                        );
                        if (time != null) setDialogState(() => pulangTime = time);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final toleransi = int.tryParse(toleransiCtrl.text);
                    if (toleransi == null) {
                      _showErrorSnackBar('Toleransi harus berupa angka');
                      return;
                    }

                    Navigator.pop(context);

                    try {
                      await _supabase.from('work_schedules').update({
                        'jam_buka_absen': formatTime(bukaTime),
                        'jam_masuk': formatTime(masukTime),
                        'toleransi_menit': toleransi,
                        'jam_pulang': formatTime(pulangTime),
                      }).eq('id', schedule['id']);
                      
                      _showSuccessSnackBar('Jadwal berhasil diubah');
                      _loadAllData();
                    } catch (e) {
                      _showErrorSnackBar('Gagal menyimpan jadwal: ${e.toString()}');
                    }
                  },
                  child: const Text('Simpan'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  // --- PENGATURAN UMUM ---

  Future<void> _toggleGeneralSettingsRequireGps(bool value) async {
    if (_generalSettings == null) return;
    try {
      await _supabase
          .from('attendance_settings')
          .update({'checkout_require_gps': value})
          .eq('id', _generalSettings!['id']);
      _loadAllData();
      _showSuccessSnackBar('Pengaturan berhasil diperbarui');
    } catch (e) {
      _showErrorSnackBar('Gagal mengubah pengaturan: ${e.toString()}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadAllData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader(Icons.location_on, 'Lokasi Kantor (GPS)'),
                    _buildOfficeLocations(),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader(Icons.schedule, 'Jadwal Jam Kerja'),
                    _buildWorkSchedules(),
                    const SizedBox(height: 24),
                    
                    _buildSectionHeader(Icons.settings, 'Pengaturan Umum'),
                    _buildGeneralSettings(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSectionHeader(IconData icon, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.indigo.shade900),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.indigo.shade900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOfficeLocations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_officeLocations.isEmpty)
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Belum ada lokasi kantor.', style: TextStyle(color: Colors.grey)),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _officeLocations.length,
            itemBuilder: (context, index) {
              final loc = _officeLocations[index];
              final isActive = loc['is_active'] ?? false;
              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 8.0),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(loc['nama'] ?? 'Tanpa Nama', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Lat: ${loc['latitude']}\nLng: ${loc['longitude']}\nRadius: ${loc['radius_meter']} m'),
                  isThreeLine: true,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit, color: Colors.blue),
                        onPressed: () => _showLocationDialog(location: loc),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _deleteLocation(loc['id']),
                      ),
                      Switch(
                        value: isActive,
                        onChanged: (val) => _toggleLocationActive(loc['id'], isActive),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: () => _showLocationDialog(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Lokasi'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.indigo.shade100,
            foregroundColor: Colors.indigo.shade900,
          ),
        ),
      ],
    );
  }

  Widget _buildWorkSchedules() {
    if (_workSchedules.isEmpty) {
      return const Text('Data jadwal tidak ditemukan.', style: TextStyle(color: Colors.grey));
    }
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _workSchedules.length,
      itemBuilder: (context, index) {
        final schedule = _workSchedules[index];
        final isActive = schedule['is_active'] ?? false;
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 8.0),
          color: isActive ? Colors.white : Colors.grey.shade200,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ListTile(
            title: Text(
              schedule['nama_hari'] ?? '',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: isActive ? Colors.black : Colors.grey.shade600,
              ),
            ),
            subtitle: Text(
              'Buka: ${schedule['jam_buka_absen'] ?? '-'} | Masuk: ${schedule['jam_masuk'] ?? '-'}\n'
              'Toleransi: ${schedule['toleransi_menit'] ?? 0} mnt | Pulang: ${schedule['jam_pulang'] ?? '-'}',
              style: TextStyle(color: isActive ? Colors.black87 : Colors.grey.shade600),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: Colors.blue),
                  onPressed: () => _showScheduleDialog(schedule),
                ),
                Switch(
                  value: isActive,
                  onChanged: (val) => _toggleScheduleActive(schedule['id'], isActive),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildGeneralSettings() {
    if (_generalSettings == null) {
      return const Text('Pengaturan umum tidak ditemukan.', style: TextStyle(color: Colors.grey));
    }
    
    final requireGps = _generalSettings!['checkout_require_gps'] ?? false;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: SwitchListTile(
        title: const Text('Wajib GPS saat Check-out', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Jika aktif, karyawan harus berada di area kantor untuk check-out'),
        value: requireGps,
        onChanged: (val) => _toggleGeneralSettingsRequireGps(val),
        activeTrackColor: Colors.indigo.shade200,
      ),
    );
  }
}
