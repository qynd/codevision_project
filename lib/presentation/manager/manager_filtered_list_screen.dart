import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../admin/project/admin_project_detail_screen.dart';

class ManagerFilteredListScreen extends StatefulWidget {
  final String filterType;

  const ManagerFilteredListScreen({super.key, required this.filterType});

  @override
  State<ManagerFilteredListScreen> createState() => _ManagerFilteredListScreenState();
}

class _ManagerFilteredListScreenState extends State<ManagerFilteredListScreen> {
  final supabase = Supabase.instance.client;
  bool isLoading = true;
  List<dynamic> items = [];

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      if (widget.filterType == "Proyek Aktif" || widget.filterType == "Proyek Selesai") {
        var query = supabase.from('projects').select();
        if (widget.filterType == "Proyek Aktif") {
          query = query.neq('status', 'Completed');
        } else {
          query = query.eq('status', 'Completed');
        }
        final data = await query;
        items = (data as List<dynamic>).map((json) => ProjectModel.fromJson(json)).toList();
      } 
      else if (widget.filterType == "Tugas Menunggu" || widget.filterType == "Total Tugas") {
        // Fetch tasks and join with users to get assignee name
        var query = supabase.from('tasks').select('*, users(nama)');
        if (widget.filterType == "Tugas Menunggu") {
          query = query.eq('status', 'Waiting Approval');
        }
        final data = await query;
        items = (data as List<dynamic>).map((json) => TaskModel.fromJson(json)).toList();
      }

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching filtered data: $e");
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filterType),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : items.isEmpty
              ? Center(child: Text("Tidak ada data untuk ${widget.filterType}"))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];

                    if (item is ProjectModel) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.indigo,
                            child: Icon(Icons.rocket_launch, color: Colors.white),
                          ),
                          title: Text(item.namaProyek, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text("Status: ${item.status}\nDeadline: ${item.dueDate}"),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => AdminProjectDetailScreen(
                                  project: {
                                    'id': item.id,
                                    'nama_proyek': item.namaProyek,
                                    'deskripsi': item.deskripsi,
                                    'status': item.status,
                                    'due_date': item.dueDate,
                                  },
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    } else if (item is TaskModel) {
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Colors.orange,
                            child: Icon(Icons.assignment, color: Colors.white),
                          ),
                          title: Text(item.judul, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("PIC: ${item.assignedToName ?? 'Belum ada'}"),
                              Text("Status: ${item.status} (${item.progress}%)"),
                            ],
                          ),
                        ),
                      );
                    }
                    return const SizedBox();
                  },
                ),
    );
  }
}
