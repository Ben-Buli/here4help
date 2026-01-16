import 'package:flutter/material.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/wallet_service.dart';
import 'package:provider/provider.dart';

class WalletWithdrawPage extends StatefulWidget {
  const WalletWithdrawPage({super.key});

  @override
  State<WalletWithdrawPage> createState() => _WalletWithdrawPageState();
}

class _WalletWithdrawPageState extends State<WalletWithdrawPage> {
  final TextEditingController _amountController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  WalletSummary? walletSummary;
  WithdrawFeeSettings? feeSettings;
  List<WithdrawRequest> requests = [];

  bool isLoading = true;
  bool isSubmitting = false;
  bool isLoadingMore = false;
  String? errorMessage;
  int currentPage = 1;
  bool hasNextPage = false;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _amountController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (hasNextPage && !isLoadingMore) {
        _loadMore();
      }
    }
  }

  Future<void> _loadAll({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          currentPage = 1;
          requests.clear();
          isLoading = true;
          errorMessage = null;
        });
      }

      final userService = Provider.of<UserService>(context, listen: false);
      await userService.ensureUserLoaded();

      final results = await Future.wait([
        WalletService.getWalletSummary(userService),
        WalletService.getWithdrawFeeSettings(userService),
        WalletService.getWithdrawRequests(userService, page: currentPage),
      ]);

      final withdrawResult = results[2] as WithdrawRequestsResult;
      setState(() {
        walletSummary = results[0] as WalletSummary;
        feeSettings = results[1] as WithdrawFeeSettings;
        if (currentPage == 1) {
          requests = withdrawResult.requests;
        } else {
          requests.addAll(withdrawResult.requests);
        }
        hasNextPage = withdrawResult.pagination.hasNextPage;
        isLoading = false;
        isLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
        isLoadingMore = false;
      });
    }
  }

  Future<void> _loadMore() async {
    if (isLoadingMore || !hasNextPage) return;
    setState(() {
      isLoadingMore = true;
      currentPage += 1;
    });
    await _loadAll();
  }

  int _parseAmount() {
    final raw = _amountController.text.trim();
    return int.tryParse(raw) ?? 0;
  }

  int _calculateFeePoints(int amount) {
    final rate = feeSettings?.rate ?? 0.0;
    return (amount * rate).round();
  }

  Future<void> _submitWithdraw() async {
    final userService = Provider.of<UserService>(context, listen: false);
    await userService.ensureUserLoaded();

    final amount = _parseAmount();
    final minWithdraw = feeSettings?.minWithdrawPoints ?? 0;
    final available = walletSummary?.pointsSummary.availablePoints ?? 0;
    final feePoints = _calculateFeePoints(amount);
    final totalDeduct = amount + feePoints;

    if (amount <= 0) {
      _showSnack('Please enter a valid amount.');
      return;
    }
    if (amount < minWithdraw) {
      _showSnack('Minimum withdraw is $minWithdraw points.');
      return;
    }
    if (available < totalDeduct) {
      _showSnack('Insufficient balance for this withdrawal.');
      return;
    }

    setState(() {
      isSubmitting = true;
    });

    try {
      await WalletService.createWithdrawRequest(
        userService,
        amountPoints: amount,
      );
      _amountController.clear();
      await _loadAll(refresh: true);
      _showSnack('Withdraw request submitted.');
    } catch (e) {
      _showSnack('Failed to submit withdraw request.');
    } finally {
      if (mounted) {
        setState(() {
          isSubmitting = false;
        });
      }
    }
  }

  Future<void> _cancelWithdraw(WithdrawRequest request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel withdraw'),
        content: const Text('Are you sure you want to cancel this request?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final userService = Provider.of<UserService>(context, listen: false);
      await WalletService.cancelWithdrawRequest(
        userService,
        requestId: request.id,
      );
      await _loadAll(refresh: true);
      _showSnack('Withdraw request cancelled.');
    } catch (e) {
      _showSnack('Failed to cancel withdraw request.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending':
        return Colors.orange.shade700;
      case 'approved':
        return Colors.blue.shade700;
      case 'paid':
        return Colors.green.shade700;
      case 'rejected':
        return Colors.red.shade700;
      case 'cancelled':
        return Colors.grey.shade600;
      default:
        return Colors.grey.shade600;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Pending';
      case 'approved':
        return 'Approved';
      case 'paid':
        return 'Paid';
      case 'rejected':
        return 'Rejected';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  Widget _buildHeaderCard() {
    final points = walletSummary?.pointsSummary;
    final available = points?.availablePoints ?? 0;
    final frozen = points?.frozenWithdrawPoints ?? 0;
    final total = points?.totalPoints ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Available Points',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              WalletService.formatPoints(available),
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Total: ${WalletService.formatPoints(total)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Frozen: ${WalletService.formatPoints(frozen)}',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeeInfoCard() {
    final rate = feeSettings?.rate ?? 0.0;
    final rateText = '${(rate * 100).toStringAsFixed(2)}%';
    final minWithdraw = feeSettings?.minWithdrawPoints ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Withdraw Fee',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Fee rate: $rateText'),
            const SizedBox(height: 4),
            Text('Minimum withdraw: $minWithdraw points'),
            if ((feeSettings?.description ?? '').isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(feeSettings!.description!),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildWithdrawForm() {
    final amount = _parseAmount();
    final feePoints = _calculateFeePoints(amount);
    final totalDeduct = amount + feePoints;
    final rate = feeSettings?.rate ?? 0.0;
    final rateText = '${(rate * 100).toStringAsFixed(2)}%';
    final canSubmit = !isSubmitting &&
        feeSettings != null &&
        walletSummary != null &&
        !isLoading;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Withdraw Request',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Amount (points)',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) {
                setState(() {});
              },
            ),
            const SizedBox(height: 12),
            Text(
              'Formula: $amount + $feePoints (fee $rateText) = $totalDeduct',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: canSubmit ? _submitWithdraw : null,
                child: isSubmitting
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistory() {
    if (isLoading && requests.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorMessage != null && requests.isEmpty) {
      return Center(
        child: Column(
          children: [
            const SizedBox(height: 24),
            Icon(Icons.error_outline, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 12),
            const Text('Failed to load withdraw history'),
            const SizedBox(height: 8),
            Text(errorMessage!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () => _loadAll(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (requests.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          children: [
            Icon(Icons.history, color: Colors.grey.shade400, size: 48),
            const SizedBox(height: 12),
            const Text('No withdraw requests yet'),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final request in requests) _buildRequestCard(request),
        if (hasNextPage)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ElevatedButton(
              onPressed: isLoadingMore ? null : _loadMore,
              child: isLoadingMore
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Load more'),
            ),
          ),
      ],
    );
  }

  Widget _buildRequestCard(WithdrawRequest request) {
    final color = _statusColor(request.status);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Request #${request.id}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _statusLabel(request.status),
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Amount: ${WalletService.formatPoints(request.amountPoints)}',
            ),
            Text(
              'Fee: ${WalletService.formatPoints(request.feePoints)}',
            ),
            Text(
              'Total deduct: ${WalletService.formatPoints(request.totalDeductPoints)}',
            ),
            const SizedBox(height: 8),
            Text(
              'Submitted: ${request.createdAt}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
            if ((request.adminReply ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                'Admin reply: ${request.adminReply}',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
            if (request.isPending) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _cancelWithdraw(request),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () => _loadAll(refresh: true),
      child: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.all(20),
        children: [
          if (walletSummary != null) _buildHeaderCard(),
          const SizedBox(height: 12),
          if (feeSettings != null) _buildFeeInfoCard(),
          const SizedBox(height: 12),
          _buildWithdrawForm(),
          const SizedBox(height: 16),
          const Text(
            'Withdraw History',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
          _buildHistory(),
        ],
      ),
    );
  }
}
