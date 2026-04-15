import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ManagerDashboardStats extends StatefulWidget {
  const ManagerDashboardStats({super.key});

  @override
  State<ManagerDashboardStats> createState() => _ManagerDashboardStatsState();
}

class _ManagerDashboardStatsState extends State<ManagerDashboardStats> {
  final supabase = Supabase.instance.client;

  int totalProjects = 0;
  int activeProjects = 0;
  int completedProjects = 0;

  int totalTasks = 0;
  int pendingTasks = 0;

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Stack(
      children: [
        Container(
          color: Colors.grey.shade50,
        ),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 240,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.orange.shade700,
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
                      "Manager Dashboard",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
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
                      "Proyek Aktif",
                      activeProjects.toString(),
                      Icons.rocket_launch_rounded,
                      Colors.blue,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Proyek Selesai",
                      completedProjects.toString(),
                      Icons.check_circle_rounded,
                      Colors.green,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Tugas Menunggu",
                      pendingTasks.toString(),
                      Icons.assignment_late_rounded,
                      Colors.orange,
                      () {},
                    ),
                    _buildMinimalCard(
                      "Total Tugas",
                      totalTasks.toString(),
                      Icons.format_list_bulleted_rounded,
                      Colors.blueGrey,
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
                        "Statistik Proyek",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                      ),
                      const SizedBox(height: 24),
                      totalProjects == 0
                          ? const SizedBox(
                              height: 150,
                              child: Center(
                                child: Text("Belum ada data proyek", style: TextStyle(color: Colors.grey)),
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
                                            value: activeProjects.toDouble(),
                                            title: '$activeProjects',
                                            radius: 50,
                                            titleStyle: const TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                          PieChartSectionData(
                                            color: Colors.indigo.shade200,
                                            value: completedProjects.toDouble(),
                                            title: '$completedProjects',
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
                                      _buildChartLegend("In Progress", Colors.indigo.shade400),
                                      const SizedBox(height: 16),
                                      _buildChartLegend("Completed", Colors.indigo.shade200),
                                    ],
                                  ),
                                ],
                              ),
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
}
