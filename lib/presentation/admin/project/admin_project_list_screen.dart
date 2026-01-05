import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'admin_add_project_screen.dart'; 
import 'admin_project_detail_screen.dart'; 

class AdminProjectListScreen extends StatefulWidget {
  const AdminProjectListScreen({super.key});

  @override
  State<AdminProjectListScreen> createState() => _AdminProjectListScreenState();
}

class _AdminProjectListScreenState extends State<AdminProjectListScreen> {
  final supabase = Supabase.instance.client;

  // Fungsi Hapus Proyek
  Future<void> _deleteProject(String id) async {
    try {
      await supabase.from('projects').delete().eq('id', id);
      setState(() {}); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Proyek berhasil dihapus")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Fetch Project + Progress Calculation
  Future<List<Map<String, dynamic>>> _fetchProjectsWithProgress() async {
    // 1. Ambil Proyek
    final projectResponse = await supabase.from('projects').select().order('created_at', ascending: false);
    final projects = List<Map<String, dynamic>>.from(projectResponse);

    // 2. Ambil Semua Task (Hanya kolom project_id dan status biar ringan)
    final taskResponse = await supabase.from('tasks').select('project_id, status');
    final tasks = List<Map<String, dynamic>>.from(taskResponse);

    // 3. Gabungkan Data (Hitung Progress per Project)
    for (var project in projects) {
      final projectId = project['id'].toString();
      final projectTasks = tasks.where((t) => t['project_id'] == projectId).toList();
      
      final totalTasks = projectTasks.length;
      final completedTasks = projectTasks.where((t) => t['status'] == 'Done').length;

      // Hitung Persentase
      double progress = 0;
      if (totalTasks > 0) {
        progress = (completedTasks / totalTasks) * 100;
      }

      // Simpan ke map project sementara (bukan di DB)
      project['progress_percent'] = progress.toInt();
      project['total_tasks'] = totalTasks;
      project['completed_tasks'] = completedTasks;
    }

    return projects;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Kelola Proyek"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        tooltip: 'Buat Proyek Baru',
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(builder: (context) => const AdminAddProjectScreen())
          );
          if (result == true) setState(() {}); 
        },
        child: const Icon(Icons.add),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchProjectsWithProgress(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text("Belum ada proyek aktif."));
          }

          final projects = snapshot.data!;

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: projects.length,
            itemBuilder: (context, index) {
              final project = projects[index];
              final progress = project['progress_percent'] as int;
              
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
                    setState(() {});
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Baris Atas
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
                            // Menu Edit & Delete
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (context) => AdminAddProjectScreen(project: project))
                                    );
                                    if (result == true) setState(() {}); 
                                  },
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                                  onPressed: () {
                                    showDialog(context: context, builder: (ctx) => AlertDialog(
                                      title: const Text("Hapus Proyek?"),
                                      content: const Text("Menghapus proyek akan menghapus semua tugas di dalamnya."),
                                      actions: [
                                        TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Batal")),
                                        TextButton(
                                          onPressed: (){ 
                                            Navigator.pop(ctx); 
                                            _deleteProject(project['id'].toString()); 
                                          }, 
                                          child: const Text("Hapus", style: TextStyle(color: Colors.red))
                                        ),
                                      ],
                                    ));
                                  },
                                )
                              ],
                            )
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        Text(deskripsi, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.grey)),
                        
                        const SizedBox(height: 16),
                        
                        // PROGRESS BAR
                        Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                        Text("Progress ($progress%)", style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.indigo)),
                                        Text("${project['completed_tasks']}/${project['total_tasks']} Tugas", style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ]
                                ),
                                const SizedBox(height: 6),
                                LinearProgressIndicator(
                                    value: progress / 100,
                                    backgroundColor: Colors.indigo.shade50,
                                    color: progress == 100 ? Colors.green : Colors.indigo,
                                    borderRadius: BorderRadius.circular(4),
                                    minHeight: 6,
                                ),
                            ],
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Baris Bawah: Info Tanggal & Status
                        Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 14, color: Colors.grey),
                            const SizedBox(width: 6),
                            Text("Deadline: $fmtDeadline", style: const TextStyle(color: Colors.grey, fontSize: 12)),
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
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
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