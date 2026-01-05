import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/models/letter_model.dart';
import '../../core/constants/app_theme.dart'; // Import Theme
import 'add_letter_screen.dart'; 
import 'letter_detail_screen.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({super.key});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this); 
  }

  // --- WIDGET LIST SURAT KEREN ---
  Widget _buildLetterList(String jenis) {
    final tableName = jenis == 'Masuk' ? 'incoming_letters' : 'outgoing_letters';

    return FutureBuilder(
      future: supabase.from(tableName).select().order('created_at', ascending: false),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text("Error: ${snapshot.error}"));
        }

        final List<dynamic>? data = snapshot.data as List<dynamic>?;

        if (data == null || data.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(jenis == 'Masuk' ? Icons.inbox_rounded : Icons.outbox_rounded, size: 80, color: Colors.grey.shade300),
                const SizedBox(height: 16),
                Text("Belum ada Surat $jenis", style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
              ],
            ),
          );
        }

        try {
          final letters = data.map((json) {
            return jenis == 'Masuk' ? LetterModel.fromIncoming(json) : LetterModel.fromOutgoing(json);
          }).toList();

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: letters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final letter = letters[index];
              return _buildLetterCard(letter, jenis);
            },
          );
        } catch (e) {
          return Center(child: Text("Gagal memproses data: $e"));
        }
      },
    );
  }

  Widget _buildLetterCard(LetterModel letter, String jenis) {
    return Card(
      elevation: 3,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => LetterDetailScreen(letter: letter)),
          );
          if (result == true) setState(() {});
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. THUMBNAIL BERGAYA
              Container(
                width: 70, height: 70,
                decoration: BoxDecoration(
                  color: jenis == 'Masuk' ? Colors.blue.shade50 : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  image: letter.fileUrl != null
                      ? DecorationImage(image: NetworkImage(letter.fileUrl!), fit: BoxFit.cover)
                      : null,
                ),
                child: letter.fileUrl == null 
                  ? Icon(jenis == 'Masuk' ? Icons.email_outlined : Icons.send_outlined, 
                      color: jenis == 'Masuk' ? CodevisionTheme.primaryColor : CodevisionTheme.accentColor, size: 30)
                  : null,
              ),
              const SizedBox(width: 16),
              
              // 2. KONTEN UTAMA
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag Kecil Nomor Surat
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        letter.nomorSurat, 
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade700, fontWeight: FontWeight.bold)
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      letter.perihal,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(
                          letter.tanggalSurat, 
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600)
                        ),
                      ],
                    )
                  ],
                ),
              ),
              
              // 3. ICON CHEVRON
              const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToAddScreen() async {
    final currentType = _tabController.index == 0 ? 'Masuk' : 'Keluar';
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddLetterScreen(jenisSurat: currentType)),
    );
    if (result == true) setState(() {}); 
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Arsip Surat', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: CodevisionTheme.primaryColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: CodevisionTheme.accentColor,
          indicatorWeight: 4,
          tabs: const [
            Tab(text: 'Surat Masuk', icon: Icon(Icons.move_to_inbox_rounded)),
            Tab(text: 'Surat Keluar', icon: Icon(Icons.outbox_rounded)),
          ],
        ),
      ),
      backgroundColor: CodevisionTheme.backgroundColor,
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLetterList('Masuk'), 
          _buildLetterList('Keluar'), 
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _navigateToAddScreen,
        backgroundColor: CodevisionTheme.accentColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text("Tulis Baru"),
      ),
    );
  }
}
