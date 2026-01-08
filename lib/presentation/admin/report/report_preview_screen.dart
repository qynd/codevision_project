import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_theme.dart';
import '../../../core/services/pdf_service.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/letter_model.dart';
import 'admin_report_selection_screen.dart'; // For Enum

class ReportPreviewScreen extends StatefulWidget {
  final ReportType reportType;
  final String title;

  const ReportPreviewScreen({super.key, required this.reportType, required this.title});

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  final SupabaseClient supabase = Supabase.instance.client;
  final PdfService _pdfService = PdfService();

  // Filters
  DateTime? startDate;
  DateTime? endDate;
  String? selectedStatus;

  // Data
  List<dynamic> _data = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- DATA FETCHING ---
  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    
    try {
      dynamic query;
      
      // 1. Select Table based on Type
      switch (widget.reportType) {
        case ReportType.project:
          query = supabase.from('projects').select();
          break;
        case ReportType.task:
          query = supabase.from('tasks').select();
          break;
        case ReportType.attendance:
          // Join for user details
          query = supabase.from('attendances').select('*, users(nama, nip, jabatan)');
          break;
        case ReportType.incomingLetter:
          query = supabase.from('letters').select().eq('jenis_surat', 'Masuk');
          break;
        case ReportType.outgoingLetter:
          query = supabase.from('letters').select().eq('jenis_surat', 'Keluar');
          break;
      }

      // 2. Apply Filters
      if (startDate != null && endDate != null) {
        // Assuming 'created_at' or 'tanggal' exists. 
        // Adjust column name based on table schema!
        String dateColumn = 'created_at';
        if (widget.reportType == ReportType.attendance || widget.reportType == ReportType.incomingLetter || widget.reportType == ReportType.outgoingLetter) {
          dateColumn = 'tanggal'; // Check DB schema if needed
        }
        
        // Format to ISO string for Supabase
        query = query.gte(dateColumn, startDate!.toIso8601String()).lte(dateColumn, endDate!.add(const Duration(days: 1)).toIso8601String());
      }

      if (selectedStatus != null && selectedStatus != 'Semua') {
          query = query.eq('status', selectedStatus!);
      }

      // 3. Order & Limit (Safe Default)
      // query = query.order('created_at', ascending: false).limit(100); 
      // Removed order temporarily to avoid errors if column missing, just limit.
      
      final res = await query;
      
      setState(() {
        _data = res as List<dynamic>;
      });

    } catch (e) {
      debugPrint("Error fetching data: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // --- PDF GENERATION ---
  Future<void> _generatePdf() async {
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Tidak ada data untuk dicetak")));
      return;
    }

    // Show Loading
    showDialog(context: context, barrierDismissible: false, builder: (c) => const Center(child: CircularProgressIndicator()));

    try {
      String url = "";
      
      // Convert Map to Models and Generate
      switch (widget.reportType) {
        case ReportType.project:
          final list = _data.map((e) => ProjectModel.fromJson(e)).toList();
          url = await _pdfService.generateProjectReport(list);
          break;
        case ReportType.task:
          final list = _data.map((e) => TaskModel.fromJson(e)).toList();
          url = await _pdfService.generateTaskReport(list);
          break;
        case ReportType.attendance:
          final list = _data.map((e) => AttendanceModel.fromJson(e)).toList();
          url = await _pdfService.generateAttendanceReport(list);
          break;
        case ReportType.incomingLetter:
          final list = _data.map((e) => LetterModel.fromIncoming(e)).toList();
          url = await _pdfService.generateIncomingLetterReport(list);
          break;
        case ReportType.outgoingLetter:
          final list = _data.map((e) => LetterModel.fromOutgoing(e)).toList();
          url = await _pdfService.generateOutgoingLetterReport(list);
          break;
      }

      if (mounted) {
        Navigator.pop(context); // Pop Loading
        _showSuccessDialog(url);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Gagal membuat PDF: $e"), backgroundColor: Colors.red));
      }
    }
  }

  void _showSuccessDialog(String url) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text("Laporan Berhasil Dibuat"),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 16),
              const Text("File PDF telah berhasil di-generate dan di-upload."),
              const SizedBox(height: 8),
              SelectableText(url, style: const TextStyle(fontSize: 12, color: Colors.blue)),
            ],
          ),
          actions: [
             TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Link disalin!")));
              },
              child: const Text("Salin Link"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  // --- FILTERS UI ---
  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: startDate != null && endDate != null ? DateTimeRange(start: startDate!, end: endDate!) : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      _fetchData(); // Refresh Data
    }
  }

  // --- BUILD UI ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          // FILTER HEADER
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(startDate == null 
                          ? "Pilih Tanggal" 
                          : "${DateFormat('dd/MM/yy').format(startDate!)} - ${DateFormat('dd/MM/yy').format(endDate!)}"
                        ),
                        onPressed: _pickDateRange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    if (widget.reportType == ReportType.project || widget.reportType == ReportType.task)
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                            border: OutlineInputBorder(),
                            labelText: "Status",
                          ),
                          value: selectedStatus,
                          items: _getStatusOptions().map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (val) {
                            setState(() => selectedStatus = val);
                            _fetchData();
                          },
                        ),
                      ),
                  ],
                ),
                if (startDate != null)
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(onPressed: () {
                       setState(() {
                         startDate = null; endDate = null; selectedStatus = null;
                       });
                       _fetchData();
                     }, child: const Text("Reset Filter", style: TextStyle(color: Colors.red))),
                   )
              ],
            ),
          ),
          const Divider(height: 1),

          // LIST VIEW
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _data.isEmpty 
                ? const Center(child: Text("Tidak ada data ditemukan"))
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _data.length,
                    separatorBuilder: (c, i) => const Divider(),
                    itemBuilder: (context, index) {
                      final item = _data[index];
                      return _buildListItem(item);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _generatePdf,
        icon: const Icon(Icons.print),
        label: const Text("Cetak PDF"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
    );
  }

  List<String> _getStatusOptions() {
    if (widget.reportType == ReportType.project) {
      return ['Semua', 'New', 'In Progress', 'Completed'];
    } else if (widget.reportType == ReportType.task) {
      return ['Semua', 'To Do', 'In Progress', 'Waiting Approval', 'Completed'];
    }
    return ['Semua'];
  }

  Widget _buildListItem(Map<String, dynamic> item) {
    // Customize based on Type
    String title = "";
    String subtitle = "";
    String status = "";

    switch (widget.reportType) {
      case ReportType.project:
        title = item['nama_proyek'] ?? 'No Name';
        subtitle = "Deadline: ${item['due_date'] ?? '-'}";
        status = item['status'] ?? '-';
        break;
      case ReportType.task:
        title = item['judul'] ?? 'No Title';
        subtitle = "Progress: ${item['progress_percent'] ?? 0}%";
        status = item['status'] ?? '-';
        break;
      case ReportType.attendance:
        final user = item['users'] ?? {'nama': 'Unknown'};
        title = user['nama'] ?? 'Unknown';
        subtitle = "${DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal']))} | Masuk: ${item['check_in_time']}";
        status = item['status'] ?? '-';
        break;
      case ReportType.incomingLetter:
      case ReportType.outgoingLetter:
        title = item['perihal'] ?? 'No Subject';
        subtitle = "No: ${item['nomor_surat'] ?? '-'} | Tgl: ${item['tanggal_surat']}";
        status = widget.reportType == ReportType.incomingLetter ? "Masuk" : "Keluar";
        break;
    }

    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Chip(label: Text(status, style: const TextStyle(fontSize: 10))),
    );
  }
}
