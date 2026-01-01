import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AdminAttendanceScreen extends StatefulWidget {
  const AdminAttendanceScreen({super.key});

  @override
  State<AdminAttendanceScreen> createState() => _AdminAttendanceScreenState();
}

class _AdminAttendanceScreenState extends State<AdminAttendanceScreen> {
  final supabase = Supabase.instance.client;

  // --- STATE VARIABLES ---
  
  DateTimeRange _selectedRange = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 6)), // 1 minggu terakhir
    end: DateTime.now(),
  );

  bool _isLoading = true;
  bool _sortByName = false; 

  List<Map<String, dynamic>> _allData = []; 
  List<Map<String, dynamic>> _filteredList = []; 

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAttendance();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- LOGIC ---

  Future<void> _fetchAttendance() async {
    setState(() => _isLoading = true);

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_selectedRange.start);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_selectedRange.end);

      final response = await supabase
          .from('attendances')
          .select('*, users(nama, nip, jabatan)')
          .gte('tanggal', startDateStr) 
          .lte('tanggal', endDateStr);

      if (mounted) {
        setState(() {
          _allData = List<Map<String, dynamic>>.from(response);
          _applyFilterAndSort(); 
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error Fetch Attendance: $e");
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  void _applyFilterAndSort() {
    final query = _searchController.text.toLowerCase();

    // 1. FILTER PENCARIAN
    List<Map<String, dynamic>> temp = _allData.where((item) {
      final user = item['users'] ?? {};
      final nama = (user['nama'] ?? '').toString().toLowerCase();
      return nama.contains(query);
    }).toList();

    // 2. SORTING
    temp.sort((a, b) {
      final userA = a['users'] ?? {};
      final userB = b['users'] ?? {};
      final namaA = (userA['nama'] ?? '').toString();
      final namaB = (userB['nama'] ?? '').toString();
      
      final dateA = a['tanggal'] ?? '';
      final dateB = b['tanggal'] ?? '';

      if (_sortByName) {
        int compareNama = namaA.compareTo(namaB);
        if (compareNama != 0) return compareNama;
        return dateB.compareTo(dateA); 
      } else {
        int compareDate = dateB.compareTo(dateA); 
        if (compareDate != 0) return compareDate;
        return namaA.compareTo(namaB); 
      }
    });

    setState(() {
      _filteredList = temp;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedRange = picked;
      });
      _fetchAttendance(); 
    }
  }

  // --- PERBAIKAN FORMAT WAKTU (MENGHAPUS .toLocal) ---
  // Karena data di DB sudah dianggap waktu lokal, kita tidak perlu mengonversinya lagi.
  String _formatTime(String? timestamp) {
    if (timestamp == null) return "--:--";
    try {
      // Cukup Parse saja, JANGAN pakai .toLocal() agar tidak nambah 8 jam lagi
      final dt = DateTime.parse(timestamp);
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      return "--:--";
    }
  }
  
  String _formatDateShort(String dateStr) {
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy', 'id_ID').format(dt);
    } catch (e) {
      return dateStr;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'hadir': return Colors.green;
      case 'telat': return Colors.orange;
      case 'izin': return Colors.blue;
      case 'sakit': return Colors.purple;
      case 'cuti': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Monitoring Absensi"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          // --- HEADER FILTER ---
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // 1. Search Bar
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: "Cari nama pegawai...",
                    prefixIcon: const Icon(Icons.search),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onChanged: (value) => _applyFilterAndSort(),
                ),
                
                const SizedBox(height: 12),
                
                // 2. Baris Opsi
                Row(
                  children: [
                    // Tombol Pilih Tanggal
                    Expanded(
                      flex: 3,
                      child: InkWell(
                        onTap: _pickDateRange,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_month, color: Colors.indigo, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  "${DateFormat('dd MMM').format(_selectedRange.start)} - ${DateFormat('dd MMM yyyy').format(_selectedRange.end)}",
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    // Checkbox Sorting
                    Expanded(
                      flex: 2,
                      child: InkWell(
                        onTap: () {
                          setState(() {
                            _sortByName = !_sortByName;
                            _applyFilterAndSort();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                          decoration: BoxDecoration(
                            color: _sortByName ? Colors.indigo.shade50 : Colors.transparent,
                            border: Border.all(
                              color: _sortByName ? Colors.indigo : Colors.grey.shade300
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _sortByName ? Icons.check_box : Icons.check_box_outline_blank,
                                size: 18,
                                color: _sortByName ? Colors.indigo : Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                "Abjad A-Z",
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: _sortByName ? Colors.indigo : Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          Container(height: 1, color: Colors.grey.shade200),

          // --- INFO HASIL ---
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade50,
            child: Row(
              children: [
                Text(
                  "Total: ${_filteredList.length} Absensi",
                  style: TextStyle(color: Colors.grey.shade700, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Text(
                  _sortByName ? "Urut: Nama Pegawai" : "Urut: Tanggal Terbaru",
                  style: const TextStyle(color: Colors.indigo, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ],
            ),
          ),

          // --- LIST DATA ---
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : _filteredList.isEmpty 
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.filter_list_off, size: 60, color: Colors.grey[300]),
                          const SizedBox(height: 10),
                          Text("Data tidak ditemukan", style: TextStyle(color: Colors.grey[600])),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                      itemCount: _filteredList.length,
                      itemBuilder: (context, index) {
                        final item = _filteredList[index];
                        final user = item['users'];
                        final nama = user != null ? user['nama'] : 'Unknown';
                        final jabatan = user != null ? user['jabatan'] ?? '-' : '-';
                        final status = item['status'] ?? 'Hadir';
                        final tanggal = item['tanggal'];

                        // Menentukan apakah tampilkan jam atau keterangan
                        final bool isHadir = (status == 'Hadir' || status == 'Telat');
                        final String timeInfo = isHadir 
                            ? "${_formatTime(item['check_in_time'])} - ${_formatTime(item['check_out_time'])}"
                            : item['keterangan'] ?? "Tidak Hadir";

                        return Card(
                          elevation: 1,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: Colors.indigo.shade50,
                                  child: Text(
                                    nama.isNotEmpty ? nama[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.indigo, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(nama, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(Icons.calendar_today, size: 10, color: Colors.grey.shade600),
                                          const SizedBox(width: 4),
                                          Text(_formatDateShort(tanggal), 
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade800, fontWeight: FontWeight.w500)),
                                          const SizedBox(width: 8),
                                          Text("• $jabatan", 
                                            style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),

                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: _getStatusColor(status).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        status,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: _getStatusColor(status)),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Tampilkan Jam jika hadir, atau Keterangan jika sakit/izin
                                    Container(
                                      constraints: const BoxConstraints(maxWidth: 80),
                                      child: Text(
                                        timeInfo,
                                        style: TextStyle(
                                          fontSize: 11, 
                                          fontWeight: FontWeight.w600, 
                                          color: isHadir ? Colors.black : Colors.grey
                                        ),
                                        textAlign: TextAlign.end,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
          ),
        ],
      ),
    );
  }
}