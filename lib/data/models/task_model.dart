class TaskModel {
  final String id;
  final String projectId;
  final String judul;
  final String deskripsi;
  final String status;
  final int progress;
  final String? assignedTo;
  final String? assignedToName; // Field baru untuk nama pegawai

  TaskModel({
    required this.id,
    required this.projectId,
    required this.judul,
    required this.deskripsi,
    required this.status,
    required this.progress,
    this.assignedTo,
    this.assignedToName,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    // Logic: Jika ada relation 'users' (join), ambil nama dari situ.
    String? name;
    if (json['users'] != null) {
      // Jika 'users' berupa Map (single join)
      name = json['users']['nama']; 
    }

    return TaskModel(
      // PERBAIKAN UTAMA: Tambahkan .toString()
      // Ini memaksa UUID (yang dianggap String) tetap dibaca sebagai String,
      // dan mencegah error jika sebelumnya aplikasi mengira ini int.
      id: json['id'].toString(),

      // Cek null dulu, baru toString. Jika kosong, isi string kosong ''.
      projectId: json['project_id'] != null ? json['project_id'].toString() : '',

      judul: json['judul'] ?? 'Tanpa Judul',
      deskripsi: json['deskripsi'] ?? '',
      status: json['status'] ?? 'To Do',

      // PERBAIKAN SAFETY: Gunakan tryParse
      // Ini menjaga agar jika DB mengirim angka dalam format string, app tidak crash.
      progress: int.tryParse(json['progress_percent'].toString()) ?? 0,

      // Handle assigned_to yang bisa null
      assignedTo: json['assigned_to']?.toString(),
      assignedToName: name, // Set nama (bisa null jika tidak di-join)
    );
  }
}