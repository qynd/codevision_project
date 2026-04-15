

class ExpenseModel {
  final String id;
  final String userId;
  final String? projectId;
  final double jumlahDana;
  final String keterangan;
  final DateTime tanggalPengajuan;
  final String? buktiNotaUrl;
  final String status;
  final String? approverId;
  final DateTime createdAt;

  final String? userName;
  final String? projectName;
  final String? approverName;

  ExpenseModel({
    required this.id,
    required this.userId,
    this.projectId,
    required this.jumlahDana,
    required this.keterangan,
    required this.tanggalPengajuan,
    this.buktiNotaUrl,
    required this.status,
    this.approverId,
    required this.createdAt,
    this.userName,
    this.projectName,
    this.approverName,
  });

  factory ExpenseModel.fromJson(Map<String, dynamic> json) {
    return ExpenseModel(
      id: json['id'],
      userId: json['user_id'],
      projectId: json['project_id'],
      jumlahDana: (json['jumlah_dana'] as num).toDouble(),
      keterangan: json['keterangan'] ?? '',
      tanggalPengajuan: DateTime.parse(json['tanggal_pengajuan']),
      buktiNotaUrl: json['bukti_nota_url'],
      status: json['status'] ?? 'Pending',
      approverId: json['approver_id'],
      createdAt: DateTime.parse(json['created_at']),
      userName: json['users'] != null ? json['users']['nama'] : (json['fk_expense_user'] != null ? json['fk_expense_user']['nama'] : null),
      projectName: json['projects'] != null ? json['projects']['nama_proyek'] : null,
      approverName: json['approver'] != null ? json['approver']['nama'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'project_id': projectId,
      'jumlah_dana': jumlahDana,
      'keterangan': keterangan,
      'tanggal_pengajuan': tanggalPengajuan.toIso8601String().split('T')[0],
      'bukti_nota_url': buktiNotaUrl,
      'status': status,
      'approver_id': approverId,
    };
  }
}
