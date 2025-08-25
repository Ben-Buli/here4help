import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/wallet_service.dart';
import 'package:flutter/services.dart';

import 'package:here4help/services/http_client_service.dart';
import 'dart:convert';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  WalletSummary? walletSummary;
  FeeSettings? feeSettings;
  BankAccountInfo? bankAccountInfo;
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadWalletData();
  }

  Future<void> _loadWalletData() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final userService = Provider.of<UserService>(context, listen: false);
      // 等待使用者資料載入完成（熱重啟/冷啟時避免讀取時序問題）
      await userService.ensureUserLoaded();

      if (userService.currentUser == null) {
        throw Exception('用戶未登入');
      }

      final results = await Future.wait([
        WalletService.getWalletSummary(userService),
        WalletService.getFeeSettings(userService),
        WalletService.getBankAccountInfo(userService),
      ]);

      setState(() {
        walletSummary = results[0] as WalletSummary;
        feeSettings = results[1] as FeeSettings;
        bankAccountInfo = results[2] as BankAccountInfo;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Widget _buildWalletCard() {
    if (isLoading) {
      return Container(
        height: 120,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: CircularProgressIndicator(
            color: Theme.of(context).colorScheme.onPrimary,
          ),
        ),
      );
    }

    if (errorMessage != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.red.shade100,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.red.shade300),
        ),
        child: Column(
          children: [
            Icon(Icons.error, color: Colors.red.shade700, size: 36),
            const SizedBox(height: 8),
            Text(
              'Failed to load wallet data',
              style: TextStyle(
                color: Colors.red.shade700,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              errorMessage!,
              style: TextStyle(color: Colors.red.shade600, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loadWalletData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (walletSummary == null) {
      return const SizedBox.shrink();
    }

    final points = walletSummary!.pointsSummary;

    return Container(
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
                // 第一行：總點數（大字體）
                Text(
                  WalletService.formatPoints(points.totalPoints),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                // 第二行：可用點數（縮排+次要顏色）
                Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text(
                    '${WalletService.formatPoints(points.availablePoints)} (Useable)',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                // if (points.occupiedPoints > 0)
                //   Padding(
                //     padding: const EdgeInsets.only(left: 8.0, top: 1.0),
                //     child: Text(
                //       '${WalletService.formatPoints(points.occupiedPoints)} (In use)',
                //       style: TextStyle(
                //         color: Theme.of(context)
                //             .colorScheme
                //             .onPrimary
                //             .withOpacity(0.6),
                //         fontSize: 12,
                //       ),
                //     ),
                //   ),
              ],
            ),
          ),
          Text(
            'Points',
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimary, fontSize: 18),
          ),
        ],
      ),
    );
  }

  // --- BEGIN: BankInfoCopyRow widget and state for copied flags ---
  // This is a reusable widget to show a label, value, copy button, and "Copied!" message.
  // The state (copied flags) is stored in the _WalletPageState.
  // We'll use a Map<String, bool> to keep track of which row is copied.

  final Map<String, bool> _bankInfoCopied = {};
  final Map<String, int> _bankInfoCopyTimers = {};

  void _handleBankInfoCopy(String key, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    setState(() {
      _bankInfoCopied[key] = true;
    });
    // Cancel any previous timer for this key (by incrementing a counter)
    final int currentTimer = (_bankInfoCopyTimers[key] ?? 0) + 1;
    _bankInfoCopyTimers[key] = currentTimer;
    Future.delayed(const Duration(seconds: 3), () {
      // Only clear if this is the latest timer for this key
      if (_bankInfoCopyTimers[key] == currentTimer) {
        setState(() {
          _bankInfoCopied[key] = false;
        });
      }
    });
  }

  Widget BankInfoCopyRow({
    required String label,
    required String value,
    TextStyle? labelStyle,
    TextStyle? valueStyle,
    required String copyKey,
  }) {
    final copied = _bankInfoCopied[copyKey] == true;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          '$label: ',
          style: labelStyle,
        ),
        Expanded(
          child: Text(
            value,
            style: valueStyle,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          icon: const Icon(Icons.copy, size: 18),
          tooltip: copied ? "Copied!" : "Copy",
          onPressed: () => _handleBankInfoCopy(copyKey, value),
        ),
        AnimatedOpacity(
          opacity: copied ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: copied
              ? const Padding(
                  padding: EdgeInsets.only(left: 2.0),
                  child: Text(
                    "Copied!",
                    style: TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
  // --- END: BankInfoCopyRow widget and copy state ---

  Widget _buildBankInfoContainer() {
    if (bankAccountInfo == null || !bankAccountInfo!.hasValidAccount) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank account info not found.',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              'Please contact admin to add bank account info.',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      );
    }

    final bankAccount = bankAccountInfo!.displayAccount!;

    // Helper to build each card tile row for bank info
    Widget buildBankInfoTile({
      required String label,
      required String value,
      required String copyKey,
      IconData? icon,
    }) {
      final copied = _bankInfoCopied[copyKey] == true;
      return ListTile(
        dense: true,
        leading: icon != null ? Icon(icon, color: Colors.blueGrey[600]) : null,
        title: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        subtitle: Text(
          value,
          style: const TextStyle(fontSize: 13),
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: copied
                ? const Icon(Icons.check,
                    key: ValueKey('check'), color: Colors.green)
                : const Icon(Icons.copy, key: ValueKey('copy')),
          ),
          tooltip: copied ? "Copied!" : "Copy",
          onPressed: () => _handleBankInfoCopy(copyKey, value),
        ),
        visualDensity: const VisualDensity(horizontal: -2, vertical: -2),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      );
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 10, bottom: 2),
              child: Text(
                'Bank Transfer Info',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
            buildBankInfoTile(
              label: 'Bank Name',
              value: bankAccount.bankName,
              copyKey: 'bankName',
              icon: Icons.account_balance,
            ),
            buildBankInfoTile(
              label: 'Account',
              value: bankAccount.accountNumber,
              copyKey: 'accountNumber',
              icon: Icons.numbers,
            ),
            buildBankInfoTile(
              label: 'Account Holder',
              value: bankAccount.accountHolder,
              copyKey: 'accountHolder',
              icon: Icons.person,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF8E1), // 淺黃色
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, color: Color(0xFFFBC02D), size: 18),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'After completing the transfer, enter ',
                            style: TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                          TextSpan(
                            text: 'last 5 digits of your bank account, ',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown,
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: 'and the ',
                            style: TextStyle(fontSize: 12, color: Colors.brown),
                          ),
                          TextSpan(
                            text: 'amount transferred.',
                            style: TextStyle(
                                fontSize: 12,
                                color: Colors.brown,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                        style: TextStyle(fontSize: 12, color: Colors.brown),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddPointsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final TextEditingController accountController = TextEditingController();
        final TextEditingController amountController = TextEditingController();
        bool isSubmitting = false;
        String? errorText;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Add Points'),
                  if (errorText != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6.0),
                      child: Text(
                        errorText!,
                        style: const TextStyle(
                            color: Colors.red,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (bankAccountInfo != null &&
                      bankAccountInfo!.hasValidAccount)
                    _buildBankInfoContainer()
                  else
                    const Padding(
                      padding: EdgeInsets.only(bottom: 8.0),
                      child: Text(
                        'Bank info unavailable. Please try again later.',
                        style: TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ),
                  TextField(
                    controller: accountController,
                    decoration: const InputDecoration(
                      labelText: 'Your Payment Account Last 5 Digits',
                      border: OutlineInputBorder(),
                      hintText: '00000',
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    maxLength: 5,
                    onChanged: (_) {
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountController,
                    decoration: const InputDecoration(
                      labelText: 'Transferred Amount (NTD)',
                      border: OutlineInputBorder(),
                      hintText: '100',
                      counterText: '',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(5),
                    ],
                    onChanged: (_) {
                      if (errorText != null) setState(() => errorText = null);
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ||
                          bankAccountInfo == null ||
                          !bankAccountInfo!.hasValidAccount
                      ? null
                      : () async {
                          final acc = accountController.text.trim();
                          final amtStr = amountController.text.trim();
                          if (acc.length != 5) {
                            setState(() => errorText =
                                'Please enter the last 5 digits of your account (numbers only).');
                            return;
                          }
                          if (amtStr.isEmpty) {
                            setState(() => errorText =
                                'Please enter the transferred amount.');
                            return;
                          }
                          if (amtStr.length > 5) {
                            setState(() => errorText =
                                'Amount too large. Maximum 5 digits.');
                            return;
                          }
                          final amountVal = int.tryParse(amtStr);
                          if (amountVal == null || amountVal <= 0) {
                            setState(() => errorText =
                                'Amount must be a positive number.');
                            return;
                          }

                          setState(() => isSubmitting = true);

                          try {
                            await _submitTopupRequest(acc, amountVal);

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
                              String msg = 'Submission failed: $e';
                              if (e.toString().contains('409')) {
                                msg =
                                    'You already have a pending topup request. Please wait for admin approval or check Points History.';
                              }
                              setState(() => errorText = msg);
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

  Future<void> _submitTopupRequest(String bankAccountLast5, int amount) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUser = userService.currentUser;

    if (currentUser == null) {
      throw Exception('用戶未登入');
    }

    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/points/request_topup.php',
      useQueryParamToken: true, // MAMP 兼容性
      body: {
        'user_id': currentUser.id,
        'amount': amount,
        'bank_account_last5': bankAccountLast5,
      },
    );

    final responseData = json.decode(response.body);

    if (response.statusCode != 200 || responseData['success'] != true) {
      throw Exception(responseData['message'] ?? 'Unknown error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadWalletData,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (walletSummary != null)
            Text(
              'Hello, ${walletSummary!.userInfo.displayName}',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          const SizedBox(height: 16),
          _buildWalletCard(),
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
                  leading: Icon(Icons.history,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Points History'),
                  onTap: () {
                    context.go('/account/wallet/point_history');
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
      ),
    );
  }
}
