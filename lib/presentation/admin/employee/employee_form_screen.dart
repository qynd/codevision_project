import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/login_screen.dart'; // Pastikan path ini benar sesuai struktur foldermu

class EmployeeFormScreen extends StatefulWidget {
  final Map<String, dynamic>? employeeData;

  const EmployeeFormScreen({super.key, this.employeeData});

  @override
  State<EmployeeFormScreen> createState() => _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends State<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  // Controllers
  final _namaController = TextEditingController();
  final _nipController = TextEditingController();
  final _emailController = TextEditingController();
  final _jabatanController = TextEditingController();
  final _noHpController = TextEditingController();
  final _passwordController = TextEditingController(); // Khusus tambah baru

  @override
  void initState() {
    super.initState();
    if (widget.employeeData != null) {
      // MODE EDIT: Isi form dengan data lama
      final data = widget.employeeData!;
      _namaController.text = data['nama'] ?? '';
      _nipController.text = data['nip'] ?? '';
      _emailController.text = data['email'] ?? '';
      _jabatanController.text = data['jabatan'] ?? '';
      _noHpController.text = data['no_hp'] ?? '';
      // Password tidak ditampilkan saat edit demi keamanan
    }
  }

  @override
  void dispose() {
    _namaController.dispose();
    _nipController.dispose();
    _emailController.dispose();
    _jabatanController.dispose();
    _noHpController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _saveData() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    final nama = _namaController.text.trim();
    final nip = _nipController.text.trim();
    final email = _emailController.text.trim();
    final jabatan = _jabatanController.text.trim();
    final noHp = _noHpController.text.trim();
    final password = _passwordController.text.trim();

    try {
      if (widget.employeeData == null) {
        // --- KASUS 1: TAMBAH PEGAWAI BARU (Create Account) ---
        
        // 1. Buat Akun di Supabase Auth (Email & Pass)
        // PERINGATAN: Di Flutter client, fungsi ini akan membuat Admin ter-logout otomatis!
        final AuthResponse res = await supabase.auth.signUp(
          email: email,
          password: password,
        );

        if (res.user != null) {
          // 2. Simpan Biodata ke Tabel 'users' menggunakan ID dari Auth
          await supabase.from('users').insert({
            'id': res.user!.id, // PENTING: ID ini harus sama dengan Auth
            'nip': nip,
            'nama': nama,
            'email': email,
            'jabatan': jabatan,
            'no_hp': noHp,
            'role': 'pegawai', // Default role
            'created_at': DateTime.now().toIso8601String(),
          });

          if (mounted) {
            // Tampilkan Dialog Logout Paksa (Karena sesi Admin tertimpa User baru)
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                title: const Text("Berhasil & Logout"),
                content: const Text(
                  "Akun pegawai berhasil dibuat.\n\n"
                  "Karena batasan keamanan sistem, sesi Admin Anda berakhir. Silakan login kembali sebagai Admin."
                ),
                actions: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (context) => const LoginScreen()),
                        (route) => false,
                      );
                    },
                    child: const Text("OK, Login Ulang"),
                  )
                ],
              ),
            );
          }
        }
      } else {
        // --- KASUS 2: EDIT PEGAWAI (Update Data) ---
        // Kita tidak mengubah password di sini, hanya data profil
        final id = widget.employeeData!['id'];
        
        await supabase.from('users').update({
          'nama': nama,
          'nip': nip,
          'email': email,
          'jabatan': jabatan,
          'no_hp': noHp,
        }).eq('id', id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Data berhasil diperbarui!")),
          );
          
          // --- PERBAIKAN DI SINI ---
          // Mengirim sinyal 'true' agar halaman list tahu data berubah
          Navigator.pop(context, true); 
        }
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
    final isEditMode = widget.employeeData != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditMode ? "Edit Pegawai" : "Tambah Pegawai Baru"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // NIP
              TextFormField(
                controller: _nipController,
                decoration: const InputDecoration(labelText: "NIP", border: OutlineInputBorder(), prefixIcon: Icon(Icons.badge)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 16),

              // Nama
              TextFormField(
                controller: _namaController,
                decoration: const InputDecoration(labelText: "Nama Lengkap", border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 16),

              // Email (Read Only jika Edit Mode agar tidak merusak Auth)
              TextFormField(
                controller: _emailController,
                readOnly: isEditMode, // Tidak bisa ubah email saat edit (rumit logic auth-nya)
                decoration: InputDecoration(
                  labelText: "Email Login", 
                  border: const OutlineInputBorder(), 
                  prefixIcon: const Icon(Icons.email),
                  filled: isEditMode,
                  fillColor: isEditMode ? Colors.grey.shade200 : null,
                ),
                validator: (val) => !val!.contains('@') ? "Email tidak valid" : null,
              ),
              const SizedBox(height: 16),

              // Password (HANYA MUNCUL SAAT TAMBAH BARU)
              if (!isEditMode) ...[
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: "Password Awal", 
                    border: OutlineInputBorder(), 
                    prefixIcon: Icon(Icons.lock),
                    helperText: "Minimal 6 karakter"
                  ),
                  validator: (val) => val!.length < 6 ? "Password terlalu pendek" : null,
                ),
                const SizedBox(height: 16),
              ],

              // Jabatan
              TextFormField(
                controller: _jabatanController,
                decoration: const InputDecoration(labelText: "Jabatan", border: OutlineInputBorder(), prefixIcon: Icon(Icons.work)),
                validator: (val) => val!.isEmpty ? "Wajib diisi" : null,
              ),
              const SizedBox(height: 16),

              // No HP
              TextFormField(
                controller: _noHpController,
                decoration: const InputDecoration(labelText: "No HP", border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
              ),
              const SizedBox(height: 30),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _saveData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(isEditMode ? "SIMPAN PERUBAHAN" : "BUAT AKUN PEGAWAI"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}