import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/letter_model.dart';
import 'add_letter_screen.dart'; // Import halaman tambah
import 'letter_detail_screen.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({super.key});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
    ); // 2 Tabs: Masuk & Keluar
  }

  // Widget untuk menampilkan List Surat (Reusable)
  // Update fungsi ini di letter_screen.dart
  Widget _buildLetterList(String jenis) {
    final tableName = jenis == 'Masuk'
        ? 'incoming_letters'
        : 'outgoing_letters';

    return FutureBuilder(
      future: supabase
          .from(tableName)
          .select()
          .order('created_at', ascending: false),
      builder: (context, snapshot) {
        // 1. Cek Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        // 2. Cek Error Teknis
        if (snapshot.hasError) {
          debugPrint("ERROR SUPABASE: ${snapshot.error}"); // Cek Terminal Anda!
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        // 3. Cek Apakah Data Kosong
        final List<dynamic>? data = snapshot.data as List<dynamic>?;

        if (data == null || data.isEmpty) {
          debugPrint("DATA KOSONG. Cek RLS atau Nama Tabel di Supabase.");
          return Center(child: Text("Belum ada data Surat $jenis"));
        }

        // 4. Debug Data Mentah (Pastikan data masuk)
        // debugPrint("Data diterima: $data");

        try {
          final letters = data.map((json) {
            return jenis == 'Masuk'
                ? LetterModel.fromIncoming(json)
                : LetterModel.fromOutgoing(json);
          }).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: letters.length,
            itemBuilder: (context, index) {
              final letter = letters[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  // ... di dalam _buildLetterList -> ListView.builder -> ListTile
                  onTap: () async {
                    // Navigasi ke Detail
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            LetterDetailScreen(letter: letter),
                      ),
                    );

                    // Jika kembali dari detail membawa sinyal 'true' (habis diupdate), refresh list
                    if (result == true) {
                      // Cara simple refresh: karena kita pakai FutureBuilder langsung di build,
                      // cukup panggil setState kosong untuk men-trigger rebuild.
                      setState(() {});
                    }
                  },
                  leading: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                      image: letter.fileUrl != null
                          ? DecorationImage(
                              image: NetworkImage(letter.fileUrl!),
                              fit: BoxFit.cover,
                            )
                          : null,
                    ),
                    child: letter.fileUrl == null
                        ? const Icon(Icons.email, color: Colors.indigo)
                        : null,
                  ),
                  title: Text(
                    letter.perihal,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    maxLines: 1,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("No: ${letter.nomorSurat}"),
                      Text("Tgl: ${letter.tanggalSurat}"),
                    ],
                  ),
                  isThreeLine: true,
                ),
              );
            },
          );
        } catch (e) {
          debugPrint("ERROR PARSING DATA: $e");
          return Center(child: Text("Gagal memproses data: $e"));
        }
      },
    );
  }

  // Navigasi ke Halaman Tambah
  void _navigateToAddScreen() async {
    final currentType = _tabController.index == 0
        ? 'Masuk'
        : 'Keluar'; // Cek tab aktif

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLetterScreen(jenisSurat: currentType),
      ),
    );

    if (result == true) {
      setState(() {}); // Refresh jika berhasil simpan
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arsip Surat'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Surat Masuk', icon: Icon(Icons.move_to_inbox)),
            Tab(text: 'Surat Keluar', icon: Icon(Icons.outbox)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLetterList('Masuk'), // Tab 1
          _buildLetterList('Keluar'), // Tab 2
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _navigateToAddScreen,
        backgroundColor: Colors.indigo,
        child: const Icon(Icons.add),
      ),
    );
  }
}
