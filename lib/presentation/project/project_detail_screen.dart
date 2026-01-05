import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/user_model.dart';
import '../../services/auth_service.dart'; // Import Auth Service

class ProjectDetailScreen extends StatefulWidget {
  final ProjectModel project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> {
  final supabase = Supabase.instance.client;
  
  // List untuk menampung data Pegawai yang bisa dipilih
  List<UserModel> _availableUsers = [];
  UserModel? _currentUser;
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUserAndUsers();
  }

  // --- BAGIAN 1: FUNGSI LOGIKA ---

  // A. Init Data (User Login & List Pegawai)
  Future<void> _fetchCurrentUserAndUsers() async {
    // 1. Ambil User Login
    final user = await AuthService().getCurrentUserData();
    
    // 2. Ambil Daftar Pegawai (Hanya jika perlu dropdown, tapi kita ambil saja)
    try {
      final response = await supabase.from('users').select();
      final data = response as List<dynamic>;
      final users = data.map((json) => UserModel.fromJson(json)).toList();

      if (mounted) {
        setState(() {
          _currentUser = user;
          _availableUsers = users;
          _isLoadingUser = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetch users: $e");
    }
  }

  // B. Ambil Tugas
  Future<List<TaskModel>> _fetchTasks() async {
    if (_currentUser == null) return [];

    var query = supabase
        .from('tasks')
        .select()
        .eq('project_id', widget.project.id);
    
    // FILTER: Jika Pegawai, hanya ambil tugas miliknya
    // Kecuali jika user Admin, ambil semua
    if (_currentUser!.role != 'Admin') {
      query = query.eq('assigned_to', _currentUser!.id);
    }
    
    final response = await query.order('created_at', ascending: true);

    final data = response as List<dynamic>;
    return data.map((json) => TaskModel.fromJson(json)).toList();
  }

  // Helper: Cari Nama User berdasarkan ID
  String _getUserName(String? userId) {
    if (userId == null) return "Belum Ada";
    try {
      final user = _availableUsers.firstWhere((u) => u.id == userId);
      return user.nama;
    } catch (e) {
      return "Unknown";
    }
  }

  // C. Tambah Tugas dengan Pilihan User (CREATE) - ONLY ADMIN
  void _showAddTaskSheet() {
    // Double check logic (opsional karena FAB juga disembunyikan)
    if (_currentUser?.role != 'Admin') return; 

    final titleController = TextEditingController();
    final descController = TextEditingController();
    String? selectedUserId; 
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              top: 20, left: 20, right: 20
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Tambah Tugas Baru", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: "Judul Tugas", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                
                TextField(
                  controller: descController,
                  decoration: const InputDecoration(labelText: "Deskripsi Singkat", border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),

                // --- DROPDOWN PILIH PEGAWAI ---
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: "Tugaskan Kepada (PIC)",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person)
                  ),
                  value: selectedUserId,
                  items: _availableUsers.map((user) {
                    return DropdownMenuItem(
                      value: user.id,
                      child: Text(user.nama), 
                    );
                  }).toList(),
                  onChanged: (val) {
                    setSheetState(() => selectedUserId = val);
                  },
                ),
                // -----------------------------

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    onPressed: isSubmitting ? null : () async {
                      if (titleController.text.isEmpty) return;
                      setSheetState(() => isSubmitting = true);

                      try {
                        await supabase.from('tasks').insert({
                          'project_id': widget.project.id,
                          'judul': titleController.text,
                          'deskripsi': descController.text,
                          'status': 'To Do',
                          'progress_percent': 0,
                          'assigned_to': selectedUserId, 
                        });

                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {}); 
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas berhasil ditambahkan")));
                        }
                      } catch (e) {
                         if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                      }
                    },
                    child: isSubmitting 
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white)) 
                      : const Text("SIMPAN TUGAS"),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          );
        }
      ),
    );
  }

  // D. Update Status
  void _showUpdateTaskDialog(TaskModel task) {
    String selectedStatus = task.status;
    double sliderValue = task.progress.toDouble();
    bool isAdmin = _currentUser?.role == 'Admin';

    // Tentukan Opsi Status
    // Step 1: Default Statuses
    List<String> statusOptions = ['To Do', 'Doing'];
    
    // Step 2: Add 'Waiting Approval' always available
    statusOptions.add('Waiting Approval');

    // Step 3: Add 'Done' ONLY if Admin
    if (isAdmin) {
      statusOptions.add('Done'); 
    }

    // Pastikan status saat ini ada di opsi (jika sudah Done, tetap tampilkan agar tidak error)
    if (!statusOptions.contains(selectedStatus)) {
      statusOptions.add(selectedStatus);
    }
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text("Update: ${task.judul}", style: const TextStyle(fontSize: 18))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("PIC: ${_getUserName(task.assignedTo)}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                  const Divider(),
                  const Text("Status Pengerjaan:"),
                  DropdownButton<String>(
                    value: selectedStatus,
                    isExpanded: true,
                    items: statusOptions.map((String val) {
                      return DropdownMenuItem(value: val, child: Text(val == 'Waiting Approval' ? 'Waiting Approval (Menunggu Validasi)' : val));
                    }).toList(),
                    onChanged: (newVal) {
                      setDialogState(() {
                         selectedStatus = newVal!;
                         if(selectedStatus == 'Done') sliderValue = 100;
                         if(selectedStatus == 'To Do') sliderValue = 0;
                         // Jika pegawai set waiting approval, mungkin set progress 90% atau 100%? Biarkan manual.
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Text("Progress: ${sliderValue.round()}%"),
                  Slider(
                    value: sliderValue,
                    min: 0,
                    max: 100,
                    divisions: 10,
                    label: sliderValue.round().toString(),
                    onChanged: (val) {
                      setDialogState(() => sliderValue = val);
                    },
                  ),
                  // Note: Bisa ditambahkan validasi Employee tidak bisa geser 100% jika status bukan Done, tapi kita percayakan pada Status.
                ],
              ),
              actions: [
                // --- TOMBOL HAPUS (HANYA ADMIN) ---
                if (isAdmin)
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      // Konfirmasi Hapus
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text("Hapus Tugas?"),
                          content: const Text("Tugas ini akan dihapus permanen."),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Batal")),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Hapus", style: TextStyle(color: Colors.red))),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        try {
                          await supabase.from('tasks').delete().eq('id', task.id);
                          
                          if (mounted) {
                            Navigator.pop(context); // Tutup Dialog Utama
                            setState(() {}); // Refresh List
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas dihapus")));
                          }
                        } catch (e) {
                          print(e);
                        }
                      }
                    },
                    child: const Text("Hapus"),
                  ),
                // ---------------------------

                const SizedBox(width: 20), 

                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Batal"),
                ),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await supabase.from('tasks').update({
                        'status': selectedStatus,
                        'progress_percent': sliderValue.toInt(),
                      }).eq('id', task.id);

                      if (mounted) {
                        Navigator.pop(context); // Tutup dialog
                        setState(() {}); // Refresh list utama
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Status diperbarui!")));
                      }
                    } catch (e) {
                      print(e);
                    }
                  },
                  child: const Text("Simpan"),
                )
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status) {
      case 'Done': color = Colors.green; break;
      case 'Doing': color = Colors.blue; break;
      case 'Waiting Approval': color = Colors.orange; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
      child: Text(
        status == 'Waiting Approval' ? 'Menunggu Validasi' : status, 
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold),
        textAlign: TextAlign.center,
      ),
    );
  }

  // --- BAGIAN 2: UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Proyek')),
      body: _isLoadingUser 
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          // Info Proyek
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            width: double.infinity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.project.namaProyek, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const SizedBox(height: 8),
                Text(widget.project.deskripsi),
                const SizedBox(height: 10),
                Text("Deadline: ${widget.project.dueDate}", style: const TextStyle(color: Colors.red)),
              ],
            ),
          ),
          const Divider(height: 1),

          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Daftar Tugas Tim", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(onPressed: (){ setState(() {}); }, icon: const Icon(Icons.refresh))
              ],
            ),
          ),
          
          Expanded(
            child: FutureBuilder<List<TaskModel>>(
              future: _fetchTasks(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada tugas."));

                final tasks = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: tasks.length,
                  itemBuilder: (context, index) {
                    final task = tasks[index];
                    final assigneeName = _getUserName(task.assignedTo); // Ambil nama pegawai

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        // Menampilkan Inisial Nama Pegawai dalam Lingkaran
                        leading: CircleAvatar(
                          backgroundColor: task.assignedTo != null ? Colors.indigo : Colors.grey.shade300,
                          child: Text(
                            assigneeName.isNotEmpty ? assigneeName[0].toUpperCase() : "?",
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                        title: Text(task.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            // Tampilkan Nama Lengkap Pegawai
                            Row(
                              children: [
                                Icon(Icons.person, size: 14, color: Colors.grey[600]),
                                const SizedBox(width: 4),
                                Text(
                                  assigneeName, 
                                  style: TextStyle(color: Colors.grey[800], fontSize: 12, fontWeight: FontWeight.bold)
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            LinearProgressIndicator(
                              value: task.progress / 100,
                              backgroundColor: Colors.grey[200],
                              color: task.progress == 100 ? Colors.green : Colors.blue,
                            ),
                          ],
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildStatusChip(task.status),
                            const SizedBox(height: 4),
                            Text("${task.progress}%", style: const TextStyle(fontSize: 10)),
                          ],
                        ),
                        // Semua bisa tap untuk update status (hak akses diatur di dalam dialog)
                        onTap: () => _showUpdateTaskDialog(task),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      // FAB HANYA UNTUK ADMIN
      floatingActionButton: _currentUser?.role == 'Admin' 
        ? FloatingActionButton.extended(
            onPressed: _showAddTaskSheet,
            label: const Text("Tugas Baru"),
            icon: const Icon(Icons.add_task),
            backgroundColor: Colors.indigo,
          )
        : null, 
    );
  }
}