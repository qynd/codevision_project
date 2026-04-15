import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../data/models/performance_model.dart';

class AdminPerformanceScreen extends StatefulWidget {
  const AdminPerformanceScreen({super.key});

  @override
  State<AdminPerformanceScreen> createState() => _AdminPerformanceScreenState();
}

class _AdminPerformanceScreenState extends State<AdminPerformanceScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  bool _isCalculating = false;
  
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  List<PerformanceModel> _performances = [];

  final List<String> _monthNames = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  @override
  void initState() {
    super.initState();
    _fetchPerformances();
  }

  Future<void> _fetchPerformances() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('employee_performances')
          .select('*, users!fk_performance_user(nama)')
          .eq('bulan', _selectedMonth)
          .eq('tahun', _selectedYear)
          .order('total_poin', ascending: false);

      final List<PerformanceModel> loaded = (response as List<dynamic>)
          .map((e) => PerformanceModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _performances = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching performances: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _kalkulasiOtomatis() async {
    setState(() => _isCalculating = true);
    try {
      // 1. Ambil daftar pegawai yang aktif (memakai ilike agar tidak sensitif huruf besar/kecil)
      final usersRes = await supabase.from('users').select('id, nama').ilike('role', '%egawai%');
      final List<dynamic> users = usersRes as List<dynamic>;

      // --- KONFIGURASI BOBOT POIN ---
      // Silakan ubah angka di bawah ini untuk mengatur fleksibilitas poin
      final int bobotKehadiran = 2; // Contoh: 1 kali hadir = 2 Poin
      final int bobotTugas = 5;     // Contoh: 1 tugas selesai = 5 Poin
      // ------------------------------

      // Bikin rentang tanggal untuk bulan/tahun terpilih
      final startDate = DateTime(_selectedYear, _selectedMonth, 1).toIso8601String();
      final endDate = DateTime(_selectedYear, _selectedMonth + 1, 0, 23, 59, 59).toIso8601String(); 

      for (var user in users) {
        final userId = user['id'];

        // 2. Hitung poin Absen (Kehadiran: Hadir) dikali bobot
        final absenRes = await supabase
            .from('attendances')
            .select('id')
            .eq('user_id', userId)
            .eq('status', 'Hadir')
            .gte('tanggal', startDate)
            .lte('tanggal', endDate);
        int totalHadir = (absenRes as List<dynamic>).length;
        int poinAbsen = totalHadir * bobotKehadiran;

        // 3. Hitung poin Tugas (Tasks: Done) dikali bobot
        // Kita asumsikan tugas yang deadline atau created_at berada di rentang ini.
        final tasksRes = await supabase
            .from('tasks')
            .select('id')
            .eq('assigned_to', userId)
            .eq('status', 'Done')
            .gte('created_at', startDate)
            .lte('created_at', endDate);
        int totalTugasDone = (tasksRes as List<dynamic>).length;
        int poinTugas = totalTugasDone * bobotTugas;

        // 4. Upsert (Update or Insert) ke tabel employee_performances
        final existingMatch = await supabase
            .from('employee_performances')
            .select('id')
            .eq('user_id', userId)
            .eq('bulan', _selectedMonth)
            .eq('tahun', _selectedYear)
            .maybeSingle();

        if (existingMatch != null) {
          // Update
          await supabase.from('employee_performances').update({
            'poin_tugas': poinTugas,
            'poin_absen': poinAbsen,
          }).eq('id', existingMatch['id']);
        } else {
          // Insert
          await supabase.from('employee_performances').insert({
            'user_id': userId,
            'bulan': _selectedMonth,
            'tahun': _selectedYear,
            'poin_tugas': poinTugas,
            'poin_absen': poinAbsen,
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Kalkulasi Kinerja Selesai!"), backgroundColor: Colors.green),
        );
        _fetchPerformances(); // Refresh data
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal kalkulasi: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isCalculating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Penilaian Kinerja Pegawai"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // Filter Section
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Bulan', border: OutlineInputBorder()),
                    initialValue: _selectedMonth,
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(value: index + 1, child: Text(_monthNames[index + 1]));
                    }),
                    onChanged: (val) {
                      setState(() => _selectedMonth = val!);
                      _fetchPerformances();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    decoration: const InputDecoration(labelText: 'Tahun', border: OutlineInputBorder()),
                    initialValue: _selectedYear,
                    items: [DateTime.now().year - 1, DateTime.now().year, DateTime.now().year + 1]
                        .map((year) => DropdownMenuItem(value: year, child: Text(year.toString())))
                        .toList(),
                    onChanged: (val) {
                      setState(() => _selectedYear = val!);
                      _fetchPerformances();
                    },
                  ),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),

          // Info Banner
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade50,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "Poin dihitung otomatis berdasarkan total Presensi (Hadir) dan Tugas yang Selesai.",
                    style: TextStyle(color: Colors.amber.shade900, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          // Leaderboard List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _performances.isEmpty
                    ? const Center(child: Text("Belum ada data kinerja untuk periode ini. Silakan Kalkulasi."))
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _performances.length,
                        itemBuilder: (context, index) {
                          final perf = _performances[index];
                          // Emas, Perak, Perunggu untuk top 3
                          Color? medalColor;
                          if (index == 0) medalColor = Colors.amber;
                          if (index == 1) medalColor = Colors.grey.shade400;
                          if (index == 2) medalColor = Colors.brown.shade400;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: medalColor != null ? 3 : 1,
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: medalColor ?? Colors.indigo.shade100,
                                foregroundColor: medalColor != null ? Colors.white : Colors.indigo.shade900,
                                child: Text("${index + 1}"),
                              ),
                              title: Text(perf.userName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text("Absen: ${perf.poinAbsen} Poin | Tugas: ${perf.poinTugas} Poin"),
                              trailing: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text("Total", style: TextStyle(fontSize: 10, color: Colors.grey)),
                                  Text(
                                    "${perf.totalPoin}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: medalColor ?? Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isCalculating ? null : _kalkulasiOtomatis,
        icon: _isCalculating 
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.calculate),
        label: const Text("Kalkulasi Otomatis"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
    );
  }
}
