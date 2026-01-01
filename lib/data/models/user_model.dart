// lib/data/models/user_model.dart

class UserModel {
  final String id;
  final String nip;
  final String nama;
  final String email;
  final String? jabatan;
  final String role;
  final bool isActive;

  UserModel({
    required this.id,
    required this.nip,
    required this.nama,
    required this.email,
    this.jabatan,
    required this.role,
    required this.isActive,
  });

  // Fungsi untuk mengubah data dari Database (Map/JSON) ke Objek UserModel
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      nip: json['nip'] ?? '',
      nama: json['nama'] ?? '',
      email: json['email'] ?? '',
      jabatan: json['jabatan'],
      role: json['role'] ?? 'Pegawai',
      isActive: json['is_active'] ?? true,
    );
  }

  // Fungsi untuk mengubah Objek UserModel kembali ke Map/JSON (jika butuh update)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nip': nip,
      'nama': nama,
      'email': email,
      'jabatan': jabatan,
      'role': role,
      'is_active': isActive,
    };
  }
}