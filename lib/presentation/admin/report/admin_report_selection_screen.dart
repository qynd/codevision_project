import 'package:flutter/material.dart';
import '../../../core/constants/app_theme.dart';
import 'report_preview_screen.dart';

enum ReportType { project, task, attendance, incomingLetter, outgoingLetter }

class AdminReportSelectionScreen extends StatelessWidget {
  const AdminReportSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pilih Jenis Laporan"),
        backgroundColor: Colors.indigo.shade900,
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildOption(context, "Laporan Proyek", Icons.folder, Colors.blue, ReportType.project),
          _buildOption(context, "Laporan Tugas", Icons.task, Colors.orange, ReportType.task),
          _buildOption(context, "Laporan Absensi", Icons.people, Colors.green, ReportType.attendance),
          _buildOption(context, "Laporan Surat Masuk", Icons.mail_outline, Colors.purple, ReportType.incomingLetter),
          _buildOption(context, "Laporan Surat Keluar", Icons.send, Colors.red, ReportType.outgoingLetter),
        ],
      ),
    );
  }

  Widget _buildOption(BuildContext context, String title, IconData icon, Color color, ReportType type) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: color, size: 28),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               // Navigate to Preview Screen with selected Type
              builder: (context) => ReportPreviewScreen(reportType: type, title: title),
            ),
          );
        },
      ),
    );
  }
}
