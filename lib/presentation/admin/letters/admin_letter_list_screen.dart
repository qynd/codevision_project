import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'admin_incoming_letter_screen.dart'; // Import Surat Masuk
import 'admin_outgoing_letter_screen.dart'; // Import Surat Keluar

class AdminLetterListScreen extends StatefulWidget {
  const AdminLetterListScreen({super.key});

  @override
  State<AdminLetterListScreen> createState() => _AdminLetterListScreenState();
}

class _AdminLetterListScreenState extends State<AdminLetterListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manajemen Surat"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(text: "Izin Pegawai"),
            Tab(text: "Surat Masuk"),
            Tab(text: "Surat Keluar"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const AdminPermissionApprovalView(), // View khusus validasi
          const AdminIncomingLetterScreen(),   // View Surat Masuk
          const AdminOutgoingLetterScreen(),   // View Surat Keluar
        ],
      ),
    );
  }
}

// --- WIDGET KHUSUS VALIDASI IZIN (Memindahkan Logic Lama ke sini) ---
class AdminPermissionApprovalView extends StatefulWidget {
  const AdminPermissionApprovalView({super.key});

  @override
  State<AdminPermissionApprovalView> createState() => _AdminPermissionApprovalViewState();
}

class _AdminPermissionApprovalViewState extends State<AdminPermissionApprovalView> {
  final supabase = Supabase.instance.client;
  String _filterStatus = 'All';
  bool _isLoading = false;

  Future<List<Map<String, dynamic>>> _fetchLetters() async {
    var query = supabase
        .from('letters') // Tabel Izin/Cuti
        .select('*, users(nama, jabatan, nip)'); 

    if (_filterStatus != 'All') {
      query = query.eq('status', _filterStatus);
    }

    final response = await query.order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _processApproval(Map<String, dynamic> letter, String newStatus) async {
    setState(() => _isLoading = true); 
    
    try {
      // 1. Update status surat jadi Approved/Rejected
      await supabase.from('letters').update({'status': newStatus}).eq('id', letter['id']);

      // 2. JIKA DISETUJUI, BUATKAN DATA ABSENSI OTOMATIS
      if (newStatus == 'Approved') {
        final startDate = DateTime.parse(letter['tanggal_mulai']);
        final endDate = DateTime.parse(letter['tanggal_selesai']);
        final int days = endDate.difference(startDate).inDays + 1;

        for (int i = 0; i < days; i++) {
          final currentDate = startDate.add(Duration(days: i));
          final dateString = DateFormat('yyyy-MM-dd').format(currentDate);

          final existing = await supabase
              .from('attendances')
              .select()
              .eq('user_id', letter['user_id'])
              .eq('tanggal', dateString)
              .maybeSingle();

          if (existing == null) {
            await supabase.from('attendances').insert({
              'user_id': letter['user_id'],
              'tanggal': dateString,
              'status': letter['jenis_surat'], 
              'check_in_time': DateTime.now().toIso8601String(), 
              'check_out_time': DateTime.now().toIso8601String(),
              'keterangan': "Pengajuan Surat Disetujui Admin",
              'durasi': 1
            });
          } else {
            await supabase.from('attendances').update({
              'status': letter['jenis_surat'],
              'keterangan': "Diubah oleh Admin (Surat Disetujui)"
            }).eq('id', existing['id']);
          }
        }
      }

      setState(() {}); 
      if (mounted) Navigator.pop(context); 

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showDetailDialog(Map<String, dynamic> letter) {
    final user = letter['users'] ?? {};
    final String status = letter['status'] ?? 'Pending';
    
    String tanggal = '-';
    try {
      final start = DateTime.parse(letter['tanggal_mulai']);
      final end = DateTime.parse(letter['tanggal_selesai']);
      tanggal = "${DateFormat('dd MMM').format(start)} - ${DateFormat('dd MMM yyyy').format(end)}";
    } catch (e) {
      tanggal = letter['tanggal_mulai'] ?? '-';
    }

    showDialog(
      context: context,
      barrierDismissible: !_isLoading, 
      builder: (context) => AlertDialog(
        title: Text("Detail ${letter['jenis_surat']}"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _rowDetail("Nama", user['nama'] ?? '-'),
              _rowDetail("Jabatan", user['jabatan'] ?? '-'),
              _rowDetail("Tanggal", tanggal),
              _rowDetail("Keterangan", letter['keterangan'] ?? '-'),
              const SizedBox(height: 10),
              const Text("Status Saat Ini:", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text(status, style: TextStyle(fontWeight: FontWeight.bold, color: _getStatusColor(status))),
              
              if (_isLoading) const Center(child: CircularProgressIndicator())
            ],
          ),
        ),
        actions: [
          if (!_isLoading) ...[
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Tutup")),
            if (status == 'Pending') ...[
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                onPressed: () => _processApproval(letter, 'Rejected'),
                child: const Text("Tolak"),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () => _processApproval(letter, 'Approved'),
                child: const Text("Setujui"),
              ),
            ]
          ]
        ],
      ),
    );
  }

  Widget _rowDetail(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: ['All', 'Pending', 'Approved', 'Rejected'].map((status) {
              final isSelected = _filterStatus == status;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: FilterChip(
                  label: Text(status == 'All' ? 'Semua' : status),
                  selected: isSelected,
                  selectedColor: Colors.indigo.shade100,
                  checkmarkColor: Colors.indigo,
                  onSelected: (val) => setState(() => _filterStatus = status),
                ),
              );
            }).toList(),
          ),
        ),
        Expanded(
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _fetchLetters(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
              if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Tidak ada pengajuan izin."));

              final letters = snapshot.data!;
              return ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                itemCount: letters.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = letters[index];
                  final user = item['users'] ?? {};
                  final status = item['status'] ?? 'Pending';
                  
                  return Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: status == 'Pending' ? const BorderSide(color: Colors.orange, width: 1.5) : BorderSide.none
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade50,
                        child: Icon(item['jenis_surat'] == 'Sakit' ? Icons.local_hospital : Icons.description, color: Colors.indigo),
                      ),
                      title: Text(user['nama'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("${item['jenis_surat']} • ${status}"),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                      onTap: () => _showDetailDialog(item),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}