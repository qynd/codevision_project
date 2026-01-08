import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_theme.dart';
import '../attendance/admin_attendance_screen.dart'; 
import 'tasks/admin_approval_screen.dart'; 
// import '../report/report_selection_sheet.dart'; // Deleted by user
import 'report/admin_report_selection_screen.dart'; // We will create this
 

class AdminDashboardStats extends StatefulWidget {
  const AdminDashboardStats({super.key});

  @override
  State<AdminDashboardStats> createState() => _AdminDashboardStatsState();
}

class _AdminDashboardStatsState extends State<AdminDashboardStats> {
  final supabase = Supabase.instance.client;

  // Stat Variables
  int totalProjects = 0;
  int activeProjects = 0;
  int completedProjects = 0;
  
  int totalTasks = 0;
  int pendingTasks = 0;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      // Run queries in parallel to reduce loading time
      final results = await Future.wait([
        supabase.from('projects').select('status'),
        supabase.from('tasks').select('status'),
      ]);

      final projects = results[0] as List<dynamic>;
      final tasks = results[1] as List<dynamic>;

      if (mounted) {
        setState(() {
          totalProjects = projects.length;
          activeProjects = projects.where((p) => p['status'] != 'Completed').length;
          completedProjects = projects.where((p) => p['status'] == 'Completed').length;
          
          totalTasks = tasks.length;
          pendingTasks = tasks.where((t) => t['status'] == 'Waiting Approval').length;
        });
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
    }
  }

  // --- REPORT GENERATION PREVIEW ---
  void _navigateToReportPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AdminReportSelectionScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // --- SILUET LOGO BACKGROUND ---
        Positioned(
          top: -20,
          right: -20,
          child: Opacity(
            opacity: 0.05, 
            child: Image.asset('assets/images/logo.png', width: 250, color: CodevisionTheme.primaryColor),
          ),
        ),

        SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // HEADER LOGO ADMIN
              Row(
                children: [
                   Image.asset('assets/images/logo.png', height: 40),
                   const SizedBox(width: 12),
                   const Text(
                     "Admin Dashboard", 
                     style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: CodevisionTheme.primaryColor)
                   ),
                ],
              ),
              const SizedBox(height: 24),

              // 1. HEADER CARD (Ringkasan)
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      "Proyek Aktif", 
                      activeProjects.toString(), 
                      Icons.folder_open, 
                      Colors.blue
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const AdminApprovalScreen()),
                        ).then((_) => _fetchStats()); 
                      },
                      child: _buildSummaryCard(
                        "Menunggu Approval", 
                        pendingTasks.toString(), 
                        Icons.notifications_active, 
                        Colors.orange
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. DIAGRAM PIE CHART
              const Text("Statistik Proyek", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              AspectRatio(
                aspectRatio: 1.5,
                child: Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  surfaceTintColor: Colors.white,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: totalProjects == 0 
                      ? const Center(child: Text("Belum ada data proyek"))
                      : Row(
                        children: [
                          Expanded(
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 40,
                                sections: [
                                  PieChartSectionData(
                                    color: Colors.blue,
                                    value: activeProjects.toDouble(),
                                    title: '$activeProjects',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                  PieChartSectionData(
                                    color: Colors.green,
                                    value: completedProjects.toDouble(),
                                    title: '$completedProjects',
                                    radius: 50,
                                    titleStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                CircleAvatar(radius: 6, backgroundColor: Colors.blue),
                                SizedBox(width: 8),
                                Text("In Progress"),
                              ]),
                              SizedBox(height: 8),
                              Row(children: [
                                CircleAvatar(radius: 6, backgroundColor: Colors.green),
                                SizedBox(width: 8),
                                Text("Completed"),
                              ]),
                            ],
                          )
                        ],
                      ),
                  ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // 3. MENU SHORTCUT
              const Text("Menu Cepat", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              ListView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: CodevisionTheme.accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.calendar_month, color: CodevisionTheme.accentColor),
                    ),
                    title: const Text("Monitoring Absensi"),
                    subtitle: const Text("Cek kehadiran pegawai hari ini"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (c) => const AdminAttendanceScreen()));
                    },
                  ),
                  const Divider(),
                  ListTile(
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.purple.shade100, borderRadius: BorderRadius.circular(8)),
                      child: const Icon(Icons.print, color: Colors.purple),
                    ),
                    title: const Text("Cetak Laporan"),
                    subtitle: const Text("Export data ke PDF/Excel"),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                       _navigateToReportPreview();
                    },
                  ),
                ],
              )
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withOpacity(0.4), blurRadius: 8, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: Colors.white70, size: 24),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
        ],
      ),
    );
  }
}
