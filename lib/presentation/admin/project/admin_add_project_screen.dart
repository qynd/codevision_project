import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAddProjectScreen extends StatefulWidget {
  final Map<String, dynamic>? project; // Data proyek (opsional, untuk edit)

  const AdminAddProjectScreen({super.key, this.project});

  @override
  State<AdminAddProjectScreen> createState() => _AdminAddProjectScreenState();
}

class _AdminAddProjectScreenState extends State<AdminAddProjectScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  late TextEditingController _titleController;
  late TextEditingController _descController;
  late TextEditingController _dateController;
  
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Jika edit, isi field dengan data lama. Jika baru, kosongkan.
    _titleController = TextEditingController(text: widget.project?['nama_proyek'] ?? '');
    _descController = TextEditingController(text: widget.project?['deskripsi'] ?? '');
    
    // Handle tanggal untuk edit
    String initialDate = '';
    if (widget.project != null && widget.project!['due_date'] != null) {
       // Format dari yyyy-mm-dd (database) ke textfield
       initialDate = widget.project!['due_date']; 
    }
    _dateController = TextEditingController(text: initialDate);
  }

  Future<void> _saveProject() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final now = DateTime.now();
      
      if (widget.project == null) {
        // --- MODE TAMBAH (INSERT) ---
        await supabase.from('projects').insert({
          'nama_proyek': _titleController.text,
          'deskripsi': _descController.text,
          'due_date': _dateController.text,
          'start_date': now.toIso8601String(),
          'status': 'In Progress',
          'created_at': now.toIso8601String(),
        });
      } else {
        // --- MODE EDIT (UPDATE) ---
        await supabase.from('projects').update({
          'nama_proyek': _titleController.text,
          'deskripsi': _descController.text,
          'due_date': _dateController.text,
          // Status dan Start Date biasanya tidak diubah di sini
        }).eq('id', widget.project!['id']); // Update berdasarkan ID
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(widget.project == null ? "Proyek dibuat!" : "Proyek diperbarui!"))
        );
        Navigator.pop(context, true); 
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.project != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEdit ? "Edit Proyek" : "Buat Proyek Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: "Nama Proyek", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descController,
                decoration: const InputDecoration(labelText: "Deskripsi Singkat", border: OutlineInputBorder()),
                maxLines: 3,
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Tenggat Waktu (Deadline)", 
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month)
                ),
                onTap: () async {
                  DateTime? picked = await showDatePicker(
                    context: context, 
                    initialDate: DateTime.now().add(const Duration(days: 7)),
                    firstDate: DateTime.now(), 
                    lastDate: DateTime(2030)
                  );
                  if (picked != null) {
                    _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveProject,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isEdit ? "UPDATE PROYEK" : "SIMPAN PROYEK"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}