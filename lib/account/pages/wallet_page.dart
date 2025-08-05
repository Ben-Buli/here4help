import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';

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
        return AlertDialog(
          title: const Text('Add Points'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please remit to our bank account, then enter the last 5 digits and amount.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: accountController,
                decoration: const InputDecoration(
                  labelText: 'Last 5 digits',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                maxLength: 5,
              ),
              const SizedBox(height: 8),
              TextField(
                controller: amountController,
                decoration: const InputDecoration(
                  labelText: 'Amount',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                // TODO: 積分加值邏輯
                Navigator.pop(context);
              },
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );
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
