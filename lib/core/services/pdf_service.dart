import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:supabase_flutter/supabase_flutter.dart';
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
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
          ),
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          _buildHeader("Laporan Tugas (Task)"),
          pw.SizedBox(height: 20),
          pw.TableHelper.fromTextArray(
            headers: ['Judul', 'Status', 'Progress', 'Assigned To', 'Deskripsi'],
            data: data.map((item) => [
              item.judul,
              item.status,
              '${item.progress}%',
              item.assignedTo ?? '-',
              item.deskripsi,
            ]).toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
            rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
          ),
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
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

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
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
        pw.Text(
          "CODEVISION APP",
          style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.grey),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          title,
          style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
        ),
        pw.SizedBox(height: 8),
        pw.Text(
          "Generated at: ${DateFormat('dd MMMM yyyy, HH:mm').format(DateTime.now())}",
          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
        ),
        pw.Divider(thickness: 1),
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
