import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/services/pdf_service.dart';
import '../../../data/models/project_model.dart';
import '../../../data/models/task_model.dart';
import '../../../data/models/attendance_model.dart';
import '../../../data/models/letter_model.dart';
import '../../../data/models/expense_model.dart';
import '../../../data/models/performance_model.dart';
import '../../../data/models/leave_model.dart';
import 'admin_report_selection_screen.dart'; // For Enum

class ReportPreviewScreen extends StatefulWidget {
  final ReportType reportType;
  final String title;

  const ReportPreviewScreen({
    super.key,
    required this.reportType,
    required this.title,
  });

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

  // Filters for Performance
  int? startMonth = DateTime.now().month;
  int? endMonth = DateTime.now().month;
  int? selectedYear = DateTime.now().year;
  final List<String> _monthNames = [
    '',
    'Januari',
    'Februari',
    'Maret',
    'April',
    'Mei',
    'Juni',
    'Juli',
    'Agustus',
    'September',
    'Oktober',
    'November',
    'Desember',
  ];

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
      await _fetchStandardData();
    } catch (e) {
      debugPrint("Error fetching data: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStandardData() async {
    dynamic query;

    // 1. Select Table based on Type
    switch (widget.reportType) {
      case ReportType.project:
        query = supabase.from('projects').select();
        break;
      case ReportType.task:
        query = supabase
            .from('tasks')
            .select('*, users:users!tasks_assigned_to_fkey(nama)');
        break;
      case ReportType.attendance:
        query = supabase
            .from('attendances')
            .select('*, users(nama, nip, jabatan)');
        break;
      case ReportType.leave:
        query = supabase
            .from('letters')
            .select('*, users!letters_user_id_fkey(nama, nip, jabatan)')
            .inFilter('jenis_surat', ['Izin', 'Sakit', 'Cuti']);
        break;
      case ReportType.incomingLetter:
        query = supabase.from('incoming_letters').select();
        break;
      case ReportType.outgoingLetter:
        query = supabase.from('outgoing_letters').select();
        break;
      case ReportType.operationalExpense:
        query = supabase
            .from('operational_expenses')
            .select(
              '*, users!fk_expense_user(nama), projects(nama_proyek), approver:approver_id(nama)',
            );
        break;
      case ReportType.performance:
        query = supabase
            .from('employee_performances')
            .select('*, users!fk_performance_user(nama)');
        break;
    }

    // 2. Apply Filters
    if (widget.reportType == ReportType.performance) {
      if (startMonth != null && endMonth != null) {
        query = query.gte('bulan', startMonth!).lte('bulan', endMonth!);
      }
      if (selectedYear != null) {
        query = query.eq('tahun', selectedYear!);
      }
      query = query.order('total_poin', ascending: false);
    } else {
      if (startDate != null && endDate != null) {
        String dateColumn = 'created_at';
        if (widget.reportType == ReportType.incomingLetter ||
            widget.reportType == ReportType.outgoingLetter) {
          dateColumn = 'tanggal_surat';
        } else if (widget.reportType == ReportType.operationalExpense) {
          dateColumn = 'tanggal_pengajuan';
        } else if (widget.reportType == ReportType.attendance) {
          dateColumn = 'tanggal';
        } else if (widget.reportType == ReportType.leave) {
          dateColumn = 'tanggal_mulai';
        }
        query = query
            .gte(dateColumn, startDate!.toIso8601String())
            .lte(
              dateColumn,
              endDate!.add(const Duration(days: 1)).toIso8601String(),
            );
      }

      if (selectedStatus != null && selectedStatus != 'Semua') {
        if (widget.reportType == ReportType.leave) {
          query = query.eq('jenis_surat', selectedStatus!);
        } else {
          query = query.eq('status', selectedStatus!);
        }
      }
    }

    final res = await query;
    if (widget.reportType == ReportType.performance) {
      // Aggregate specific for Performance timeframe ranges
      final Map<String, Map<String, dynamic>> aggregatedMap = {};
      for (var row in (res as List<dynamic>)) {
        final userId = row['user_id'];
        if (!aggregatedMap.containsKey(userId)) {
          aggregatedMap[userId] = Map<String, dynamic>.from(row);
        } else {
          aggregatedMap[userId]!['poin_absen'] =
              (aggregatedMap[userId]!['poin_absen'] ?? 0) +
              (row['poin_absen'] ?? 0);
          aggregatedMap[userId]!['poin_tugas'] =
              (aggregatedMap[userId]!['poin_tugas'] ?? 0) +
              (row['poin_tugas'] ?? 0);
          aggregatedMap[userId]!['total_poin'] =
              (aggregatedMap[userId]!['total_poin'] ?? 0) +
              (row['total_poin'] ?? 0);
        }
      }

      final aggregatedList = aggregatedMap.values.toList();
      aggregatedList.sort(
        (a, b) => (b['total_poin'] as int).compareTo(a['total_poin'] as int),
      );

      setState(() {
        _data = aggregatedList;
      });
    } else {
      setState(() {
        _data = res as List<dynamic>;
      });
    }
  }

  // --- PDF GENERATION ---
  Future<void> _generatePdf() async {
    if (_data.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Tidak ada data untuk dicetak")),
      );
      return;
    }

    // Show Loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

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
        case ReportType.leave:
          final list = _data.map((e) => LeaveModel.fromJson(e)).toList();
          url = await _pdfService.generateLeaveReport(list);
          break;
        case ReportType.incomingLetter:
          final list = _data.map((e) => LetterModel.fromIncoming(e)).toList();
          url = await _pdfService.generateIncomingLetterReport(list);
          break;
        case ReportType.outgoingLetter:
          final list = _data.map((e) => LetterModel.fromOutgoing(e)).toList();
          url = await _pdfService.generateOutgoingLetterReport(list);
          break;
        case ReportType.operationalExpense:
          final list = _data.map((e) => ExpenseModel.fromJson(e)).toList();
          url = await _pdfService.generateExpenseReport(list);
          break;
        case ReportType.performance:
          final list = _data.map((e) => PerformanceModel.fromJson(e)).toList();
          String periodeTitle = startMonth == endMonth
              ? "${_monthNames[startMonth!]} $selectedYear"
              : "${_monthNames[startMonth!]} - ${_monthNames[endMonth!]} $selectedYear";
          url = await _pdfService.generatePerformanceReport(list, periodeTitle);
          break;
      }

      if (mounted) {
        Navigator.pop(context); // Pop Loading
        _showSuccessDialog(url);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal membuat PDF: $e"),
            backgroundColor: Colors.red,
          ),
        );
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
              SelectableText(
                url,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text("Link disalin!")));
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
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
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
                    if (widget.reportType == ReportType.performance) ...[
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                            labelText: "Mulai",
                          ),
                          initialValue: startMonth,
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(
                                _monthNames[index + 1],
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => startMonth = val);
                            _fetchData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                            labelText: "Sampai",
                          ),
                          initialValue: endMonth,
                          items: List.generate(
                            12,
                            (index) => DropdownMenuItem(
                              value: index + 1,
                              child: Text(
                                _monthNames[index + 1],
                                style: const TextStyle(fontSize: 12),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          onChanged: (val) {
                            setState(() => endMonth = val);
                            _fetchData();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          decoration: const InputDecoration(
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(),
                            labelText: "Tahun",
                          ),
                          initialValue: selectedYear,
                          items:
                              [
                                    DateTime.now().year - 1,
                                    DateTime.now().year,
                                    DateTime.now().year + 1,
                                  ]
                                  .map(
                                    (year) => DropdownMenuItem(
                                      value: year,
                                      child: Text(
                                        year.toString(),
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (val) {
                            setState(() => selectedYear = val);
                            _fetchData();
                          },
                        ),
                      ),
                    ] else ...[
                      Expanded(
                        child: OutlinedButton.icon(
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            startDate == null
                                ? "Pilih Tanggal"
                                : "${DateFormat('dd/MM/yy').format(startDate!)} - ${DateFormat('dd/MM/yy').format(endDate!)}",
                          ),
                          onPressed: _pickDateRange,
                        ),
                      ),
                      const SizedBox(width: 12),
                      if (widget.reportType == ReportType.project ||
                          widget.reportType == ReportType.task ||
                          widget.reportType == ReportType.attendance ||
                          widget.reportType == ReportType.leave ||
                          widget.reportType == ReportType.operationalExpense)
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 0,
                              ),
                              border: OutlineInputBorder(),
                              labelText: "Status",
                            ),
                            key: ValueKey(selectedStatus),
                            initialValue: selectedStatus,
                            items: _getStatusOptions()
                                .map(
                                  (e) => DropdownMenuItem(
                                    value: e,
                                    child: Text(e),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) {
                              setState(() => selectedStatus = val);
                              _fetchData();
                            },
                          ),
                        ),
                    ],
                  ],
                ),
                if (startDate != null ||
                    widget.reportType == ReportType.performance)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        setState(() {
                          startDate = null;
                          endDate = null;
                          selectedStatus = null;
                          if (widget.reportType == ReportType.performance) {
                            startMonth = DateTime.now().month;
                            endMonth = DateTime.now().month;
                            selectedYear = DateTime.now().year;
                          }
                        });
                        _fetchData();
                      },
                      child: const Text(
                        "Reset Filter",
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ),
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
      return ['Semua', 'To Do', 'Doing', 'Waiting Approval', 'Done'];
    } else if (widget.reportType == ReportType.attendance) {
      return ['Semua', 'Hadir', 'Telat'];
    } else if (widget.reportType == ReportType.leave) {
      return ['Semua', 'Izin', 'Sakit', 'Cuti'];
    } else if (widget.reportType == ReportType.operationalExpense) {
      return ['Semua', 'Pending', 'Approved', 'Rejected'];
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

        String checkInDisplay = '-';
        if (item['check_in_time'] != null) {
          try {
            // Try parse if it's a full timestamp
            checkInDisplay = DateTime.parse(
              item['check_in_time'],
            ).toString().split(' ')[1].substring(0, 5);
          } catch (_) {
            checkInDisplay = item['check_in_time'].toString();
          }
        }

        subtitle =
            "${DateFormat('dd MMM yyyy').format(DateTime.parse(item['tanggal'] ?? DateTime.now().toIso8601String()))} | Masuk: $checkInDisplay";
        status = item['status'] ?? '-';
        break;
      case ReportType.leave:
        final userLevel = item['users'] ?? {'nama': 'Unknown'};
        title = "${userLevel['nama']} (${item['jenis_surat']})";
        final tglAwal = item['tanggal_mulai'] != null
            ? DateFormat('dd MMM').format(DateTime.parse(item['tanggal_mulai']))
            : '-';
        final tglAkhir = item['tanggal_selesai'] != null
            ? DateFormat(
                'dd MMM yyyy',
              ).format(DateTime.parse(item['tanggal_selesai']))
            : '-';
        subtitle = "Tgl: $tglAwal s/d $tglAkhir";
        status = item['status'] ?? 'Pending';
        break;
      case ReportType.incomingLetter:
      case ReportType.outgoingLetter:
        title = item['perihal'] ?? 'No Subject';
        subtitle =
            "No: ${item['nomor_surat'] ?? '-'} | Tgl: ${item['tanggal_surat']}";
        status = widget.reportType == ReportType.incomingLetter
            ? "Masuk"
            : "Keluar";
        break;
      case ReportType.operationalExpense:
        title = item['keterangan'] ?? 'Tanpa Keterangan';
        final nominal = NumberFormat.currency(
          locale: 'id_ID',
          symbol: 'Rp ',
          decimalDigits: 0,
        ).format(item['jumlah_dana'] ?? 0);
        subtitle = "Nominal: $nominal | Tgl: ${item['tanggal_pengajuan']}";
        status = item['status'] ?? '-';
        break;
      case ReportType.performance:
        title = item['users'] != null ? item['users']['nama'] : 'Unknown';
        String periodeStr = startMonth == endMonth
            ? _monthNames[startMonth!]
            : "${_monthNames[startMonth!]} - ${_monthNames[endMonth!]}";
        subtitle =
            "Periode: $periodeStr ${item['tahun']} | Tugas: ${item['poin_tugas']} | Absen: ${item['poin_absen']}";
        status = "${item['total_poin']} Pkt";
        break;
    }

    return ListTile(
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Chip(label: Text(status, style: const TextStyle(fontSize: 10))),
    );
  }
}
