import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'admin_add_task_screen.dart'; // Pastikan nama file ini benar

class AdminProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const AdminProjectDetailScreen({super.key, required this.project});

  @override
  State<AdminProjectDetailScreen> createState() => _AdminProjectDetailScreenState();
}

class _AdminProjectDetailScreenState extends State<AdminProjectDetailScreen> {
  final supabase = Supabase.instance.client;

  // FUNGSI FETCH
  Future<List<Map<String, dynamic>>> _fetchTasks() async {
    try {
      final projectId = widget.project['id'].toString();

      final response = await supabase
          .from('tasks')
          .select('*, users!assigned_to(nama)') 
          .eq('project_id', projectId)
          .order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error Fetch Tasks: $e");
      return [];
    }
  }

  // Fungsi Hapus Task
  Future<void> _deleteTask(String taskId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Tugas?"),
        content: const Text("Tugas ini akan dihapus permanen."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(
            onPressed: () => Navigator.pop(context, true), 
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text("Hapus"),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      try {
        await supabase.from('tasks').delete().eq('id', taskId);
        
        // Refresh UI setelah hapus
        setState(() {}); 

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas dihapus")));
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal hapus: $e")));
        }
      }
    }
  }

  // Fungsi Update Checkbox (Opsional jika ingin langsung ganti status di list)
  Future<void> _toggleTaskStatus(String taskId, bool isDone) async {
    try {
        await supabase.from('tasks').update({
          'status': isDone ? 'Done' : 'In Progress',
          'progress_percent': isDone ? 100 : 50 // Logika sederhana
        }).eq('id', taskId);
        setState(() {}); // Refresh UI
    } catch (e) {
       // Handle error
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.project['nama_proyek'] ?? 'Detail Proyek')),
      // --- LOGIKA REFRESH OTOMATIS SAAT TAMBAH TUGAS ---
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => AdminAddTaskScreen(projectId: widget.project['id'].toString())
            )
          );

          // Jika result == true (berhasil simpan), refresh list
          if (result == true) {
            setState(() {});
          }
        },
        label: const Text("Tambah Tugas"),
        icon: const Icon(Icons.add_task),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // HEADER PROYEK
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.indigo.shade50,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Deskripsi:", style: TextStyle(fontWeight: FontWeight.bold)),
                Text(widget.project['deskripsi'] ?? '-'),
                const SizedBox(height: 10),
                Text(
                  "Deadline Proyek: ${widget.project['due_date'] ?? widget.project['deadline'] ?? '-'}",
                  style: const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          
          const Divider(height: 1),
          
          // LIST TUGAS
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchTasks(), // Dipanggil ulang saat setState
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                   return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
                }

                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text("Belum ada tugas di proyek ini."));
                }

                final tasks = snapshot.data!;
                
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: tasks.length,
                  separatorBuilder: (_,__) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final task = tasks[index];

                    String assignedName = "Belum Assign";
                    if (task['users'] != null) {
                      assignedName = task['users']['nama'] ?? "Unknown";
                    }

                    final isDone = task['status'] == 'Done';

                    return Card(
                      elevation: 2,
                      child: ListTile(
                        leading: InkWell(
                          onTap: () => _toggleTaskStatus(task['id'].toString(), !isDone),
                          child: CircleAvatar(
                            backgroundColor: isDone ? Colors.green.shade100 : Colors.blue.shade100,
                            child: Icon(
                              isDone ? Icons.check : Icons.assignment, 
                              color: isDone ? Colors.green : Colors.blue
                            ),
                          ),
                        ),
                        title: Text(
                          task['judul'] ?? 'Tanpa Judul', 
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            decoration: isDone ? TextDecoration.lineThrough : null,
                            color: isDone ? Colors.grey : Colors.black,
                          )
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text("PIC: $assignedName", style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text("Status: ${task['status']} (${task['progress_percent']}%)"),
                          ],
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                           icon: const Icon(Icons.delete_outline, color: Colors.grey),
                           onPressed: () => _deleteTask(task['id'].toString()),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}