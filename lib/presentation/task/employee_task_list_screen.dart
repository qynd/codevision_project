import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EmployeeTaskListScreen extends StatefulWidget {
  const EmployeeTaskListScreen({super.key});

  @override
  State<EmployeeTaskListScreen> createState() => _EmployeeTaskListScreenState();
}

class _EmployeeTaskListScreenState extends State<EmployeeTaskListScreen> {
  final supabase = Supabase.instance.client;

  Future<List<Map<String, dynamic>>> _fetchMyTasks() async {
    final user = supabase.auth.currentUser;
    if (user == null) return [];

    final response = await supabase
        .from('tasks')
        .select('*, projects(nama_proyek)')
        .eq('assigned_to', user.id)
        .neq('status', 'Done') // Tampilkan yang belum selesai saja (atau urutkan status)
        .order('deadline', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  void _showUpdateProgressDialog(Map<String, dynamic> task) {
    String selectedStatus = task['status'];
    double sliderValue = (task['progress_percent'] as int).toDouble();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: Text("Update: ${task['judul']}"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  items: ['To Do', 'Doing', 'Waiting Approval', 'Done'].map((e) {
                    bool enabled = true;
                    if (e == 'Done') enabled = false; // Pegawai tak bisa set Done langsung
                    
                    return DropdownMenuItem(
                      value: e, 
                      enabled: enabled,
                      child: Text(e == 'Done' ? 'Done (Verified by Admin)' : e, style: TextStyle(color: enabled ? Colors.black : Colors.grey)),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setDialogState(() => selectedStatus = val!);
                  },
                ),
                const SizedBox(height: 20),
                Text("Progress: ${sliderValue.round()}%"),
                Slider(
                  value: sliderValue,
                  min: 0, max: 100, divisions: 10,
                  label: sliderValue.round().toString(),
                  onChanged: (val) => setDialogState(() => sliderValue = val),
                )
              ],
            ),
            actions: [
              TextButton(onPressed: ()=>Navigator.pop(context), child: const Text("Batal")),
              ElevatedButton(
                onPressed: () async {
                  await supabase.from('tasks').update({
                    'status': selectedStatus,
                    'progress_percent': sliderValue.toInt()
                  }).eq('id', task['id']);
                  
                  if (mounted) {
                    Navigator.pop(context);
                    setState(() {}); 
                  }
                },
                child: const Text("Simpan"),
              )
            ],
          );
        });
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tugas Saya"), backgroundColor: Colors.indigo, foregroundColor: Colors.white),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchMyTasks(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Hore! Tidak ada tugas pending."));

          final tasks = snapshot.data!;
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              final projectName = task['projects'] != null ? task['projects']['nama_proyek'] : '-';
              final deadline = task['deadline'] != null ? DateFormat('d MMM').format(DateTime.parse(task['deadline'])) : '-';
              
              return Card(
                elevation: 3,
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.indigo.shade100,
                    child: Text("${task['progress_percent']}%", style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(task['judul'], style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Proyek: $projectName", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      Text("Status: ${task['status']}", style: const TextStyle(fontSize: 12, color: Colors.indigo)),
                    ],
                  ),
                  trailing: Text(deadline, style: const TextStyle(color: Colors.red)),
                  onTap: () => _showUpdateProgressDialog(task),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
