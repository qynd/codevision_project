import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _keteranganController = TextEditingController();
  final _jumlahController = TextEditingController();

  List<dynamic> _projects = [];
  String? _selectedProjectId;
  bool _isLoading = false;
  String _currentUserRole = 'Pegawai'; 

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Cek role user saat ini
      final userRes = await supabase.from('users').select('role').eq('id', user.id).single();
      final String currentRole = (userRes['role'] ?? 'Pegawai').toString().toLowerCase();

      // Ambil seluruh proyek terlebih dahulu
      final allProjectRes = await supabase.from('projects').select('id, nama_proyek, manager_id').order('created_at', ascending: false);
      
      List<dynamic> filteredProjects = [];
      
      if (currentRole == 'pegawai') {
        // Ambil daftar project_id dari tasks di mana pegawai ini di-assign
        final taskRes = await supabase.from('tasks').select('project_id').eq('assigned_to', user.id);
        final assignedProjectIds = (taskRes as List<dynamic>)
            .map((t) => t['project_id'].toString())
            .where((id) => id != 'null')
            .toSet();

        filteredProjects = (allProjectRes as List<dynamic>)
            .where((p) => assignedProjectIds.contains(p['id'].toString()))
            .toList();
      } else {
        // Role lain (Manajer/HRD/Direktur) melihat semua proyek
        filteredProjects = allProjectRes as List<dynamic>;
      }

      if (mounted) {
        setState(() {
          _projects = filteredProjects;
          _currentUserRole = currentRole;
        });
      }
    } catch (e) {
      debugPrint("Error fetching data: $e");
    }
  }

  Future<void> _submitExpense() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Parse nominal
      final jumlahStr = _jumlahController.text.replaceAll(RegExp(r'[^0-9]'), '');
      final double jumlah = double.parse(jumlahStr);

      // Logika khusus: Jika yang input Manajer, langsung Approved. Jika lainnya, Pending.
      String status = 'Pending';
      if (_currentUserRole == 'manajer') {
        status = 'Approved';
      }

      await supabase.from('operational_expenses').insert({
        'user_id': user.id,
        'project_id': _selectedProjectId,
        'jumlah_dana': jumlah,
        'keterangan': _keteranganController.text.trim(),
        'status': status,
        'tanggal_pengajuan': DateTime.now().toIso8601String().split('T')[0],
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Berhasil mengajukan dana operasional!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Ajukan Dana Operasional")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_currentUserRole == 'manajer')
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.green.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          "Anda login sebagai Manajer. Pengajuan ini akan otomatis disetujui (Approved).",
                          style: TextStyle(color: Colors.green.shade900, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),

              TextFormField(
                controller: _keteranganController,
                decoration: const InputDecoration(
                  labelText: "Keterangan/Keperluan",
                  hintText: "Contoh: Pembelian alat tulis kantor, biaya langganan server...",
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _jumlahController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: "Nominal Dana (Rp)",
                  prefixText: "Rp ",
                  border: OutlineInputBorder(),
                ),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              DropdownButtonFormField<String>(
                initialValue: _selectedProjectId,
                decoration: const InputDecoration(
                  labelText: "Terkait Proyek (Opsional)",
                  border: OutlineInputBorder(),
                  helperText: "Format: Kosongkan jika merupakan biaya operasional umum",
                ),
                items: [
                  const DropdownMenuItem(value: null, child: Text("- Tidak Terkait Proyek -")),
                  ..._projects.map((p) {
                    return DropdownMenuItem<String>(
                      value: p['id'].toString(),
                      child: Text(p['nama_proyek'].length > 30 ? p['nama_proyek'].substring(0,30)+'...' : p['nama_proyek']),
                    );
                  }),
                ],
                onChanged: (val) => setState(() => _selectedProjectId = val),
              ),
              const SizedBox(height: 32),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitExpense,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("KIRIM PENGAJUAN"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
