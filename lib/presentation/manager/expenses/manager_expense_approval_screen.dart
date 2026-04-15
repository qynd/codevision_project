import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/expense_model.dart';
import '../../home/expenses/add_expense_screen.dart';

class ManagerExpenseApprovalScreen extends StatefulWidget {
  const ManagerExpenseApprovalScreen({super.key});

  @override
  State<ManagerExpenseApprovalScreen> createState() => _ManagerExpenseApprovalScreenState();
}

class _ManagerExpenseApprovalScreenState extends State<ManagerExpenseApprovalScreen> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<ExpenseModel> _expenses = [];

  @override
  void initState() {
    super.initState();
    _fetchExpenses();
  }

  Future<void> _fetchExpenses() async {
    setState(() => _isLoading = true);
    try {
      final response = await supabase
          .from('operational_expenses')
          .select('*, users!fk_expense_user(nama), projects(nama_proyek), approver:approver_id(nama)')
          .order('status', ascending: false) // Pending dulu (P), baru Approved/Rejected
          .order('tanggal_pengajuan', ascending: false);

      final List<ExpenseModel> loaded = (response as List<dynamic>)
          .map((e) => ExpenseModel.fromJson(e))
          .toList();

      if (mounted) {
        setState(() {
          _expenses = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching expenses for approval: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;
      
      await supabase.from('operational_expenses').update({
        'status': newStatus,
        'approver_id': user.id,
      }).eq('id', id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text("Berhasil: Pengajuan menjadi $newStatus"), backgroundColor: Colors.green),
        );
      }
      _fetchExpenses();
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengupdate: $e"), backgroundColor: Colors.red),
        );
      }
    }
  }

  String _formatCurrency(double amount) {
    return NumberFormat.currency(locale: 'id_ID', symbol: 'Rp ', decimalDigits: 0).format(amount);
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: _fetchExpenses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _expenses.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: Text("Belum ada pengajuan dana yang perlu direview.",
                            style: TextStyle(color: Colors.grey)),
                      ),
                    ],
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _expenses.length,
                    itemBuilder: (context, index) {
                      final exp = _expenses[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    exp.userName ?? "Unknown",
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: _getStatusColor(exp.status).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      exp.status,
                                      style: TextStyle(
                                        color: _getStatusColor(exp.status),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text("Tujuan: ${exp.keterangan}", style: const TextStyle(color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text("Nominal: ${_formatCurrency(exp.jumlahDana)}",
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                              const SizedBox(height: 4),
                              Text("Tanggal: ${DateFormat('dd MMM yyyy').format(exp.tanggalPengajuan)}"),
                              
                              if (exp.projectName != null) ...[
                                const SizedBox(height: 4),
                                Text("Proyek: ${exp.projectName}",
                                    style: TextStyle(color: Colors.indigo.shade700)),
                              ],

                              if (exp.approverName != null) ...[
                                const SizedBox(height: 8),
                                Text("Direview oleh: ${exp.approverName}",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontStyle: FontStyle.italic)),
                              ],

                              if (exp.status == 'Pending') ...[
                                const Divider(height: 24),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () => _updateStatus(exp.id, 'Rejected'),
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: Colors.red,
                                          side: const BorderSide(color: Colors.red),
                                        ),
                                        child: const Text("Tolak"),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: ElevatedButton(
                                        onPressed: () => _updateStatus(exp.id, 'Approved'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                        child: const Text("Setujui"),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            _fetchExpenses();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
