import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Import Supabase
import '../../data/models/letter_model.dart';
import 'add_letter_screen.dart'; 

class LetterDetailScreen extends StatefulWidget {
  final LetterModel letter;

  const LetterDetailScreen({super.key, required this.letter});

  @override
  State<LetterDetailScreen> createState() => _LetterDetailScreenState();
}

class _LetterDetailScreenState extends State<LetterDetailScreen> {
  final supabase = Supabase.instance.client; // Inisialisasi Client
  bool _isDeleting = false;

  // --- FUNGSI HAPUS SURAT ---
  Future<void> _deleteLetter() async {
    setState(() => _isDeleting = true);

    try {
      final tableName = widget.letter.jenis == 'Masuk' ? 'incoming_letters' : 'outgoing_letters';

      // 1. Hapus Data dari Database
      await supabase.from(tableName).delete().eq('id', widget.letter.id);

      // (Opsional) Hapus File Gambar dari Storage
      // Jika ingin hemat storage, kita bisa hapus gambarnya juga.
      // Tapi karena nama file harus diparsing dari URL, untuk pemula kita skip dulu agar aman.
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Surat berhasil dihapus")));
        // Kembali ke layar sebelumnya dengan sinyal 'true' agar list direfresh
        Navigator.pop(context, true); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal menghapus: $e")));
      }
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  // --- FUNGSI KONFIRMASI (DIALOG) ---
  void _showDeleteConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Hapus Surat?"),
        content: const Text("Data yang dihapus tidak dapat dikembalikan. Apakah Anda yakin?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), // Tutup dialog
            child: const Text("Batal"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () {
              Navigator.pop(context); // Tutup dialog dulu
              _deleteLetter(); // Jalankan fungsi hapus
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // Fungsi Pindah ke Halaman Edit
  void _navigateToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddLetterScreen(
          jenisSurat: widget.letter.jenis, 
          letterToEdit: widget.letter,     
        ),
      ),
    );

    if (result == true) {
      if (mounted) Navigator.pop(context, true); 
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Surat'),
        actions: [
          // TOMBOL HAPUS (Sampah)
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            tooltip: 'Hapus Surat',
            onPressed: _isDeleting ? null : _showDeleteConfirmation,
          ),
          // TOMBOL EDIT (Pensil)
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit Surat',
            onPressed: _isDeleting ? null : _navigateToEdit,
          )
        ],
      ),
      body: _isDeleting 
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Gambar Surat
                  Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.grey.shade200,
                    child: widget.letter.fileUrl != null
                        ? Image.network(
                            widget.letter.fileUrl!,
                            fit: BoxFit.contain,
                            loadingBuilder: (ctx, child, progress) {
                              if (progress == null) return child;
                              return const Center(child: CircularProgressIndicator());
                            },
                            errorBuilder: (ctx, _, __) => const Center(child: Icon(Icons.broken_image, size: 50)),
                          )
                        : const Center(child: Text("Tidak ada lampiran gambar")),
                  ),
                  
                  // Informasi Detail
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailItem("Nomor Surat", widget.letter.nomorSurat),
                        _buildDetailItem("Tanggal Surat", widget.letter.tanggalSurat),
                        const Divider(),
                        _buildDetailItem("Perihal", widget.letter.perihal, isBold: true),
                        const Divider(),
                        _buildDetailItem(
                          widget.letter.jenis == 'Masuk' ? "Pengirim (Asal)" : "Penerima (Tujuan)", 
                          widget.letter.pihakTerkait
                        ),
                        
                        const SizedBox(height: 30),
                        
                        // Tombol Hapus Tambahan di Bawah (Opsional, biar lebih jelas)
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red, 
                              side: const BorderSide(color: Colors.red)
                            ),
                            onPressed: _showDeleteConfirmation,
                            icon: const Icon(Icons.delete_forever),
                            label: const Text("HAPUS SURAT INI"),
                          ),
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDetailItem(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              fontSize: 16, 
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: Colors.black87
            )
          ),
        ],
      ),
    );
  }
}