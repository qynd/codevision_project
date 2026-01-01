import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'admin_add_project_screen.dart'; // Pastikan nama file ini benar
import 'admin_project_detail_screen.dart'; // Pastikan nama file ini benar

class AdminProjectListScreen extends StatefulWidget {
  const AdminProjectListScreen({super.key});

  @override
  State<AdminProjectListScreen> createState() => _AdminProjectListScreenState();
}

class _AdminProjectListScreenState extends State<AdminProjectListScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi Hapus Proyek
  Future<void> _deleteProject(int id) async {
    try {
      await supabase.from('projects').delete().eq('id', id);
      
      // Refresh UI setelah hapus
      setState(() {}); 

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proyek berhasil dihapus")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Proyek"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      // --- LOGIKA REFRESH OTOMATIS SAAT TAMBAH DATA ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        tooltip: 'Buat Proyek Baru',
        onPressed: () async {
          // 1. Tunggu hasil dari halaman tambah
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const AdminAddProjectScreen())
          );
          
          // 2. Jika result == true (berhasil simpan), refresh layar
          if (result == true) {
            setState(() {}); 
          }
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder(
        // Query mengambil data terbaru setiap kali setState dipanggil
        future: supabase.from('projects').select().order('created_at', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || (snapshot.data as List).isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_open, size: 60, color: Colors.grey),
                  SizedBox(height: 10),
                  Text("Belum ada proyek aktif."),
                ],
              ),
            );
          }

          final List projects = snapshot.data as List;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              
              // Null Safety
              final String namaProyek = project['nama_proyek'] ?? 'Tanpa Judul';
              final String deskripsi = project['deskripsi'] ?? 'Tidak ada deskripsi';
              final String status = project['status'] ?? 'Active';

              // Format Tanggal
              String fmtDeadline = '-'; 
              if (project['due_date'] != null) {
                try {
                  final deadline = DateTime.parse(project['due_date']);
                  fmtDeadline = DateFormat('d MMM yyyy', 'id_ID').format(deadline);
                } catch (e) {
                  fmtDeadline = project['due_date'];
                }
              }

              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () async {
                    // Navigasi ke Detail
                    await Navigator.push(
                      context, 
                      MaterialPageRoute(builder: (context) => AdminProjectDetailScreen(project: project))
                    );
                    // Refresh list saat kembali (siapa tahu ada update di dalam detail)
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Baris Atas: Judul + Tombol Aksi
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                namaProyek, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // --- LOGIKA REFRESH OTOMATIS SAAT EDIT ---
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue),
                              tooltip: 'Edit Proyek',
                              onPressed: () async {
                                final result = await Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (context) => AdminAddProjectScreen(project: project))
                                );
                                if (result == true) setState(() {}); 
                              },
                            ),
                            // Tombol Hapus
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              tooltip: 'Hapus Proyek',
                              onPressed: () {
                                showDialog(context: context, builder: (ctx) => AlertDialog(
                                  title: const Text("Hapus Proyek?"),
                                  content: const Text("Menghapus proyek akan menghapus semua tugas di dalamnya."),
                                  actions: [
                                    TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
                                    TextButton(
                                      onPressed: (){ 
                                        Navigator.pop(ctx); 
                                        _deleteProject(project['id']); 
                                      }, 
                                      child: const Text("Hapus", style: TextStyle(color: Colors.red))
                                    ),
                                  ],
                                ));
                              },
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Text(deskripsi, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                        
                        const SizedBox(height: 16),
                        
                        // Baris Bawah: Info Tanggal & Status
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 16, color: Colors.indigo),
                            const SizedBox(width: 6),
                            Text("Deadline: $fmtDeadline", style: const TextStyle(color: Colors.indigo)),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: status == 'Completed' ? Colors.green.shade50 : Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8)
                              ),
                              child: Text(
                                status, 
                                style: TextStyle(
                                  color: status == 'Completed' ? Colors.green.shade800 : Colors.blue.shade800, 
                                  fontWeight: FontWeight.bold
                                )
                              ),
                            )
                          ],
                        )
                      ],
                    ),
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