import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:here4help/services/wallet_service.dart';
import 'dart:convert';

/// 支付對話框組件
class PaymentDialog extends StatefulWidget {
  final Map<String, dynamic> taskData;
  final Map<String, dynamic> userData;
  final VoidCallback? onPaymentSuccess;

  const PaymentDialog({
    super.key,
    required this.taskData,
    required this.userData,
    this.onPaymentSuccess,
  });

  @override
  State<PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<PaymentDialog> {
  // 表單狀態
  bool _agreedToTerms = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  // 密碼輸入
  final TextEditingController _passwordController1 = TextEditingController();
  final TextEditingController _passwordController2 = TextEditingController();
  bool _passwordsMatch = false;

  // 評分和評論
  double _rating = 0.0;
  final TextEditingController _commentController = TextEditingController();

  // 手續費相關
  Map<String, dynamic>? _feeSettings;
  double _feeRate = 0.0;
  int _feeAmount = 0;
  int _totalAmount = 0;

  @override
  void initState() {
    super.initState();
    _loadFeeSettings();
    _calculateFees();

    // 監聽密碼輸入
    _passwordController1.addListener(_checkPasswords);
    _passwordController2.addListener(_checkPasswords);
  }

  @override
  void dispose() {
    _passwordController1.dispose();
    _passwordController2.dispose();
    _commentController.dispose();
    super.dispose();
  }

  /// 載入手續費設定
  Future<void> _loadFeeSettings() async {
    try {
      final response = await HttpClientService.get(
        '${AppConfig.apiBaseUrl}/backend/api/wallet/fee-settings.php',
        useQueryParamToken: true,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _feeSettings = data['data'];
            _feeRate = (_feeSettings?['rate'] ?? 0.0).toDouble();
            _calculateFees();
          });
        }
      }
    } catch (e) {
      debugPrint('Error loading fee settings: $e');
    }
  }

  /// 計算手續費
  void _calculateFees() {
    final rewardPoints = widget.taskData['reward_point'] ?? 0;
    _feeAmount = (_feeRate * rewardPoints).round();
    _totalAmount = rewardPoints + _feeAmount;
  }

  /// 檢查密碼是否一致
  void _checkPasswords() {
    final password1 = _passwordController1.text;
    final password2 = _passwordController2.text;

    setState(() {
      _passwordsMatch = password1.isNotEmpty &&
          password2.isNotEmpty &&
          password1 == password2;
    });
  }

  /// 驗證表單
  bool _validateForm() {
    if (!_agreedToTerms) {
      setState(
          () => _errorMessage = 'Please agree to the terms and conditions');
      return false;
    }

    if (_passwordController1.text.isEmpty ||
        _passwordController2.text.isEmpty) {
      setState(() => _errorMessage = 'Please enter your payment password');
      return false;
    }

    if (!_passwordsMatch) {
      setState(() => _errorMessage = 'Payment passwords do not match');
      return false;
    }

    if (_rating == 0.0) {
      setState(() => _errorMessage = 'Please provide a rating');
      return false;
    }

    if (_commentController.text.trim().isEmpty) {
      setState(() => _errorMessage = 'Please provide a comment');
      return false;
    }

    setState(() => _errorMessage = null);
    return true;
  }

  /// 提交支付
  Future<void> _submitPayment() async {
    if (!_validateForm()) return;

    setState(() => _isSubmitting = true);

    try {
      // 1. 點數轉移
      await _transferPoints();

      // 2. 扣除手續費（如果有）
      if (_feeAmount > 0) {
        await _deductFee();
      }

      // 3. 記錄交易
      await _recordTransactions();

      // 4. 記錄手續費收入
      if (_feeAmount > 0) {
        await _recordFeeRevenue();
      }

      // 5. 提交評分評論
      await _submitReview();

      if (mounted) {
        Navigator.of(context).pop();
        widget.onPaymentSuccess?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Payment completed successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = 'Payment failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  /// 點數轉移
  Future<void> _transferPoints() async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/points/transfer.php',
      useQueryParamToken: true,
      body: {
        'from_user_id': widget.userData['id'],
        'to_user_id': widget.taskData['participant_id'],
        'amount': widget.taskData['reward_point'],
        'task_id': widget.taskData['id'],
        'transaction_type': 'task_payment',
      },
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Transfer failed');
    }
  }

  /// 扣除手續費
  Future<void> _deductFee() async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/points/deduct-fee.php',
      useQueryParamToken: true,
      body: {
        'user_id': widget.userData['id'],
        'amount': _feeAmount,
        'task_id': widget.taskData['id'],
        'fee_rate': _feeRate,
        'transaction_type': 'completion_fee',
      },
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Fee deduction failed');
    }
  }

  /// 記錄交易
  Future<void> _recordTransactions() async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/points/transactions.php',
      useQueryParamToken: true,
      body: {
        'transactions': [
          {
            'user_id': widget.userData['id'],
            'amount': -widget.taskData['reward_point'],
            'type': 'task_payment_out',
            'task_id': widget.taskData['id'],
            'description': 'Payment for task: ${widget.taskData['title']}',
          },
          {
            'user_id': widget.taskData['participant_id'],
            'amount': widget.taskData['reward_point'],
            'type': 'task_payment_in',
            'task_id': widget.taskData['id'],
            'description':
                'Payment received for task: ${widget.taskData['title']}',
          },
          if (_feeAmount > 0)
            {
              'user_id': widget.userData['id'],
              'amount': -_feeAmount,
              'type': 'completion_fee',
              'task_id': widget.taskData['id'],
              'description': 'Task completion fee',
            },
        ],
      },
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Transaction recording failed');
    }
  }

  /// 記錄手續費收入
  Future<void> _recordFeeRevenue() async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/admin/fee-revenue.php',
      useQueryParamToken: true,
      body: {
        'task_id': widget.taskData['id'],
        'amount': _feeAmount,
        'fee_rate': _feeRate,
        'description': 'Task completion fee revenue',
      },
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Fee revenue recording failed');
    }
  }

  /// 提交評分評論
  Future<void> _submitReview() async {
    final response = await HttpClientService.post(
      '${AppConfig.apiBaseUrl}/backend/api/reviews/create.php',
      useQueryParamToken: true,
      body: {
        'task_id': widget.taskData['id'],
        'reviewer_id': widget.userData['id'],
        'reviewee_id': widget.taskData['participant_id'],
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'review_type': 'task_completion',
      },
    );

    if (response.statusCode != 200) {
      final data = json.decode(response.body);
      throw Exception(data['message'] ?? 'Review submission failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 標題
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.payment,
                      color: theme.colorScheme.onPrimary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Confirm Payment',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: theme.colorScheme.onPrimary),
                  ),
                ],
              ),
            ),

            // 內容
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 錯誤訊息
                    if (_errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error,
                                color: Colors.red.shade600, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // 上半部：支付確認
                    _buildPaymentSection(theme),

                    const Divider(height: 32),

                    // 下半部：評分評論
                    _buildReviewSection(theme),
                  ],
                ),
              ),
            ),

            // 底部按鈕
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitPayment,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor:
                                    AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : const Text('Confirm Payment'),
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

  /// 構建支付確認區塊
  Widget _buildPaymentSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Payment Confirmation',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // 任務信息
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Task: ${widget.taskData['title']}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text('Reward Points: ${widget.taskData['reward_point']}'),
              if (_feeAmount > 0) ...[
                const SizedBox(height: 4),
                Text(
                    'Completion Fee: $_feeAmount (${(_feeRate * 100).toStringAsFixed(1)}%)'),
                const SizedBox(height: 4),
                Text(
                  'Total Amount: $_totalAmount',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 16),

        // 同意條款
        Row(
          children: [
            Checkbox(
              value: _agreedToTerms,
              onChanged: (value) =>
                  setState(() => _agreedToTerms = value ?? false),
            ),
            Expanded(
              child: Text(
                'I agree to pay the task completion fee and transfer the reward points to the tasker',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 支付密碼
        Text(
          'Payment Password',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _passwordController1,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Enter password',
                  border: OutlineInputBorder(),
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextFormField(
                controller: _passwordController2,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm password',
                  border: const OutlineInputBorder(),
                  suffixIcon:
                      _passwordsMatch && _passwordController1.text.isNotEmpty
                          ? const Icon(Icons.check_circle, color: Colors.green)
                          : null,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// 構建評分評論區塊
  Widget _buildReviewSection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Rate & Review',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // 評分
        Row(
          children: [
            Text(
              'Rating: ',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            RatingBar.builder(
              initialRating: _rating,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: false,
              itemCount: 5,
              itemSize: 24,
              itemBuilder: (context, _) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() {
                  _rating = rating;
                });
              },
            ),
            const SizedBox(width: 8),
            Text(
              '$_rating/5',
              style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // 評論
        Text(
          'Comment',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),

        TextFormField(
          controller: _commentController,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Share your experience with this tasker...',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }
}
