class PerformanceModel {
  final String id;
  final String userId;
  final String userName;
  final int bulan;
  final int tahun;
  final int poinTugas;
  final int poinAbsen;
  final int totalPoin;

  PerformanceModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.bulan,
    required this.tahun,
    required this.poinTugas,
    required this.poinAbsen,
    required this.totalPoin,
  });

  factory PerformanceModel.fromJson(Map<String, dynamic> json) {
    return PerformanceModel(
      id: json['id'],
      userId: json['user_id'],
      userName: json['users'] != null 
          ? json['users']['nama'] 
          : (json['fk_performance_user'] != null ? json['fk_performance_user']['nama'] : 'Unknown'),
      bulan: json['bulan'],
      tahun: json['tahun'],
      poinTugas: json['poin_tugas'] ?? 0,
      poinAbsen: json['poin_absen'] ?? 0,
      totalPoin: json['total_poin'] ?? 0,
    );
  }
}
