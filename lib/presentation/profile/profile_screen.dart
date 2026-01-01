import 'dart:io';
import 'package:flutter/foundation.dart'; // Untuk kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/login_screen.dart'; // PASTIKAN IMPORT HALAMAN LOGIN ANDA

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  final _namaController = TextEditingController();
  final _phoneController = TextEditingController();
  final _alamatController = TextEditingController();
  
  String _email = '';
  String _jabatan = '';
  String? _currentAvatarUrl;
  
  XFile? _pickedImage;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final data = await supabase.from('users').select().eq('id', user.id).single();

      setState(() {
        _namaController.text = data['nama'] ?? '';
        _phoneController.text = data['no_hp'] ?? '';
        _alamatController.text = data['alamat'] ?? '';
        _email = data['email'] ?? '-';
        _jabatan = data['jabatan'] ?? '-';
        _currentAvatarUrl = data['avatar_url'];
      });
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal load profil: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (image != null) {
      setState(() => _pickedImage = image);
    }
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      String? newAvatarUrl = _currentAvatarUrl;

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final fileExt = _pickedImage!.name.split('.').last;
        final fileName = '${user.id}_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final path = fileName;

        await supabase.storage.from('avatars').uploadBinary(
          path, bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );
        newAvatarUrl = supabase.storage.from('avatars').getPublicUrl(path);
      }

      await supabase.from('users').update({
        'nama': _namaController.text,
        'no_hp': _phoneController.text,
        'alamat': _alamatController.text,
        'avatar_url': newAvatarUrl,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profil berhasil diperbarui!")));
        setState(() {
           _currentAvatarUrl = newAvatarUrl;
           _pickedImage = null;
        });
      }

    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal update: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
  }

  // --- FUNGSI LOGOUT (BARU) ---
  Future<void> _signOut() async {
    // Tampilkan konfirmasi dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Keluar Aplikasi"),
        content: const Text("Apakah Anda yakin ingin logout?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Ya, Keluar", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.auth.signOut();
      if (mounted) {
        // Pindah ke Halaman Login dan hapus semua history navigasi sebelumnya
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const LoginScreen()), 
          (route) => false
        );
      }
    }
  }

  Widget _buildAvatarUI() {
    ImageProvider? backgroundImage;
    Widget? childWidget;

    if (_pickedImage != null) {
      if (kIsWeb) {
        backgroundImage = NetworkImage(_pickedImage!.path);
      } else {
        backgroundImage = FileImage(File(_pickedImage!.path));
      }
    } else if (_currentAvatarUrl != null && _currentAvatarUrl!.isNotEmpty) {
      backgroundImage = NetworkImage(_currentAvatarUrl!);
    } else {
      childWidget = Text(
        _namaController.text.isNotEmpty ? _namaController.text[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 40, color: Colors.indigo),
      );
    }

    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 60,
            backgroundColor: Colors.indigo.shade100,
            backgroundImage: backgroundImage,
            child: childWidget,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: InkWell(
              onTap: _pickImage,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(color: Colors.indigo, shape: BoxShape.circle),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profil')),
      body: _isLoading && _namaController.text.isEmpty
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _buildAvatarUI(),
                    const SizedBox(height: 30),
                    
                    _buildReadOnlyField("Email", _email, Icons.email),
                    _buildReadOnlyField("Jabatan", _jabatan, Icons.work),
                    const Divider(height: 30),
                    
                    TextFormField(
                      controller: _namaController,
                      decoration: const InputDecoration(labelText: 'Nama Lengkap', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                      validator: (val) => val!.isEmpty ? 'Nama tidak boleh kosong' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      decoration: const InputDecoration(labelText: 'No. Handphone', border: OutlineInputBorder(), prefixIcon: Icon(Icons.phone)),
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _alamatController,
                      decoration: const InputDecoration(labelText: 'Alamat Domisili', border: OutlineInputBorder(), prefixIcon: Icon(Icons.home)),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 30),

                    // TOMBOL SIMPAN
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                        child: _isLoading 
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("SIMPAN PERUBAHAN"),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // --- TOMBOL LOGOUT (BARU) ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _signOut, // Panggil fungsi Logout
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red, 
                          side: const BorderSide(color: Colors.red)
                        ),
                        icon: const Icon(Icons.logout),
                        label: const Text("KELUAR APLIKASI"),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildReadOnlyField(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: TextField(
        enabled: false,
        controller: TextEditingController(text: value),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          prefixIcon: Icon(icon, color: Colors.grey),
          filled: true,
          fillColor: Colors.grey.shade100,
          disabledBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.grey.shade300)),
        ),
      ),
    );
  }
}