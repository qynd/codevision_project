import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'employee_form_screen.dart'; // Pastikan import ini benar

class EmployeeListScreen extends StatefulWidget {
  const EmployeeListScreen({super.key});

  @override
  State<EmployeeListScreen> createState() => _EmployeeListScreenState();
}

class _EmployeeListScreenState extends State<EmployeeListScreen> {
  final supabase = Supabase.instance.client;
  
  String _searchQuery = "";
  final TextEditingController _searchController = TextEditingController();

  // 1. Ganti Stream menjadi Future agar bisa direfresh manual
  Future<List<Map<String, dynamic>>> _fetchEmployees() async {
    final response = await supabase
        .from('users')
        .select()
        .order('nama', ascending: true);
        
    // Filter manual di sisi aplikasi
    final data = List<Map<String, dynamic>>.from(response);
    
    if (_searchQuery.isEmpty) return data;
    
    // Logika pencarian
    return data.where((user) {
      final nama = (user['nama'] ?? '').toLowerCase();
      final nip = (user['nip'] ?? '').toLowerCase();
      final query = _searchQuery.toLowerCase();
      return nama.contains(query) || nip.contains(query);
    }).toList();
  }

  // Fungsi Hapus
  Future<void> _deleteEmployee(String id, String nama) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Pegawai?"),
        content: Text("Apakah Anda yakin ingin menghapus data '$nama'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Batal")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Hapus"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('users').delete().eq('id', id);
        
        // 2. Refresh List setelah hapus
        setState(() {}); 

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Pegawai $nama berhasil dihapus")));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
        }
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Data Pegawai"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      
      // --- LOGIKA REFRESH SAAT TAMBAH PEGAWAI ---
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        onPressed: () async {
          // Tunggu sampai halaman Form ditutup
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const EmployeeFormScreen()),
          );
          
          // Selalu refresh setelah kembali (untuk jaga-jaga)
          setState(() {});
        },
        child: const Icon(Icons.add),
      ),
      
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Cari Nama atau NIP...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (val) {
                // Refresh list saat mengetik
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),

          // List Data (Menggunakan FutureBuilder)
          Expanded(
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchEmployees(), // Dipanggil ulang setiap setState
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }

                final data = snapshot.data ?? [];

                if (data.isEmpty) {
                  return const Center(child: Text("Belum ada data pegawai."));
                }

                return ListView.separated(
                  padding: const EdgeInsets.only(bottom: 80),
                  itemCount: data.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final employee = data[index];
                    final id = employee['id'];
                    final nama = employee['nama'] ?? 'Tanpa Nama';
                    final nip = employee['nip'] ?? '-';
                    final jabatan = employee['jabatan'] ?? 'Staff';

                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.indigo.shade50,
                        child: Text(
                          nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                        ),
                      ),
                      title: Text(nama, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("NIP: $nip  •  $jabatan"),
                      
                      // Menu Edit & Delete
                      trailing: PopupMenuButton(
                        onSelected: (value) async {
                          if (value == 'edit') {
                            // --- LOGIKA REFRESH SAAT EDIT ---
                            final result = await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EmployeeFormScreen(employeeData: employee),
                              ),
                            );
                            
                            // Jika ada perubahan (result == true), refresh list
                            if (result == true) {
                              setState(() {});
                            }
                          } else if (value == 'delete') {
                            _deleteEmployee(id, nama);
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'edit',
                            child: Row(children: [Icon(Icons.edit, color: Colors.blue), SizedBox(width: 8), Text("Edit")]),
                          ),
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Hapus")]),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}