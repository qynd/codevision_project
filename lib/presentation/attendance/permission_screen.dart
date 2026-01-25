import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class PermissionScreen extends StatefulWidget {
  const PermissionScreen({super.key});

  @override
  State<PermissionScreen> createState() => _PermissionScreenState();
}

class _PermissionScreenState extends State<PermissionScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _reasonController = TextEditingController();
  final _durationController = TextEditingController(text: '1'); 
  final _dateController = TextEditingController(); 
  
  final supabase = Supabase.instance.client;
  
  String _selectedType = 'Izin'; 
  DateTime _selectedDate = DateTime.now(); // Default hari ini
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Set default tampilan tanggal hari ini di input field
    _dateController.text = DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    _durationController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  // Fungsi Pilih Tanggal
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd MMMM yyyy', 'id_ID').format(picked);
      });
    }
  }

  // Fungsi Kirim Data
  Future<void> _submitPermission() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw "User tidak terdeteksi";

      // 0. CEK APAKAH SUDAH ABSEN 'HADIR' HARI INI
      // Jika sudah absen masuk, tidak boleh izin/sakit di hari yang sama
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final existingAttendance = await supabase.from('attendances')
          .select()
          .eq('user_id', user.id)
          .eq('tanggal', today)
          .maybeSingle();

      if (existingAttendance != null) {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("GAGAL: Anda sudah melakukan Absen Masuk hari ini. Tidak dapat mengajukan Izin/Sakit."), backgroundColor: Colors.red),
            );
         }
         return; // STOP PROSES
      }

      // 1. Hitung Tanggal Selesai
      int duration = 1;
      if (_selectedType == 'Cuti') {
        duration = int.tryParse(_durationController.text) ?? 1;
      }
      
      // Hitung end date berdasarkan durasi
      // Jika durasi 1 hari, start & end sama. Jika 2 hari, end = start + 1 hari.
      final endDate = _selectedDate.add(Duration(days: duration - 1));

      // 2. Simpan ke tabel 'letters' (Agar terbaca di Admin Validasi Surat)
      await supabase.from('letters').insert({
        'user_id': user.id,
        'jenis_surat': _selectedType, // 'Izin', 'Sakit', 'Cuti'
        'keterangan': _reasonController.text,
        'tanggal_mulai': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'tanggal_selesai': DateFormat('yyyy-MM-dd').format(endDate),
        'status': 'Pending', // Default status
      });

      if (mounted) {
        // Tampilkan Dialog Sukses
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text("Berhasil Dikirim"),
            content: const Text("Pengajuan Anda telah dikirim dan menunggu persetujuan Admin."),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context); // Tutup Dialog
                  Navigator.pop(context, true); // Kembali ke halaman sebelumnya
                },
                child: const Text("OK"),
              )
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajukan Izin / Cuti'),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- JENIS PENGAJUAN ---
              const Text("Jenis Pengajuan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(border: OutlineInputBorder()),
                items: ['Izin', 'Sakit', 'Cuti'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Row(
                      children: [
                        Icon(
                          value == 'Sakit' ? Icons.local_hospital : 
                          value == 'Cuti' ? Icons.beach_access : Icons.assignment,
                          color: Colors.indigo, size: 20
                        ),
                        const SizedBox(width: 10),
                        Text(value),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (newValue) {
                  setState(() => _selectedType = newValue!);
                },
              ),
              const SizedBox(height: 20),

              // --- TANGGAL MULAI ---
              const Text("Tanggal Mulai", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dateController,
                readOnly: true, // Tidak bisa ketik manual, harus lewat picker
                onTap: _pickDate,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_month),
                ),
              ),
              const SizedBox(height: 20),
              
              // --- DURASI (HANYA MUNCUL JIKA CUTI) ---
              if (_selectedType == 'Cuti') ...[
                const Text("Lama Cuti (Hari)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _durationController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    hintText: '1',
                    suffixText: 'Hari',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Wajib diisi';
                    if (int.tryParse(value) == null) return 'Harus angka';
                    return null;
                  },
                ),
                const SizedBox(height: 20),
              ],

              // --- KETERANGAN ---
              const Text("Keterangan / Alasan", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Contoh: Sakit demam, Acara keluarga, dll...',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Mohon isi alasan';
                  return null;
                },
              ),
              const SizedBox(height: 30),

              // --- TOMBOL KIRIM ---
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _submitPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : const Text("KIRIM PENGAJUAN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}