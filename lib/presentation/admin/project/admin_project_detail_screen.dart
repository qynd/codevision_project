import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'admin_add_task_screen.dart'; 

class AdminProjectDetailScreen extends StatefulWidget {
  final Map<String, dynamic> project;

  const AdminProjectDetailScreen({super.key, required this.project});

  @override
  State<AdminProjectDetailScreen> createState() => _AdminProjectDetailScreenState();
}

class _AdminProjectDetailScreenState extends State<AdminProjectDetailScreen> with SingleTickerProviderStateMixin {
  final supabase = Supabase.instance.client;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  // FUNGSI FETCH dengan filter opsional
  Future<List<Map<String, dynamic>>> _fetchTasks({bool onlyPendingApproval = false}) async {
    try {
      final projectId = widget.project['id'].toString();

      var query = supabase
          .from('tasks')
          .select('*, users!assigned_to(nama)') 
          .eq('project_id', projectId);

      if (onlyPendingApproval) {
        query = query.eq('status', 'Waiting Approval');
      } else {
        // Ambil semua selain waiting approval agar tidak duplikat di tab All Tasks (Opsional, atau tampilkan semua)
        // Disini kita tampilkan semua agar Admin bisa monitor progress global
      }

      final response = await query.order('created_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint("Error Fetch Tasks: $e");
      return [];
    }
  }

  // Fungsi Approve (Tandai Selesai)
  Future<void> _approveTask(String taskId) async {
    try {
      await supabase.from('tasks').update({
        'status': 'Done',
        'progress_percent': 100
      }).eq('id', taskId);
      
      setState(() {}); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas berhasil disetujui (Done).")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Fungsi Reject (Kembalikan ke Doing)
  Future<void> _rejectTask(String taskId) async {
    try {
      await supabase.from('tasks').update({
        'status': 'Doing', // Kembalikan ke Doing agar diperbaiki
        // progress jangan diedit, biarkan user yang sesuaikan
      }).eq('id', taskId);
      
      setState(() {}); 
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas ditolak. Status kembali ke 'Doing'.")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
        setState(() {}); 
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas dihapus")));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal hapus: $e")));
      }
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('d MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project['nama_proyek'] ?? 'Detail Proyek'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(icon: Icon(Icons.verified_user), text: "Perlu Approval"),
            Tab(icon: Icon(Icons.list), text: "Semua Tugas"),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context, 
            MaterialPageRoute(
              builder: (context) => AdminAddTaskScreen(projectId: widget.project['id'].toString())
            )
          );
          if (result == true) setState(() {});
        },
        label: const Text("Tugas Baru"),
        icon: const Icon(Icons.add_task),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // TAB 1: WAITNG APPROVAL
          _buildTaskList(onlyPendingApproval: true),
          
          // TAB 2: ALL TASKS
          _buildTaskList(onlyPendingApproval: false),
        ],
      ),
    );
  }

  Widget _buildTaskList({required bool onlyPendingApproval}) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchTasks(onlyPendingApproval: onlyPendingApproval),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
           return Center(child: Text("Terjadi kesalahan: ${snapshot.error}"));
        }

        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          if (onlyPendingApproval) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   Icon(Icons.thumb_up_alt_outlined, size: 60, color: Colors.indigo.shade100),
                   const SizedBox(height: 16),
                   const Text("Tidak ada tugas yang menunggu persetujuan.", style: TextStyle(color: Colors.grey)),
                ],
              ),
            );
          }
          return const Center(child: Text("Belum ada tugas di proyek ini."));
        }

        final tasks = snapshot.data!;
        
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          separatorBuilder: (_,__) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return _buildTaskCard(task, isApprovalTab: onlyPendingApproval);
          },
        );
      },
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, {required bool isApprovalTab}) {
    String assignedName = "Belum Assign";
    if (task['users'] != null) {
      assignedName = task['users']['nama'] ?? "Unknown";
    }

    final isDone = task['status'] == 'Done';
    final status = task['status'] ?? 'To Do';
    
    Color statusColor = Colors.grey;
    if (status == 'Done') statusColor = Colors.green;
    if (status == 'Doing') statusColor = Colors.blue;
    if (status == 'Waiting Approval') statusColor = Colors.orange;

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Judul & Status
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    task['judul'] ?? 'Tanpa Judul',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      color: isDone ? Colors.grey : Colors.black87,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor.withOpacity(0.5))
                  ),
                  child: Text(
                    status == 'Waiting Approval' ? 'Butuh Cek' : status,
                    style: TextStyle(fontSize: 10, color: statusColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Body: PIC & Deadline
            Row(
              children: [
                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(assignedName, style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                const Spacer(),
                const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  _formatDate(task['deadline']),
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: (task['progress_percent'] ?? 0) / 100,
              backgroundColor: Colors.grey[100],
              color: statusColor,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
            
            // Footer: Approval Actions atau Delete
            const SizedBox(height: 12),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (isApprovalTab) ...[
                  TextButton.icon(
                    onPressed: () => _rejectTask(task['id'].toString()), 
                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                    label: const Text("Tolak", style: TextStyle(color: Colors.red)),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: () => _approveTask(task['id'].toString()), 
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text("Setujui"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                  ),
                ] else ...[
                  // Di tab All Tasks, tampilkan tombol delete biasa
                  if (status == 'Waiting Approval')
                     TextButton(    
                        onPressed: () {
                           // Pindah ke tab 0 (Approval) -> ini manual, user suruh klik tab aja
                           _tabController.animateTo(0);
                        }, 
                        child: const Text("Perlu Approval", style: TextStyle(color: Colors.orange))
                     ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.grey),
                    tooltip: "Hapus Tugas",
                    onPressed: () => _deleteTask(task['id'].toString()),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }
}