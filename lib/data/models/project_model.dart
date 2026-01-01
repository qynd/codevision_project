class ProjectModel {
  final String id;
  final String namaProyek;
  final String deskripsi;
  final String status;
  final String startDate;
  final String dueDate;

  ProjectModel({
    required this.id,
    required this.namaProyek,
    required this.deskripsi,
    required this.status,
    required this.startDate,
    required this.dueDate,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      // TAMBAHKAN .toString() DISINI UNTUK MENCEGAH ERROR
      id: json['id'].toString(), 
      namaProyek: json['nama_proyek'] ?? 'Tanpa Nama',
      deskripsi: json['deskripsi'] ?? '-',
      status: json['status'] ?? 'New',
      startDate: json['start_date']?.toString() ?? '',
      dueDate: json['due_date']?.toString() ?? '',
    );
  }
}