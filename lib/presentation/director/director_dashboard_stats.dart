import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../admin/report/admin_report_selection_screen.dart';

class DirectorDashboardStats extends StatefulWidget {
  const DirectorDashboardStats({super.key});

  @override
  State<DirectorDashboardStats> createState() => _DirectorDashboardStatsState();
}

class _DirectorDashboardStatsState extends State<DirectorDashboardStats> {
  final supabase = Supabase.instance.client;

  int totalProjects = 0;
  int activeProjects = 0;
  int completedProjects = 0;

  int totalEmployees = 0;
  int todayAttendances = 0;
  
  double totalExpenses = 0.0;

  // Chart Variables
  List<double> dailyExpenses = List.generate(31, (index) => 0.0);
  double maxExpense = 100000;
  int daysCount = 31;
  String errorMessage = "";

  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final String today = DateTime.now().toIso8601String().split('T')[0];

      final results = await Future.wait<dynamic>([
        supabase.from('projects').select('status'),
        supabase.from('users').select('id'),
        supabase.from('attendances').select('id').eq('tanggal', today),
        supabase.from('operational_expenses').select('jumlah_dana, tanggal_pengajuan').eq('status', 'Approved'),
      ]);

      final projects = results[0] as List<dynamic>;
      final users = results[1] as List<dynamic>;
      final attendances = results[2] as List<dynamic>;
      final expenses = results[3] as List<dynamic>;

      double sumExpense = 0;
      final now = DateTime.now();
      int currentDaysInMonth = DateUtils.getDaysInMonth(now.year, now.month);

      List<double> tempExpenses = List.generate(currentDaysInMonth, (index) => 0.0);
      double tempMax = 0.0;

      for (var exp in expenses) {
        sumExpense += (exp['jumlah_dana'] as num?)?.toDouble() ?? 0.0;
        
        final dateStr = exp['tanggal_pengajuan'];
        final amount = (exp['jumlah_dana'] as num?)?.toDouble() ?? 0.0;
        if (dateStr != null) {
          final date = DateTime.tryParse(dateStr);
          if (date != null && date.year == now.year && date.month == now.month) {
             tempExpenses[date.day - 1] += amount;
          }
        }
      }

      for (var val in tempExpenses) {
        if (val > tempMax) tempMax = val;
      }
      if (tempMax == 0) tempMax = 1000000;

      if (mounted) {
        setState(() {
          totalProjects = projects.length;
          activeProjects = projects.where((p) => p['status'] != 'Completed').length;
          completedProjects = projects.where((p) => p['status'] == 'Completed').length;

          totalEmployees = users.length;
          todayAttendances = attendances.length;
          
          totalExpenses = sumExpense;
          dailyExpenses = tempExpenses;
          maxExpense = tempMax;
          daysCount = currentDaysInMonth;
          
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching director stats: $e");
      if (mounted) {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            "Terjadi Kesalahan:\n$errorMessage",
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          ),
        ),
      );
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
          height: 250,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.deepPurple.shade800,
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
                      "Executive Overview,",
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      "Director Dashboard",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                // BIG FINANCIAL CARD
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.deepPurple.shade900, Colors.purple.shade800],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.deepPurple.withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.account_balance_wallet_rounded, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            "Total Pengeluaran Operasional",
                            style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _formatCurrency(totalExpenses),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Dana Operasional Approved",
                        style: TextStyle(color: Colors.purple.shade200, fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // BAR CHART BEGIN
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Detail Pengeluaran Harian",
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                          ),
                          Text(
                            DateFormat('MMMM yyyy', 'id_ID').format(DateTime.now()),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.deepPurple),
                          ),
                        ],
                      ),
                      const SizedBox(height: 38),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: SizedBox(
                          width: daysCount * 35.0,
                          height: 200,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: maxExpense + (maxExpense * 0.25),
                              barTouchData: BarTouchData(
                                enabled: true,
                                touchTooltipData: BarTouchTooltipData(
                                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                                    return BarTooltipItem(
                                      _formatCurrency(rod.toY),
                                      const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 10),
                                    );
                                  },
                                ),
                              ),
                              titlesData: FlTitlesData(
                                show: true,
                                topTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 22,
                                    getTitlesWidget: (value, meta) {
                                      if (value.toInt() < 0 || value.toInt() >= daysCount) return const SizedBox.shrink();
                                      final val = dailyExpenses[value.toInt()];
                                      if (val <= 0) return const SizedBox.shrink();
                                      
                                      String text = '';
                                      if (val >= 1000000) {
                                        text = '${(val / 1000000).toStringAsFixed(1)}M';
                                      } else if (val >= 1000) {
                                        text = '${(val / 1000).toStringAsFixed(0)}k';
                                      } else {
                                        text = val.toStringAsFixed(0);
                                      }
                                      return Padding(
                                        padding: const EdgeInsets.only(bottom: 4.0),
                                        child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.deepPurple.shade700)),
                                      );
                                    },
                                  ),
                                ),
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (value, meta) {
                                      return Padding(
                                        padding: const EdgeInsets.only(top: 8.0),
                                        child: Text('${value.toInt() + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                      );
                                    },
                                  ),
                                ),
                                leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: List.generate(daysCount, (i) {
                                return BarChartGroupData(
                                  x: i,
                                  barRods: [
                                    BarChartRodData(
                                      toY: dailyExpenses[i],
                                      color: Colors.deepPurple.shade500,
                                      width: 16,
                                      borderRadius: BorderRadius.circular(4),
                                      backDrawRodData: BackgroundBarChartRodData(
                                        show: true,
                                        toY: maxExpense + (maxExpense * 0.25),
                                        color: Colors.deepPurple.shade50,
                                      ),
                                    ),
                                  ],
                                );
                              }),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // BAR CHART END

                const Text(
                  "Kinerja Organisasi",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                
                GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.1,
                  children: [
                    _buildMinimalCard(
                      "Proyek Berjalan",
                      activeProjects.toString(),
                      Icons.rocket_launch_rounded,
                      Colors.blue,
                    ),
                    _buildMinimalCard(
                      "Proyek Selesai",
                      completedProjects.toString(),
                      Icons.check_circle_rounded,
                      Colors.green,
                    ),
                    _buildMinimalCard(
                      "Total Pegawai",
                      totalEmployees.toString(),
                      Icons.people_alt_rounded,
                      Colors.teal,
                    ),
                    _buildMinimalCard(
                      "Pegawai Hadir",
                      todayAttendances.toString(),
                      Icons.fingerprint_rounded,
                      Colors.indigo,
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
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    leading: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.pink.shade50,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(Icons.analytics_rounded, color: Colors.pink.shade400),
                    ),
                    title: const Text(
                      "Pusat Laporan",
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    subtitle: Text(
                      "Lihat dan cetak seluruh data",
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
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (c) => const AdminReportSelectionScreen(),
                        ),
                      );
                    },
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
  ) {
    return Container(
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
    );
  }
}
