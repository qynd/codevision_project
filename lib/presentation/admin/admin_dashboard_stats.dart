import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../attendance/admin_attendance_screen.dart';
import 'report/admin_report_selection_screen.dart';

class AdminDashboardStats extends StatefulWidget {
  const AdminDashboardStats({super.key});

  @override
  State<AdminDashboardStats> createState() => _AdminDashboardStatsState();
}

class _AdminDashboardStatsState extends State<AdminDashboardStats> {
  final supabase = Supabase.instance.client;

  // Stat Variables
  int totalIncoming = 0;
  int pendingIncoming = 0;

  int totalOutgoing = 0;
  
  int totalEmployees = 0;
  int todayAttendances = 0;
  
  int pendingPermissions = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];
      
      // Run queries in parallel
      final results = await Future.wait<dynamic>([
        supabase.from('incoming_letters').select('status'),
        supabase.from('outgoing_letters').select('id'),
        supabase.from('users').select('id'),
        supabase.from('attendances').select('id').eq('tanggal', today),
        supabase.from('letters').select('status').eq('status', 'Pending'), // Izin Menunggu
      ]);

      final incoming = results[0] as List<dynamic>;
      final outgoing = results[1] as List<dynamic>;
      final users = results[2] as List<dynamic>;
      final attendances = results[3] as List<dynamic>;
      final permissions = results[4] as List<dynamic>;

      if (mounted) {
        setState(() {
          totalIncoming = incoming.length;
          pendingIncoming = incoming.where((p) => p['status'] == 'Pending').length;

          totalOutgoing = outgoing.length;
          
          totalEmployees = users.length;
          todayAttendances = attendances.length;
          pendingPermissions = permissions.length;
          
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  void _navigateToReportPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AdminReportSelectionScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Container(
          color: Colors.grey.shade50, // Minimalist neutral background
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.indigo.shade600,
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
          ),
        ),
        
        RefreshIndicator(
          onRefresh: _fetchStats,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Selamat Datang,",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white70,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          "HRD/GA Dashboard",
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    InkWell(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (c) => const AdminReportSelectionScreen(),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.03),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Icon(Icons.print_rounded, color: Colors.indigo.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                const Text(
                  "Ringkasan Operasional",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.05,
                  children: [
                    _buildMinimalCard(
                      "Pegawai Hadir",
                      todayAttendances.toString(),
                      Icons.fingerprint_rounded,
                      Colors.blue,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Izin Menunggu",
                      pendingPermissions.toString(),
                      Icons.assignment_late_rounded,
                      Colors.orange,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Surat Masuk",
                      totalIncoming.toString(),
                      Icons.move_to_inbox_rounded,
                      Colors.teal,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Surat Keluar",
                      totalOutgoing.toString(),
                      Icons.outbox_rounded,
                      Colors.green,
                      () {},
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Statistik Surat",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      (totalIncoming == 0 && totalOutgoing == 0)
                          ? const SizedBox(
                              height: 150,
                              child: Center(
                                child: Text("Belum ada data surat", style: TextStyle(color: Colors.grey)),
                              ),
                            )
                          : AspectRatio(
                              aspectRatio: 1.5,
                              child: Row(
                                children: [
                                  Expanded(
                                    child: PieChart(
                                      PieChartData(
                                        sectionsSpace: 4,
                                        centerSpaceRadius: 30,
                                        sections: [
                                          PieChartSectionData(
                                            color: Colors.indigo.shade400,
                                            value: totalIncoming.toDouble(),
                                            title: '$totalIncoming',
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            color: Colors.indigo.shade200,
                                            value: totalOutgoing.toDouble(),
                                            title: '$totalOutgoing',
                                            radius: 40,
                                            titleStyle: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.indigo,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _buildChartLegend("Surat Masuk", Colors.indigo.shade400),
                                      const SizedBox(height: 16),
                                      _buildChartLegend("Surat Keluar", Colors.indigo.shade200),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                const SizedBox(height: 32),

                // QUICK MENU SECTION
                const Text(
                  "Akses Cepat",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildQuickMenuTile(
                        title: "Monitoring Absensi",
                        subtitle: "Cek rekapitulasi kehadiran pegawai",
                        icon: Icons.fingerprint_rounded,
                        iconColor: Colors.blue,
                        bgColor: Colors.blue.shade50,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (c) => const AdminAttendanceScreen(),
                            ),
                          );
                        },
                      ),
                      Divider(height: 1, color: Colors.grey.shade200, indent: 70, endIndent: 20),
                      _buildQuickMenuTile(
                        title: "Cetak Laporan",
                        subtitle: "Export data operasional ke dokumen",
                        icon: Icons.print_rounded,
                        iconColor: Colors.purple,
                        bgColor: Colors.purple.shade50,
                        onTap: _navigateToReportPreview,
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMinimalCard(
    String title,
    String value,
    IconData icon,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: accentColor, size: 28),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                ),
              ],
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartLegend(String label, Color color) {
    return Row(
      children: [
        CircleAvatar(radius: 6, backgroundColor: color),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildQuickMenuTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
      ),
      trailing: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.black54),
      ),
      onTap: onTap,
    );
  }
}
