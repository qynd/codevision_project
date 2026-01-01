import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/models/user_model.dart';

class AuthService {
  final SupabaseClient _client = Supabase.instance.client;

  // Fungsi Login (sudah ada sebelumnya)
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (e) {
      throw Exception(e.message);
    }
  }

  // --- FUNGSI BARU: Ambil Detail Pegawai ---
  Future<UserModel?> getCurrentUserData() async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) return null;

      // Ambil data dari tabel 'users' berdasarkan ID yang sedang login
      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .single();

      return UserModel.fromJson(response);
    } catch (e) {
      print('Error ambil data detail: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }
}