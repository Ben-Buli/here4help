import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
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
    userName = currentUser?.name ?? 'Guest';
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
                      labelText: '您的銀行帳號末五碼',
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
                      labelText: '匯款金額 (點數)',
                      border: OutlineInputBorder(),
                      hintText: '100',
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteController,
                    decoration: const InputDecoration(
                      labelText: '備註 (選填)',
                      border: OutlineInputBorder(),
                      hintText: '匯款用途說明',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () async {
                          if (accountController.text.trim().length != 5 ||
                              amountController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('請填寫正確的帳號末五碼和金額')),
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
                                  content: Text('點數儲值申請已提交，等待管理員審核'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('提交失敗: $e')),
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
                      : const Text('提交申請'),
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
      throw Exception(responseData['message'] ?? '未知錯誤');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Hello, $userName',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2563EB),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2563EB),
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
              const Icon(Icons.account_balance_wallet,
                  color: Colors.white, size: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Wallet',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                    Text(
                      '$points',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Points',
                style: TextStyle(color: Colors.white, fontSize: 18),
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
                leading: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary),
                title: const Text('Add Points'),
                onTap: _showAddPointsDialog,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.percent, color: AppColors.primary),
                title: const Text('Coupons'),
                onTap: () {
                  // TODO: 跳轉到優惠券頁面
                },
              ),
              const Divider(height: 1),
              ListTile(
                leading:
                    const Icon(Icons.info_outline, color: AppColors.primary),
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
