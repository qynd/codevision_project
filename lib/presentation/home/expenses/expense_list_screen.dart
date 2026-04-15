import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/expense_model.dart';
import 'add_expense_screen.dart';

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
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
      final user = supabase.auth.currentUser;
      if (user == null) return;

      final response = await supabase
          .from('operational_expenses')
          .select('*, projects(nama_proyek), approver:approver_id(nama)')
          .eq('user_id', user.id)
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
      debugPrint("Error fetching expenses: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal memuat data: $e")),
        );
        setState(() => _isLoading = false);
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
      appBar: AppBar(
        title: const Text("Pengajuan Dana Operasional"),
      ),
      body: RefreshIndicator(
        onRefresh: _fetchExpenses,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _expenses.isEmpty
                ? ListView(
                    children: [
                      SizedBox(height: MediaQuery.of(context).size.height * 0.3),
                      const Center(
                        child: Text("Belum ada pengajuan dana operasional.",
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
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          title: Text(
                            exp.keterangan,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 8),
                              Text("Nominal: ${_formatCurrency(exp.jumlahDana)}",
                                  style: const TextStyle(color: Colors.black87)),
                              Text("Tanggal: ${DateFormat('dd MMM yyyy').format(exp.tanggalPengajuan)}"),
                              if (exp.projectName != null)
                                Text("Proyek: ${exp.projectName}",
                                    style: TextStyle(color: Colors.indigo.shade700)),
                              if (exp.approverName != null)
                                Text("Direview oleh: ${exp.approverName}",
                                    style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            ],
                          ),
                          trailing: Container(
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
                        ),
                      );
                    },
                  ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddExpenseScreen()),
          );
          if (result == true) {
            _fetchExpenses();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text("Ajukan Dana"),
      ),
    );
  }
}
