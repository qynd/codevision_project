import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/login_screen.dart'; // Mundur 2 langkah ke folder auth

class AddEmployeeScreen extends StatefulWidget {
  const AddEmployeeScreen({super.key});

  @override
  State<AddEmployeeScreen> createState() => _AddEmployeeScreenState();
}

class _AddEmployeeScreenState extends State<AddEmployeeScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();
  
  // 1. Tambahkan Controller untuk NIP
  final _nipController = TextEditingController(); 
  final _namaController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _jabatanController = TextEditingController();
  
  String _selectedRole = 'pegawai'; 
  bool _isLoading = false;

  Future<void> _createAccount() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      // Create User (Akan otomatis logout Admin)
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null) {
        // 2. Masukkan NIP ke dalam data yang dikirim ke database
        await supabase.from('users').insert({
          'id': res.user!.id,
          'nip': _nipController.text.trim(), // <--- PENTING: Kirim NIP di sini
          'nama': _namaController.text.trim(),
          'email': _emailController.text.trim(),
          'jabatan': _jabatanController.text.trim(),
          'role': _selectedRole,
          'created_at': DateTime.now().toIso8601String(),
        });

        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              title: const Text("Pegawai Berhasil Ditambahkan"),
              content: const Text(
                "Akun pegawai baru telah dibuat.\n\n"
                "Anda harus login ulang sebagai Admin karena sesi telah berubah."
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (context) => const LoginScreen()), 
                      (route) => false
                    );
                  }, 
                  child: const Text("OK, Login Ulang")
                )
              ],
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e"), backgroundColor: Colors.red));
      }
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Tambah Pegawai Baru")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 3. Tambahkan Form Input NIP di UI
              TextFormField(
                controller: _nipController,
                decoration: const InputDecoration(
                  labelText: "NIP (Nomor Induk Pegawai)", 
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge)
                ),
                validator: (val) => val!.isEmpty ? 'NIP Wajib diisi' : null,
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: "Email Login", border: OutlineInputBorder()),
                validator: (val) => !val!.contains('@') ? 'Email tidak valid' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "Password Awal", border: OutlineInputBorder()),
                validator: (val) => val!.length < 6 ? 'Min 6 karakter' : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _jabatanController,
                decoration: const InputDecoration(labelText: "Jabatan (Misal: Staf IT)", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: "Hak Akses (Role)", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'pegawai', child: Text("Pegawai Biasa")),
                  DropdownMenuItem(value: 'admin', child: Text("Admin (Full Akses)")),
                ],
                onChanged: (val) => setState(() => _selectedRole = val!),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _createAccount,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("SIMPAN PEGAWAI"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}