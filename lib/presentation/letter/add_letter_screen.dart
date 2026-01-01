import 'dart:io';
import 'package:flutter/foundation.dart'; // Untuk kIsWeb
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../data/models/letter_model.dart'; // Pastikan import model

class AddLetterScreen extends StatefulWidget {
  final String jenisSurat;
  final LetterModel? letterToEdit; // TAMBAHAN: Data surat jika mode Edit

  const AddLetterScreen({
    super.key, 
    required this.jenisSurat, 
    this.letterToEdit // Boleh null (artinya mode Tambah Baru)
  });

  @override
  State<AddLetterScreen> createState() => _AddLetterScreenState();
}

class _AddLetterScreenState extends State<AddLetterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nomorController = TextEditingController();
  final _perihalController = TextEditingController();
  final _pihakController = TextEditingController();
  final _dateController = TextEditingController();
  
  final supabase = Supabase.instance.client;
  
  XFile? _selectedImage; 
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // LOGIKA ISI DATA JIKA MODE EDIT
    if (widget.letterToEdit != null) {
      _nomorController.text = widget.letterToEdit!.nomorSurat;
      _perihalController.text = widget.letterToEdit!.perihal;
      _pihakController.text = widget.letterToEdit!.pihakTerkait;
      _dateController.text = widget.letterToEdit!.tanggalSurat;
    }
  }

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() => _selectedImage = image);
    }
  }

  Future<void> _submitData() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validasi Foto:
    // Jika Mode Tambah: Wajib ada _selectedImage
    // Jika Mode Edit: Boleh kosong (artinya pakai foto lama)
    if (widget.letterToEdit == null && _selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Harap lampirkan foto surat")));
      return;
    }

    setState(() => _isUploading = true);

    try {
      String? imageUrl;

      // 1. Cek apakah user upload foto baru?
      if (_selectedImage != null) {
        // Upload Foto Baru
        final bytes = await _selectedImage!.readAsBytes();
        final String fileExt = _selectedImage!.name.split('.').last; 
        final fileName = '${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        final path = 'uploads/$fileName';

        await supabase.storage.from('letters').uploadBinary(
          path, bytes,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: false),
        );
        imageUrl = supabase.storage.from('letters').getPublicUrl(path);
      } else {
        // Tidak upload baru, pakai URL lama
        imageUrl = widget.letterToEdit?.fileUrl;
      }

      // 2. Siapkan Data
      final tableName = widget.jenisSurat == 'Masuk' ? 'incoming_letters' : 'outgoing_letters';
      final pihakColumn = widget.jenisSurat == 'Masuk' ? 'asal_surat' : 'tujuan_surat';
      
      final dataToInsert = {
        'nomor_surat': _nomorController.text,
        'perihal': _perihalController.text,
        'tanggal_surat': _dateController.text,
        pihakColumn: _pihakController.text,
        'file_url': imageUrl,
      };

      if (widget.jenisSurat == 'Masuk' && widget.letterToEdit == null) {
        dataToInsert['tanggal_terima'] = DateTime.now().toIso8601String();
      }

      // 3. Eksekusi (INSERT atau UPDATE)
      if (widget.letterToEdit == null) {
        // Mode Tambah
        await supabase.from(tableName).insert(dataToInsert);
      } else {
        // Mode Edit (Update berdasarkan ID)
        await supabase.from(tableName).update(dataToInsert).eq('id', widget.letterToEdit!.id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(widget.letterToEdit == null ? "Berhasil disimpan" : "Berhasil diupdate")));
        Navigator.pop(context, true); // Kembali dengan sukses
      }

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final labelPihak = widget.jenisSurat == 'Masuk' ? "Pengirim (Instansi Asal)" : "Tujuan (Penerima)";
    final isEditMode = widget.letterToEdit != null;

    return Scaffold(
      appBar: AppBar(title: Text(isEditMode ? 'Edit Surat' : 'Tambah Surat')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _nomorController,
                decoration: const InputDecoration(labelText: 'Nomor Surat', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _perihalController,
                decoration: const InputDecoration(labelText: 'Perihal / Subjek', border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _pihakController,
                decoration: InputDecoration(labelText: labelPihak, border: const OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateController,
                decoration: const InputDecoration(labelText: 'Tanggal Surat', border: OutlineInputBorder(), suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: () async {
                  DateTime? pickedDate = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2000), lastDate: DateTime(2100)
                  );
                  if (pickedDate != null) {
                     _dateController.text = DateFormat('yyyy-MM-dd').format(pickedDate);
                  }
                },
                validator: (val) => val!.isEmpty ? 'Wajib diisi' : null,
              ),
              const SizedBox(height: 20),

              const Text("Foto Fisik Surat:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _selectedImage != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: kIsWeb 
                             ? Image.network(_selectedImage!.path, fit: BoxFit.contain)
                             : Image.file(File(_selectedImage!.path), fit: BoxFit.contain),
                        )
                      : (widget.letterToEdit?.fileUrl != null) 
                          // Jika mode Edit dan belum ganti foto, tampilkan foto lama dari URL
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(widget.letterToEdit!.fileUrl!, fit: BoxFit.contain),
                            )
                          : const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt, size: 40, color: Colors.grey),
                                Text("Ketuk untuk ganti/upload foto"),
                              ],
                            ),
                ),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isUploading ? null : _submitData,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: _isUploading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(isEditMode ? "UPDATE SURAT" : "SIMPAN SURAT"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}