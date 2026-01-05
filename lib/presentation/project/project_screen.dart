import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/user_model.dart'; // Import Model User
import '../../services/auth_service.dart'; // Import Auth Service
import 'project_detail_screen.dart';

class ProjectScreen extends StatefulWidget {
  const ProjectScreen({super.key});

  @override
  State<ProjectScreen> createState() => _ProjectScreenState();
}

class _ProjectScreenState extends State<ProjectScreen> {
  final supabase = Supabase.instance.client;
  UserModel? _currentUser; // Simpan data user yang login
  bool _isLoadingUser = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentUser();
  }

  // Ambil Data User Saat Ini
  Future<void> _fetchCurrentUser() async {
    final user = await AuthService().getCurrentUserData();
    if (mounted) {
      setState(() {
        _currentUser = user;
        _isLoadingUser = false;
      });
    }
  }

  // Future untuk mengambil list project
  Future<List<ProjectModel>> _fetchProjects() async {
    // Tunggu user loaded jika dipanggil manual (misal refresh)
    if (_currentUser == null) {
      // Coba fetch lagi jika null (edge case)
      await _fetchCurrentUser();
      if (_currentUser == null) return [];
    }

    if (_currentUser!.role == 'Admin') {
      // ADMIN: Lihat Semua Project
      final response = await supabase
          .from('projects')
          .select()
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((json) => ProjectModel.fromJson(json)).toList();
    } else {
      // PEGAWAI: Hanya Project yang mereka punya TUGAS di dalamnya
      // 1. Ambil semua tugas yang assigned_to user ini
      final tasksResponse = await supabase
          .from('tasks')
          .select('project_id')
          .eq('assigned_to', _currentUser!.id);
      
      final tasksData = tasksResponse as List<dynamic>;
      
      // 2. Kumpulkan ID Project yang unik
      final projectIds = tasksData.map((t) => t['project_id']).toSet().toList();

      if (projectIds.isEmpty) return [];

      // 3. Ambil Detail Project berdasarkan ID tersebut
      final response = await supabase
          .from('projects')
          .select()
          .filter('id', 'in', projectIds) // Filter Project ID
          .order('created_at', ascending: false);

      final data = response as List<dynamic>;
      return data.map((json) => ProjectModel.fromJson(json)).toList();
    }
  }

  // Helper untuk warna status
  Color _getStatusColor(String status) {
    switch (status) {
      case 'In Progress':
        return Colors.blue;
      case 'Completed':
        return Colors.green;
      case 'On Hold':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Proyek'),
        actions: [
          IconButton(
            onPressed: () {
              setState(() {});
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _isLoadingUser 
          ? const Center(child: CircularProgressIndicator()) 
          : FutureBuilder<List<ProjectModel>>(
        future: _fetchProjects(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(
              child: Text(
                _currentUser?.role == 'Admin' 
                  ? "Belum ada proyek saat ini." // Pesan untuk Admin
                  : "Anda belum memiliki tugas di proyek manapun." // Pesan untuk Pegawai
              ),
            );
          }

          final projects = snapshot.data!;

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: projects.length,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final project = projects[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ProjectDetailScreen(project: project),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Baris Atas: Nama Proyek & Chip Status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                project.namaProyek,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _getStatusColor(
                                  project.status,
                                ).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _getStatusColor(project.status),
                                ),
                              ),
                              child: Text(
                                project.status,
                                style: TextStyle(
                                  color: _getStatusColor(project.status),
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Deskripsi
                        Text(
                          project.deskripsi,
                          style: TextStyle(color: Colors.grey[600]),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const Divider(height: 24),

                        // Baris Bawah: Tanggal & Icon
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "Deadline: ${project.dueDate}",
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.grey,
                              ),
                            ),
                            const Spacer(),
                            const Text(
                              "Lihat Detail",
                              style: TextStyle(
                                color: Colors.indigo,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              size: 12,
                              color: Colors.indigo,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      // Tombol Tambah Proyek (Hanya Admin yang bisa lihat)
      floatingActionButton: _currentUser?.role == 'Admin' 
          ? FloatingActionButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Fitur Tambah Proyek akan dibuat nanti"),
                  ),
                );
              },
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null, // Sembunyikan jika bukan Admin
    );
  }
}
