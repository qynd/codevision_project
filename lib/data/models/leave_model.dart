class LeaveModel {
  final String namaPegawai;
  final String jenisSurat;
  final DateTime? tanggalMulai;
  final DateTime? tanggalSelesai;
  final String keterangan;
  final String status;

  LeaveModel({
    required this.namaPegawai,
    required this.jenisSurat,
    this.tanggalMulai,
    this.tanggalSelesai,
    required this.keterangan,
    required this.status,
  });

  factory LeaveModel.fromJson(Map<String, dynamic> json) {
    return LeaveModel(
      namaPegawai: json['users'] != null ? json['users']['nama'] : 'Unknown',
      jenisSurat: json['jenis_surat'] ?? '-',
      tanggalMulai: json['tanggal_mulai'] != null ? DateTime.parse(json['tanggal_mulai']) : null,
      tanggalSelesai: json['tanggal_selesai'] != null ? DateTime.parse(json['tanggal_selesai']) : null,
      keterangan: json['keterangan'] ?? '-',
      status: json['status'] ?? 'Pending',
    );
  }
}
