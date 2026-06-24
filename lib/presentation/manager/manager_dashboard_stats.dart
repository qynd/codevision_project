import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/services/pdf_service.dart';
import 'manager_filtered_list_screen.dart';

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

  Map<String, int> employeeWorkload = {};
  List<Map<String, dynamic>> detailedWorkloadList = [];
  List<dynamic> usersList = [];

  DateTimeRange? _selectedDateRange;

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
        supabase.from('tasks').select('status, assigned_to, project_id, created_at'),
        supabase.from('users').select('id, nama, role'),
      ]);

      final projects = results[0] as List<dynamic>;
      final tasks = results[1] as List<dynamic>;
      final users = results[2] as List<dynamic>;

      if (mounted) {
        setState(() {
          totalProjects = projects.length;
          activeProjects = projects.where((p) => p['status'] != 'Completed').length;
          completedProjects = projects.where((p) => p['status'] == 'Completed').length;

          totalTasks = tasks.length;
          pendingTasks = tasks.where((t) => t['status'] == 'Waiting Approval').length;
          
          usersList = users;
          
          // Hitung workload per pegawai (tugas yang belum Done)
          employeeWorkload.clear();
          detailedWorkloadList.clear();
          for (var user in users) {
             final role = user['role']?.toString().toLowerCase().trim() ?? 'pegawai';
             if (role != 'admin' && role != 'manager' && role != 'manajer' && role != 'direktur' && role != 'hrd_ga') {
                 String nama = user['nama'] ?? 'Unknown';
                 employeeWorkload[nama] = 0;
                 detailedWorkloadList.add({
                    'id': user['id'],
                    'nama': nama,
                    'posisi': user['role'] ?? 'Pegawai',
                    'total_aktif': 0,
                    'tugas_selesai': 0,
                    'proyek_aktif': <String>{},
                 });
             }
          }
          
          for (var task in tasks) {
             // In-memory filter for workload chart
             if (_selectedDateRange != null) {
                 final taskDateStr = task['created_at'];
                 if (taskDateStr != null) {
                     final taskDate = DateTime.tryParse(taskDateStr.toString());
                     if (taskDate != null) {
                         final start = _selectedDateRange!.start;
                         final end = _selectedDateRange!.end.add(const Duration(hours: 23, minutes: 59, seconds: 59));
                         if (taskDate.isBefore(start) || taskDate.isAfter(end)) {
                             continue;
                         }
                     }
                 }
             }

             if (task['assigned_to'] != null) {
                 dynamic assignee;
                 try {
                     assignee = users.firstWhere((u) => u['id'] == task['assigned_to']);
                 } catch (_) {
                     assignee = null;
                 }
                 
                 if (assignee != null) {
                     String nama = assignee['nama'] ?? 'Unknown';
                     
                     // Hanya hitung chart workload untuk tugas yang belum selesai
                     if (task['status'] != 'Done') {
                         if (employeeWorkload.containsKey(nama)) {
                             employeeWorkload[nama] = (employeeWorkload[nama] ?? 0) + 1;
                         } else {
                             employeeWorkload[nama] = 1;
                         }
                     }
                     
                     // Update detail list
                     try {
                       var detail = detailedWorkloadList.firstWhere((e) => e['id'] == task['assigned_to']);
                       if (task['status'] != 'Done') {
                           detail['total_aktif'] = (detail['total_aktif'] as int) + 1;
                           if (task['project_id'] != null) {
                               (detail['proyek_aktif'] as Set<String>).add(task['project_id'].toString());
                           }
                       } else {
                           detail['tugas_selesai'] = (detail['tugas_selesai'] as int) + 1;
                       }
                     } catch (_) {}
                 }
             }
          }

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
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManagerFilteredListScreen(filterType: "Proyek Aktif"),
                          ),
                        );
                      },
                    ),
                    _buildMinimalCard(
                      "Proyek Selesai",
                      completedProjects.toString(),
                      Icons.check_circle_rounded,
                      Colors.green,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManagerFilteredListScreen(filterType: "Proyek Selesai"),
                          ),
                        );
                      },
                    ),
                    _buildMinimalCard(
                      "Tugas Menunggu",
                      pendingTasks.toString(),
                      Icons.assignment_late_rounded,
                      Colors.orange,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManagerFilteredListScreen(filterType: "Tugas Menunggu"),
                          ),
                        );
                      },
                    ),
                    _buildMinimalCard(
                      "Total Tugas",
                      totalTasks.toString(),
                      Icons.format_list_bulleted_rounded,
                      Colors.blueGrey,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ManagerFilteredListScreen(filterType: "Total Tugas"),
                          ),
                        );
                      },
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

                const SizedBox(height: 24),
                
                // --- GRAFIK BEBAN KERJA PEGAWAI ---
                _buildWorkloadChart(),

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

  Widget _buildWorkloadChart() {
    if (employeeWorkload.isEmpty) return const SizedBox();

    List<BarChartGroupData> barGroups = [];
    int index = 0;
    employeeWorkload.forEach((name, count) {
      barGroups.add(
        BarChartGroupData(
          x: index,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.orange,
              width: 16,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
      index++;
    });

    return Container(
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  "Beban Kerja Pegawai",
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.calendar_month, color: Colors.indigo),
                    tooltip: "Filter Tanggal",
                    onPressed: () async {
                      final picked = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        initialDateRange: _selectedDateRange,
                        builder: (context, child) {
                          return Theme(
                            data: Theme.of(context).copyWith(
                              colorScheme: const ColorScheme.light(
                                primary: Colors.indigo,
                                onPrimary: Colors.white,
                                onSurface: Colors.indigo,
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          _selectedDateRange = picked;
                          isLoading = true;
                        });
                        _fetchStats();
                      }
                    },
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _generateAndPrintPDF,
                    icon: const Icon(Icons.print, size: 16),
                    label: const Text("Cetak"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.indigo,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (_selectedDateRange != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  const Icon(Icons.filter_alt, color: Colors.grey, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    "${DateFormat('dd MMM yyyy').format(_selectedDateRange!.start)} - ${DateFormat('dd MMM yyyy').format(_selectedDateRange!.end)}",
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () {
                      setState(() {
                        _selectedDateRange = null;
                        isLoading = true;
                      });
                      _fetchStats();
                    },
                    child: const Text("Hapus Filter", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ),
          const SizedBox(height: 24),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: employeeWorkload.length * 60.0 > MediaQuery.of(context).size.width - 96 
                     ? employeeWorkload.length * 60.0 
                     : MediaQuery.of(context).size.width - 96,
              height: 200,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: 5, // Sesuai limit maksimal tugas
                  barTouchData: BarTouchData(enabled: true),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          if (value.toInt() >= 0 && value.toInt() < employeeWorkload.keys.length) {
                            String name = employeeWorkload.keys.elementAt(value.toInt());
                            // Shorten name if too long
                            if (name.length > 8) name = '${name.substring(0, 8)}..';
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: Text(name, style: const TextStyle(fontSize: 10)),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 28,
                        getTitlesWidget: (value, meta) {
                          return Text(value.toInt().toString(), style: const TextStyle(fontSize: 10));
                        },
                      ),
                    ),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: barGroups,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _generateAndPrintPDF() async {
    final pdfService = PdfService();
    final pdf = pw.Document();
    final logoImage = await pdfService.loadLogo();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        build: (pw.Context context) {
          return [
            pdfService.buildLetterhead(logoImage),
            pw.SizedBox(height: 20),
            pdfService.buildHeader("Laporan Beban Kerja Pegawai"),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              context: context,
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.blue800),
              rowDecoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey300))),
              headers: ['No', 'Nama Pegawai', 'Posisi', 'Proyek Aktif', 'Tugas Selesai', 'Total Tugas', 'Status Beban'],
              data: List<List<String>>.generate(
                detailedWorkloadList.length,
                (index) {
                  final data = detailedWorkloadList[index];
                  final int totalTugas = data['total_aktif'];
                  final int totalProyek = (data['proyek_aktif'] as Set<String>).length;
                  final int tugasSelesai = data['tugas_selesai'];
                  
                  String statusBeban = 'Aman';
                  if (totalTugas == 4) statusBeban = 'Penuh';
                  if (totalTugas >= 5) statusBeban = 'Maksimal';

                  return [
                    (index + 1).toString(),
                    data['nama'].toString(),
                    data['posisi'].toString(),
                    totalProyek.toString(),
                    tugasSelesai.toString(),
                    totalTugas.toString(),
                    statusBeban,
                  ];
                },
              ),
              cellAlignments: {
                0: pw.Alignment.center,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.center,
                4: pw.Alignment.center,
                5: pw.Alignment.center,
                6: pw.Alignment.center,
              },
            ),
            pdfService.buildSignature(),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
      name: 'Laporan_Beban_Kerja_Pegawai',
    );
  }
}
