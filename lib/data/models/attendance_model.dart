class AttendanceModel {
  final String id;
  final String namaPegawai;
  final String jabatan;
  final String tanggal;
  final String checkInTime;
  final String checkOutTime;
  final String status;
  final String keterangan;

  AttendanceModel({
    required this.id,
    required this.namaPegawai,
    required this.jabatan,
    required this.tanggal,
    required this.checkInTime,
    required this.checkOutTime,
    required this.status,
    required this.keterangan,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final user = json['users'] ?? {};
    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      namaPegawai: user['nama'] ?? '-',
      jabatan: user['jabatan'] ?? '-',
      tanggal: json['tanggal'] ?? '',
      checkInTime: json['check_in_time'] != null 
          ? DateTime.parse(json['check_in_time']).toLocal().toString().split(' ')[1].substring(0, 5) 
          : '--:--',
      checkOutTime: json['check_out_time'] != null 
          ? DateTime.parse(json['check_out_time']).toLocal().toString().split(' ')[1].substring(0, 5) 
          : '--:--',
      status: json['status'] ?? '-',
      keterangan: json['keterangan'] ?? '-',
    );
  }
}
