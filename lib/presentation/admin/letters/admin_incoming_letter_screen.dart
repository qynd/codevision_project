import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

class AdminIncomingLetterScreen extends StatefulWidget {
  const AdminIncomingLetterScreen({super.key});

  @override
  State<AdminIncomingLetterScreen> createState() => _AdminIncomingLetterScreenState();
}

class _AdminIncomingLetterScreenState extends State<AdminIncomingLetterScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = false;

  Future<List<Map<String, dynamic>>> _fetchLetters() async {
    final response = await supabase
        .from('incoming_letters')
        .select()
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _deleteLetter(String id) async {
    try {
      await supabase.from('incoming_letters').delete().eq('id', id);
      setState(() {});
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Surat dihapus")));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal: $e")));
    }
  }

  // --- LOGIKA UPLOAD ---
  Future<String?> _uploadImage(XFile imageFile) async {
    try {
      final bytes = await imageFile.readAsBytes();
      final fileExt = imageFile.path.split('.').last;
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
      final filePath = 'incoming/$fileName';

      await supabase.storage.from('letters').uploadBinary(
            filePath,
            bytes,
            fileOptions: FileOptions(contentType: imageFile.mimeType),
          );
      
      final imageUrl = supabase.storage.from('letters').getPublicUrl(filePath);
      return imageUrl;
    } catch (e) {
      debugPrint("Upload Error: $e");
      return null;
    }
  }

  // --- FORM DIALOG ---
  void _showFormDialog({Map<String, dynamic>? letter}) {
    final _formKey = GlobalKey<FormState>();
    final _noController = TextEditingController(text: letter?['nomor_surat'] ?? '');
    final _asalController = TextEditingController(text: letter?['asal_surat'] ?? '');
    final _perihalController = TextEditingController(text: letter?['perihal'] ?? '');
    final _tglSuratController = TextEditingController(text: letter?['tanggal_surat'] ?? '');
    final _tglTerimaController = TextEditingController(text: letter?['tanggal_terima'] ?? '');
    
    // Variable state lokal dialog untuk handle gambar
    XFile? _pickedImage; 
    String? _existingImageUrl = letter?['file_url'];
    bool _isUploading = false;

    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(letter == null ? "Tambah Surat Masuk" : "Edit Surat Masuk"),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: _noController,
                        decoration: const InputDecoration(labelText: "Nomor Surat", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _asalController,
                        decoration: const InputDecoration(labelText: "Asal Surat", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _perihalController,
                        decoration: const InputDecoration(labelText: "Perihal", border: OutlineInputBorder()),
                        validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                      ),
                      const SizedBox(height: 12),
                      
                      // Tanggal Surat
                      InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context, initialDate: DateTime.now(), 
                            firstDate: DateTime(2000), lastDate: DateTime(2050));
                          if(picked != null) _tglSuratController.text = DateFormat('yyyy-MM-dd').format(picked);
                        },
                        child: TextFormField(
                          controller: _tglSuratController,
                          decoration: const InputDecoration(labelText: "Tanggal Surat", suffixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                          enabled: false,
                          validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(height: 12),
                      
                      // Tanggal Terima
                      InkWell(
                        onTap: () async {
                          DateTime? picked = await showDatePicker(
                            context: context, initialDate: DateTime.now(), 
                            firstDate: DateTime(2000), lastDate: DateTime(2050));
                          if(picked != null) _tglTerimaController.text = DateFormat('yyyy-MM-dd').format(picked);
                        },
                        child: TextFormField(
                          controller: _tglTerimaController,
                          decoration: const InputDecoration(labelText: "Tanggal Terima", suffixIcon: Icon(Icons.calendar_today), border: OutlineInputBorder()),
                          enabled: false,
                          validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // UPLOAD FOTO AREA
                      const Text("Lampiran Foto Surat (Opsional)", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () async {
                           final ImagePicker picker = ImagePicker();
                           final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                           if(image != null) {
                             setDialogState(() => _pickedImage = image);
                           }
                        },
                        child: Container(
                          height: 150,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade100,
                          ),
                          child: _pickedImage != null 
                            ? Image.network(_pickedImage!.path, fit: BoxFit.cover) // Untuk Web gunakan path/bytes
                            : (_existingImageUrl != null 
                                ? Image.network(_existingImageUrl!, fit: BoxFit.cover)
                                : const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [Icon(Icons.add_a_photo, size: 40, color: Colors.grey), Text("Tap untuk upload")],
                                  )
                              ),
                        ),
                      ),
                      if (_pickedImage != null)
                        TextButton.icon(
                          onPressed: () => setDialogState(() => _pickedImage = null), 
                          icon: const Icon(Icons.close, color: Colors.red),
                          label: const Text("Hapus Foto")
                        )
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Batal")),
                ElevatedButton(
                  onPressed: _isUploading ? null : () async {
                    if (_formKey.currentState!.validate()) {
                      setDialogState(() => _isUploading = true);
                      
                      try {
                        String? fileUrl = _existingImageUrl;
                        
                        // Upload Image jika ada yang baru dipilih
                        if (_pickedImage != null) {
                           final url = await _uploadImage(_pickedImage!);
                           if (url != null) fileUrl = url;
                        }

                        final data = {
                          'nomor_surat': _noController.text,
                          'asal_surat': _asalController.text,
                          'perihal': _perihalController.text,
                          'tanggal_surat': _tglSuratController.text,
                          'tanggal_terima': _tglTerimaController.text,
                          'file_url': fileUrl,
                          'status': 'Pending' // Default
                        };
                        
                        if (letter == null) {
                          await supabase.from('incoming_letters').insert(data);
                        } else {
                          await supabase.from('incoming_letters').update(data).eq('id', letter['id']);
                        }
                        
                        if (mounted) {
                          Navigator.pop(context);
                          setState(() {}); // Refresh list
                        }
                      } catch (e) {
                         debugPrint(e.toString());
                      } finally {
                        setDialogState(() => _isUploading = false);
                      }
                    }
                  }, 
                  child: _isUploading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator()) : const Text("Simpan")
                )
              ],
            );
          }
        );
      }
    );
  }

  // --- DETAIL DIALOG (Gaya Modern) ---
  void _showDetail(Map<String, dynamic> letter) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Gambar Header (Jika ada)
              if (letter['file_url'] != null)
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  child: Image.network(
                    letter['file_url'],
                    height: 250,
                    fit: BoxFit.cover,
                    errorBuilder: (ctx, err, stack) => Container(
                      height: 150, color: Colors.grey.shade200, 
                      child: const Center(child: Icon(Icons.broken_image, color: Colors.grey))
                    ),
                  ),
                )
              else 
                Container(
                  height: 100, 
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                  child: const Center(child: Icon(Icons.mail, size: 50, color: Colors.indigo)),
                ),
              
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(letter['perihal'] ?? 'Tanpa Perihal', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Divider(color: Colors.grey.shade300),
                    const SizedBox(height: 8),
                    _detailItem("Nomor Surat", letter['nomor_surat']),
                    _detailItem("Asal Surat", letter['asal_surat']),
                    _detailItem("Tanggal Surat", letter['tanggal_surat']),
                    _detailItem("Tanggal Terima", letter['tanggal_terima']),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: ElevatedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                  label: const Text("Tutup"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailItem(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 120, child: Text(label, style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.w500))),
          Expanded(child: Text(value ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showFormDialog(),
        label: const Text("Tambah Surat"),
        icon: const Icon(Icons.add),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _fetchLetters(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          if (!snapshot.hasData || snapshot.data!.isEmpty) return const Center(child: Text("Belum ada surat masuk."));

          final letters = snapshot.data!;
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: letters.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = letters[index];
              return Card(
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDetail(item),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Thumbnail
                        Container(
                          width: 60, height: 60,
                          decoration: BoxDecoration(
                            color: Colors.indigo.shade50,
                            borderRadius: BorderRadius.circular(8),
                            image: item['file_url'] != null ? DecorationImage(image: NetworkImage(item['file_url']), fit: BoxFit.cover) : null,
                          ),
                          child: item['file_url'] == null ? const Icon(Icons.image_not_supported, color: Colors.indigo) : null,
                        ),
                        const SizedBox(width: 12),
                        // Konten
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(item['perihal'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16), maxLines: 2, overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 4),
                              Text("No: ${item['nomor_surat']}", style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(Icons.business, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(child: Text(item['asal_surat'], style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis)),
                                ],
                              )
                            ],
                          ),
                        ),
                        // Aksi Edit
                        Column(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _showFormDialog(letter: item),
                            ),
                            const SizedBox(height: 12),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () => _deleteLetter(item['id']),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
