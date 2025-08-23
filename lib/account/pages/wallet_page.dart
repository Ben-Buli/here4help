import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  late int points;
  late String userName;

  @override
  void initState() {
    super.initState();
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUser = userService.currentUser;
    userName = currentUser?.nickname ?? currentUser?.name ?? 'User';
    points = currentUser?.points ?? 0;
  }

  void _showAddPointsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController accountController = TextEditingController();
        final TextEditingController amountController = TextEditingController();
        final TextEditingController noteController = TextEditingController();
        bool isSubmitting = false;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Add Points'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '銀行匯款資訊:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        SizedBox(height: 4),
                        Text('銀行: 台灣銀行', style: TextStyle(fontSize: 12)),
                        Text('帳號: 123-456-789-012',
                            style: TextStyle(fontSize: 12)),
                        Text('戶名: Here4Help Co., Ltd.',
                            style: TextStyle(fontSize: 12)),
                        SizedBox(height: 8),
                        Text(
                          '請匯款後填寫以下資訊:',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: accountController,
                    decoration: const InputDecoration(
                      labelText: 'Your Payment Account Last 5 Digits',
                      border: OutlineInputBorder(),
                      hintText: '12345',
                    ),
                    keyboardType: TextInputType.number,
                    maxLength: 5,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Topup Amount (Points)',
                      border: OutlineInputBorder(),
                      hintText: 'Enter Amount..',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: 'Note (Optional)',
                      border: OutlineInputBorder(),
                      hintText: 'Topup Purpose',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (accountController.text.trim().length != 5 ||
                              amountController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                  content: Text(
                                      'Please fill in the correct account last 5 digits and amount')),
                            );
                            return;
                          }

                          setState(() => isSubmitting = true);

                          try {
                            await _submitTopupRequest(
                              accountController.text.trim(),
                              int.parse(amountController.text.trim()),
                              noteController.text.trim(),
                            );

                            if (mounted) {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Topup request submitted, waiting for admin approval'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                    content: Text('Submission failed: $e')),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => isSubmitting = false);
                          }
                        },
                  child: isSubmitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Submit Request'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _submitTopupRequest(
      String bankAccountLast5, int amount, String note) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUser = userService.currentUser;

    if (currentUser == null) {
      throw Exception('用戶未登入');
    }

    final url = Uri.parse(
        '${AppConfig.apiBaseUrl}/backend/api/points/request_topup.php');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'user_id': currentUser.id,
        'amount': amount,
        'bank_account_last5': bankAccountLast5,
        'note': note.isEmpty ? null : note,
      }),
    );

    final responseData = json.decode(response.body);

    if (response.statusCode != 200 || responseData['success'] != true) {
      throw Exception(responseData['message'] ?? 'Unknown error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, $userName',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Icon(Icons.account_balance_wallet,
                  color: Theme.of(context).colorScheme.onPrimary, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Wallet',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.onPrimary,
                            fontSize: 16)),
                    Text(
                      '$points',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Points',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 18),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Payment info',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.add_circle_outline,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Add Points'),
                onTap: _showAddPointsDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.percent,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Coupons'),
                onTap: () {
                  // TODO: 跳轉到優惠券頁面
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.info_outline,
                    color: Theme.of(context).colorScheme.primary),
                title: const Text('Points Policies'),
                onTap: () {
                  // TODO: 跳轉到積分政策頁面
                  GoRouter.of(context).go('/account/wallet/point_policy');
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
