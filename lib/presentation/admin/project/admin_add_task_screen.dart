import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminAddTaskScreen extends StatefulWidget {
  // PERBAIKAN 1: Ubah int ke String karena ID project adalah UUID
  final String projectId; 

  const AdminAddTaskScreen({super.key, required this.projectId});

  @override
  State<AdminAddTaskScreen> createState() => _AdminAddTaskScreenState();
}

class _AdminAddTaskScreenState extends State<AdminAddTaskScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _dueDateController = TextEditingController();
  
  String? _selectedEmployeeId;
  String _selectedPriority = 'Medium';
  bool _isLoading = false;

  // Mengambil daftar pegawai
  Future<List<Map<String, dynamic>>> _fetchEmployees() async {
    // Pastikan tabel users memiliki kolom 'role'. Jika tidak ada, hapus .eq('role', 'pegawai')
    final response = await supabase
        .from('users')
        .select('id, nama')
        // .eq('role', 'pegawai') // Aktifkan baris ini jika Anda punya kolom role
        ;
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // PERBAIKAN 2: Sesuaikan nama key dengan nama kolom di Database Supabase Anda
      await supabase.from('tasks').insert({
        'project_id': widget.projectId,  // UUID Project
        'assigned_to': _selectedEmployeeId, // Kolom: assigned_to (bukan user_id)
        'judul': _titleController.text,     // Kolom: judul
        'deskripsi': _descController.text,  // Kolom: deskripsi
        'deadline': _dueDateController.text, // Kolom: deadline (format YYYY-MM-DD aman)
        'status': 'To Do',                  // Default status
        'progress_percent': 0,              // Default progress
        
        // Catatan: Kolom 'priority' tidak dikirim karena tidak ada di tabel database Anda.
        // Jika ingin menyimpannya, Anda harus alter table add column priority text;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tugas berhasil diberikan!")));
        Navigator.pop(context, true); // Kembali ke layar sebelumnya & refresh
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Tugas Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Judul Tugas", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              
              // DROPDOWN PILIH PEGAWAI
              FutureBuilder<List<Map<String, dynamic>>>(
                future: _fetchEmployees(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                     return const LinearProgressIndicator();
                  }
                  if (snapshot.hasError) {
                    return Text("Error ambil pegawai: ${snapshot.error}");
                  }
                  
                  // Handle jika data kosong
                  final employees = snapshot.data ?? [];
                  
                  return DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: "Tugaskan Kepada", border: OutlineInputBorder()),
                    value: _selectedEmployeeId,
                    items: employees.map((user) {
                      return DropdownMenuItem(
                        value: user['id'].toString(), // Pastikan value ID string
                        child: Text(user['nama'] ?? 'Tanpa Nama'),
                      );
                    }).toList(),
                    onChanged: (val) => setState(() => _selectedEmployeeId = val),
                    validator: (val) => val == null ? 'Pilih pegawai' : null,
                  );
                },
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _descController,
                maxLines: 3,
                decoration: const InputDecoration(labelText: "Deskripsi Detail", border: OutlineInputBorder()),
              ),
              const SizedBox(height: 16),

              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: "Prioritas (Info Only)", border: OutlineInputBorder()),
                      value: _selectedPriority,
                      items: const ['Low', 'Medium', 'High'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                      onChanged: (val) => setState(() => _selectedPriority = val!),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _dueDateController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: "Deadline", border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                      onTap: () async {
                        DateTime? picked = await showDatePicker(
                          context: context, 
                          initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime(2030)
                        );
                        if (picked != null) {
                          // Format ISO String agar aman masuk ke database timestamp
                          _dueDateController.text = picked.toIso8601String(); 
                        }
                      },
                      validator: (val) => val!.isEmpty ? 'Isi deadline' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveTask,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text("BERIKAN TUGAS"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}