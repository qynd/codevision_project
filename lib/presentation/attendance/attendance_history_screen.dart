import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() => _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final supabase = Supabase.instance.client;

  // Mengambil dan Menggabungkan Data (Attendances + Letters)
  Future<List<Map<String, dynamic>>> _fetchHistory() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // 1. Ambil Data Hadir (Attendances)
      final attendanceRes = await supabase
          .from('attendances')
          .select()
          .eq('user_id', user.id)
          .order('tanggal', ascending: false)
          .limit(30);

      // 2. Ambil Data Izin/Sakit (Letters) yang sudah DIS TUIJUI (Approved)
      // Kita hanya ambil yang approved agar valid sebagai riwayat
      final lettersRes = await supabase
          .from('letters')
          .select()
          .eq('user_id', user.id)
          .eq('status', 'Approved') // Hanya yang Approved
          .order('created_at', ascending: false)
          .limit(30);

      // 3. Normalisasi & Gabungkan Data
      List<Map<String, dynamic>> combinedList = [];

      // Masukkan data Hadir
      for (var item in attendanceRes) {
        combinedList.add({
          'type': 'attendance', // Penanda
          'tanggal': item['tanggal'],
          'status': 'Hadir',
          'check_in': item['check_in_time'],
          'check_out': item['check_out_time'],
        });
      }

      // Masukkan data Surat (Izin/Sakit)
      for (var item in lettersRes) {
        // Surat biasanya punya rentang tanggal, kita ambil tanggal mulainya saja untuk display di list
        combinedList.add({
          'type': 'letter', // Penanda
          'tanggal': item['tanggal_mulai'], 
          'status': item['jenis_surat'] ?? 'Izin',
          'keterangan': item['keterangan'] ?? '-',
        });
      }

      // 4. Urutkan Lagi Gabungan Data berdasarkan Tanggal (Terbaru di atas)
      combinedList.sort((a, b) {
        DateTime dateA = DateTime.parse(a['tanggal']);
        DateTime dateB = DateTime.parse(b['tanggal']);
        return dateB.compareTo(dateA); // Descending
      });

      return combinedList;

    } catch (e) {
      debugPrint("Error fetch history: $e");
      return [];
    }
  }

  // Helper warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Hadir': return Colors.green;
      case 'Izin': return Colors.blue;
      case 'Sakit': return Colors.orange;
      case 'Cuti': return Colors.purple;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Absensi'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black87,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchHistory(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Belum ada riwayat absensi"),
                ],
              ),
            );
          }

          final logs = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: logs.length,
            separatorBuilder: (ctx, i) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final log = logs[index];
              final tanggal = DateTime.parse(log['tanggal']);
              final fmtTanggal = DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tanggal);
              final status = log['status'];

              // Format Jam (Hanya untuk Hadir)
              String jamMasuk = '-';
              String jamPulang = '-';
              if (log['type'] == 'attendance') {
                 jamMasuk = log['check_in'] != null ? DateFormat('HH:mm').format(DateTime.parse(log['check_in']).toLocal()) : '-';
                 jamPulang = log['check_out'] != null ? DateFormat('HH:mm').format(DateTime.parse(log['check_out']).toLocal()) : '-';
              }

              return Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  child: Row(
                    children: [
                      // Kolom Tanggal (Kiri)
                      Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              DateFormat('d').format(tanggal),
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: _getStatusColor(status)),
                            ),
                            Text(
                              DateFormat('MMM', 'id_ID').format(tanggal),
                              style: TextStyle(fontSize: 10, color: _getStatusColor(status)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Kolom Detail (Tengah)
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fmtTanggal,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 6),
                            
                            // Tampilan Beda antara 'Hadir' dan 'Surat'
                            if (log['type'] == 'attendance')
                              Row(
                                children: [
                                  Icon(Icons.login, size: 14, color: Colors.green[700]),
                                  const SizedBox(width: 4),
                                  Text(jamMasuk, style: const TextStyle(fontSize: 12)),
                                  const SizedBox(width: 12),
                                  Icon(Icons.logout, size: 14, color: Colors.red[700]),
                                  const SizedBox(width: 4),
                                  Text(jamPulang, style: const TextStyle(fontSize: 12)),
                                ],
                              )
                            else
                              Text(
                                "Keterangan: ${log['keterangan']}",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12, color: Colors.grey),
                              ),
                          ],
                        ),
                      ),

                      // Chip Status (Kanan)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            color: _getStatusColor(status),
                            fontWeight: FontWeight.bold,
                            fontSize: 12
                          ),
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}