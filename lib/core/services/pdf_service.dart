import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';

import '../../data/models/project_model.dart';
import '../../data/models/task_model.dart';
import '../../data/models/attendance_model.dart';
import '../../data/models/letter_model.dart';

class PdfService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final String _bucketName = 'general_bucket'; // Single bucket strategy

  // ===========================================================================
  // 1. PUBLIC METHODS (Generate Reports)
  // ===========================================================================

  /// Laporan Project: Detail project, status, timeline
  Future<String> generateProjectReport(List<ProjectModel> data) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildLetterhead(logoImage),
          pw.SizedBox(height: 20),
          _buildHeader("Laporan Proyek"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Nama Proyek', 'Status', 'Mulai', 'Selesai', 'Deskripsi'],
            data: data.map((item) => [
              item.namaProyek,
              item.status,
              item.startDate,
              item.dueDate,
              item.deskripsi,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellAlignment: pw.Alignment.centerLeft,
            cellAlignments: {0: pw.Alignment.centerLeft, 4: pw.Alignment.centerLeft},
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Nama Proyek
              1: const pw.FlexColumnWidth(1.5), // Status
              2: const pw.FlexColumnWidth(1.5), // Mulai
              3: const pw.FlexColumnWidth(1.5), // Selesai
              4: const pw.FlexColumnWidth(3), // Deskripsi
            },
          ),
          _buildSignature(),
        ],
      ),
    );

    // FIX: Generate bytes first
    final bytes = await pdf.save();
    
    // Format: report/proyek/Laporan_Proyek_07-Jan-2026_14-30.pdf
    final fileName = 'report/proyek/Laporan_Proyek_${_getReadableTimestamp()}.pdf';
    return await _uploadToSupabase(fileName, bytes);
  }

  /// Laporan Task: List task & penanggung jawab
  Future<String> generateTaskReport(List<TaskModel> data) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildLetterhead(logoImage),
          pw.SizedBox(height: 20),
          _buildHeader("Laporan Tugas (Task)"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Judul', 'Status', 'Progress', 'Assigned To', 'Deskripsi'],
            data: data.map((item) => [
              item.judul,
              item.status,
              '${item.progress}%',
              item.assignedToName ?? item.assignedTo ?? '-', // Tampilkan Nama jika ada
              item.deskripsi,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: {
              0: const pw.FlexColumnWidth(2), // Judul (lebar)
              1: const pw.FlexColumnWidth(1), // Status
              2: const pw.FlexColumnWidth(1.5), // Progress
              3: const pw.FlexColumnWidth(2), // Assigned To (Nama)
              4: const pw.FlexColumnWidth(3), // Deskripsi (paling lebar)
            },
          ),
          _buildSignature(),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'report/tugas/Laporan_Tugas_${_getReadableTimestamp()}.pdf';
    return await _uploadToSupabase(fileName, bytes);
  }

  /// Laporan Absensi: Log kehadiran (Masuk, Pulang, Status)
  Future<String> generateAttendanceReport(List<AttendanceModel> data) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildLetterhead(logoImage),
          pw.SizedBox(height: 20),
          _buildHeader("Laporan Absensi Karyawan"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Nama', 'Jabatan', 'Tanggal', 'Masuk', 'Pulang', 'Status'],
            data: data.map((item) => [
              item.namaPegawai,
              item.jabatan,
              item.tanggal,
              item.checkInTime,
              item.checkOutTime,
              item.status,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
          _buildSignature(),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'report/absensi/Laporan_Absensi_${_getReadableTimestamp()}.pdf';
    return await _uploadToSupabase(fileName, bytes);
  }

  /// Laporan Surat Masuk
  Future<String> generateIncomingLetterReport(List<LetterModel> data) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildLetterhead(logoImage),
          pw.SizedBox(height: 20),
          _buildHeader("Laporan Surat Masuk"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['No. Surat', 'Pengirim', 'Perihal', 'Tanggal'],
            data: data.where((e) => e.jenis == 'Masuk').map((item) => [
              item.nomorSurat,
              item.pihakTerkait,
              item.perihal,
              item.tanggalSurat,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.green),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
          _buildSignature(),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'report/surat/masuk/Laporan_Surat_Masuk_${_getReadableTimestamp()}.pdf';
    return await _uploadToSupabase(fileName, bytes);
  }

  /// Laporan Surat Keluar
  Future<String> generateOutgoingLetterReport(List<LetterModel> data) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildLetterhead(logoImage),
          pw.SizedBox(height: 20),
          _buildHeader("Laporan Surat Keluar"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['No. Surat', 'Tujuan', 'Perihal', 'Tanggal'],
            data: data.where((e) => e.jenis == 'Keluar').map((item) => [
              item.nomorSurat,
              item.pihakTerkait,
              item.perihal,
              item.tanggalSurat,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.purple),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
          _buildSignature(),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'report/surat/keluar/Laporan_Surat_Keluar_${_getReadableTimestamp()}.pdf';
    return await _uploadToSupabase(fileName, bytes);
  }

  // ===========================================================================
  // 2. PRIVATE HELPERS
  // ===========================================================================

  /// Header Template for consistency
  pw.Widget _buildHeader(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Copied previous simple header style (optional if letterhead is enough, 
        // but kept as title of the specific report)
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          "Generated at: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}",
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 0.5),
      ],
    );
  }

  // ===========================================================================
  // 3. LETTERHEAD & SIGNATURE
  // ===========================================================================

  Future<pw.MemoryImage?> _loadLogo() async {
    try {
      final imageBytes = await rootBundle.load('assets/images/logo.png');
      return pw.MemoryImage(imageBytes.buffer.asUint8List());
    } catch (e) {
      // Return null if logo fails to load to prevent crash
      return null;
    }
  }

  pw.Widget _buildLetterhead(pw.MemoryImage? logoImage) {
    return pw.Column(
      children: [
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          mainAxisAlignment: pw.MainAxisAlignment.start, // Changed to start
          children: [
            // Logo - Moved to Left
            if (logoImage != null)
              pw.Container(
                width: 80,
                height: 80,
                margin: const pw.EdgeInsets.only(right: 60), // Add spacing
                child: pw.Image(logoImage),
              ),

            // Company Details
            pw.Flexible(
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center, // Centered Text
                children: [
                  pw.Text(
                    "CV. MAHKOTA BARITO",
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "Jl. Temanggung Silam RT 002/RW 004 NO 29",
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    "Puruk Cahu, Kec. Murung, Kabupaten Murung Raya",
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Text(
                    "Kalimantan Tengah 73911",
                    style: const pw.TextStyle(fontSize: 10),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    "CODEVISION",
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                ],
              ),
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Divider(thickness: 2, color: PdfColors.black),
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildSignature() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 50), // Spacer from table
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.end, // Align right
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Text(
                  "Puruk Cahu, ${DateFormat('d MMMM yyyy', 'id_ID').format(DateTime.now())}",
                  style: const pw.TextStyle(fontSize: 12),
                ),
                pw.SizedBox(height: 4),
                pw.Text("Hormat Kami,", style: const pw.TextStyle(fontSize: 12)),
                pw.SizedBox(height: 60), // Space for signature
                pw.Text(
                  "(__________________________)",
                  style: const pw.TextStyle(fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// Upload byte data to Supabase Storage and return Public URL
  Future<String> _uploadToSupabase(String filePath, Uint8List bytes) async {
    try {
      // Upload binary file
      await _supabase.storage.from(_bucketName).uploadBinary(
        filePath,
        bytes,
        fileOptions: const FileOptions(contentType: 'application/pdf', upsert: true),
      );

      // Get Public URL
      final String publicUrl = _supabase.storage.from(_bucketName).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      throw Exception('Gagal upload PDF ke Supabase: $e');
    }
  }

  String _getReadableTimestamp() {
    // Format: 07-Jan-2026_14-30 (Lebih mudah dibaca dibanding 20260107_143000)
    return DateFormat('dd-MMM-yyyy_HH-mm').format(DateTime.now());
  }
}
