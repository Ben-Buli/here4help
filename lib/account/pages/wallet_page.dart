import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/wallet_service.dart';
import 'package:flutter/services.dart';
import 'package:here4help/services/theme_config_manager.dart';

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
            color: Colors.black.withValues(alpha: 0.08),
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

  // --- BEGIN: BankInfo copy-state helpers ---
  final Map<String, bool> _bankInfoCopied = {};
  final Map<String, int> _bankInfoCopyTimers = {};

  void _handleBankInfoCopy(String key, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    setState(() {
      _bankInfoCopied[key] = true;
    });
    final int currentTimer = (_bankInfoCopyTimers[key] ?? 0) + 1;
    _bankInfoCopyTimers[key] = currentTimer;
    Future.delayed(const Duration(seconds: 3), () {
      if (_bankInfoCopyTimers[key] == currentTimer) {
        setState(() {
          _bankInfoCopied[key] = false;
        });
      }
    });
  }
  // --- END: BankInfo copy-state helpers ---

  Widget _buildBankInfoContainer() {
    final theme = Theme.of(context);
    final themeManager = context.watch<ThemeConfigManager>();
    final primaryColor = themeManager.dialogPrimaryColor;
    final subtleColor = themeManager.dialogContentColor.withValues(alpha: 0.7);
    final titleColor = themeManager.dialogTitleColor;
    final cardBackground =
        Color.alphaBlend(primaryColor.withValues(alpha: 0.08), Colors.white);
    final cardBorder = primaryColor.withValues(alpha: 0.2);
    final successColor = theme.colorScheme.secondary;
    final warningColor = theme.colorScheme.error;
    final bannerBackground =
        Color.alphaBlend(warningColor.withValues(alpha: 0.12), Colors.white);

    if (bankAccountInfo == null || !bankAccountInfo!.hasValidAccount) {
      return Container(
        padding: const EdgeInsets.all(12),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: cardBorder),
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

    Widget buildBankInfoTile({
      required String label,
      required String value,
      required String copyKey,
      IconData? icon,
    }) {
      final copied = _bankInfoCopied[copyKey] == true;
      return ListTile(
        dense: true,
        leading: icon != null ? Icon(icon, color: subtleColor) : null,
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
                ? Icon(Icons.check,
                    key: const ValueKey('check'), color: successColor)
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
      color: cardBackground,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bank Transfer Info',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 8),
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
                color: bannerBackground,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      color: warningColor.withValues(alpha: 0.85), size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: 'After completing the transfer, enter ',
                            style: TextStyle(
                                fontSize: 12,
                                color: warningColor.withValues(alpha: 0.85)),
                          ),
                          TextSpan(
                            text: 'last 5 digits of your bank account, ',
                            style: TextStyle(
                                fontSize: 12,
                                color: warningColor.withValues(alpha: 0.85),
                                fontWeight: FontWeight.bold),
                          ),
                          TextSpan(
                            text: 'and the ',
                            style: TextStyle(
                                fontSize: 12,
                                color: warningColor.withValues(alpha: 0.85)),
                          ),
                          TextSpan(
                            text: 'amount transferred.',
                            style: TextStyle(
                                fontSize: 12,
                                color: warningColor.withValues(alpha: 0.85),
                                fontWeight: FontWeight.bold),
                          ),
                        ],
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
          builder: (context, setDialogState) {
            final theme = Theme.of(context);
            final themeManager = context.watch<ThemeConfigManager>();
            final dialogBackground = theme.dialogTheme.backgroundColor ??
                themeManager.dialogBackgroundColor;
            final primaryColor = themeManager.dialogPrimaryColor;
            final warningColor = theme.colorScheme.error;

            return StreamBuilder<List<Object?>>(
              stream: Stream.value([bankAccountInfo, isLoading, errorMessage]),
              builder: (context, snapshot) {
                final mediaQuery = MediaQuery.of(context);
                final bottomInset = mediaQuery.viewInsets.bottom;

                return AlertDialog(
                  backgroundColor: dialogBackground,
                  shape: theme.dialogTheme.shape,
                  titleTextStyle: theme.dialogTheme.titleTextStyle,
                  contentTextStyle: theme.dialogTheme.contentTextStyle,
                  scrollable: true,
                  insetPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
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
                            style: TextStyle(
                                color: warningColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                    ],
                  ),
                  content: Padding(
                    padding: EdgeInsets.only(
                      bottom: bottomInset > 0 ? bottomInset : 0,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (bankAccountInfo != null &&
                            bankAccountInfo!.hasValidAccount)
                          _buildBankInfoContainer()
                        else if (isLoading)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Text(
                              'Loading bank information...',
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                              ),
                            ),
                          )
                        else
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8.0),
                            child: Column(
                              children: [
                                Text(
                                  'Bank info unavailable. Please try again later.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: warningColor,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    await _loadWalletData();
                                    setDialogState(() {});
                                  },
                                  icon: const Icon(Icons.refresh, size: 16),
                                  label: const Text('Retry',
                                      style: TextStyle(fontSize: 12)),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 4),
                                  ),
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
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textInputAction: TextInputAction.next,
                          maxLength: 5,
                          onChanged: (_) {
                            if (errorText != null) {
                              setDialogState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: amountController,
                          decoration: const InputDecoration(
                            labelText: 'Transferred Amount (NTD)',
                            border: OutlineInputBorder(),
                            hintText: '12345',
                            counterText: '',
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(5),
                          ],
                          textInputAction: TextInputAction.done,
                          onChanged: (_) {
                            if (errorText != null) {
                              setDialogState(() => errorText = null);
                            }
                          },
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed:
                          isSubmitting ? null : () => Navigator.pop(context),
                      style:
                          TextButton.styleFrom(foregroundColor: primaryColor),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: isSubmitting ||
                              bankAccountInfo == null ||
                              !bankAccountInfo!.hasValidAccount
                          ? null
                          : () async {
                              final acc = accountController.text.trim();
                              final amtStr = amountController.text.trim();
                              if (acc.length != 5) {
                                setDialogState(() => errorText =
                                    'Please enter the last 5 digits of your account (numbers only).');
                                return;
                              }
                              if (amtStr.isEmpty) {
                                setDialogState(() => errorText =
                                    'Please enter the transferred amount.');
                                return;
                              }
                              if (amtStr.length > 5) {
                                setDialogState(() => errorText =
                                    'Amount too large. Maximum 5 digits.');
                                return;
                              }
                              final amountVal = int.tryParse(amtStr);
                              if (amountVal == null || amountVal <= 0) {
                                setDialogState(() => errorText =
                                    'Amount must be a positive number.');
                                return;
                              }

                              setDialogState(() => isSubmitting = true);

                              try {
                                await _submitTopupRequest(acc, amountVal);

                                if (!mounted || !context.mounted) {
                                  return;
                                }
                                Navigator.pop(context);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                        'Topup request submitted, waiting for admin approval'),
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                  ),
                                );
                              } catch (e) {
                                if (mounted) {
                                  String msg = 'Submission failed: $e';
                                  if (e.toString().contains('409')) {
                                    msg =
                                        'You already have a pending topup request. Please wait for admin approval or check Points History.';
                                  }
                                  setDialogState(() => errorText = msg);
                                }
                              } finally {
                                if (mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
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
      },
    );
  }

  Future<void> _submitTopupRequest(String bankAccountLast5, int amount) async {
    final userService = Provider.of<UserService>(context, listen: false);
    final currentUser = userService.currentUser;

    if (currentUser == null) {
      throw Exception('用戶未登入');
    }

    final requestBody = {
      'user_id': currentUser.id,
      'amount': amount,
      'bank_account_last5': bankAccountLast5,
    };

    final response = await HttpClientService.post(
      AppConfig.api('/points/request_topup.php'),
      useQueryParamToken: true, // MAMP 兼容性
      body: requestBody,
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
                  leading: Icon(Icons.add_card_outlined,
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
                  leading: Icon(Icons.output_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Withdraw Request'),
                  onTap: () {
                    GoRouter.of(context).go('/account/wallet/withdraw');
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: Icon(Icons.policy_outlined,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Point Policy'),
                  onTap: () {
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
