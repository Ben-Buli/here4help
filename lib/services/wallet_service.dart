import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/services/http_client_service.dart';
import 'package:flutter/foundation.dart';

class WalletService {
  static final String _baseUrl = AppConfig.apiBaseUrl;

  /// 錢包統計數據模型
  static Future<WalletSummary> getWalletSummary(UserService userService) async {
    try {
      if (kDebugMode) {
        debugPrint('[getWalletSummary] $_baseUrl');
      }

      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/wallet/summary.php',
        useQueryParamToken: true, // MAMP 兼容性
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return WalletSummary.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load wallet summary');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 手續費設定數據
  static Future<FeeSettings> getFeeSettings(UserService userService) async {
    try {
      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/wallet/fee-settings.php',
        useQueryParamToken: true, // MAMP 兼容性
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return FeeSettings.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load fee settings');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 格式化點數顯示（千位逗號）
  static String formatPoints(int points) {
    return points.toString().replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (Match m) => '${m[1]},',
        );
  }

  /// 銀行帳戶資訊
  static Future<BankAccountInfo> getBankAccountInfo(
      UserService userService) async {
    try {
      final response = await HttpClientService.get(
        '$_baseUrl/backend/api/wallet/bank-accounts.php',
        useQueryParamToken: true, // MAMP 兼容性
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return BankAccountInfo.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load bank account info');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 獲取儲值申請記錄
  static Future<DepositRequestsResult> getDepositRequests(
    UserService userService, {
    int page = 1,
    int perPage = 20,
    String? status,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (status != null) {
        queryParams['status'] = status;
      }
      if (fromDate != null) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null) {
        queryParams['to_date'] = toDate;
      }

      final uri = Uri.parse('$_baseUrl/backend/api/wallet/deposit-requests.php')
          .replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri.toString(),
        useQueryParamToken: true, // MAMP 兼容性
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return DepositRequestsResult.fromJson(data['data']);
      } else {
        throw Exception(data['message'] ?? 'Failed to load deposit requests');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 獲取交易歷史
  static Future<TransactionHistoryResult> getTransactionHistory(
    UserService userService, {
    int page = 1,
    int perPage = 20,
    String? transactionType,
    String? fromDate,
    String? toDate,
  }) async {
    try {
      final queryParams = <String, String>{
        'page': page.toString(),
        'per_page': perPage.toString(),
      };

      if (transactionType != null) {
        queryParams['transaction_type'] = transactionType;
      }
      if (fromDate != null) {
        queryParams['from_date'] = fromDate;
      }
      if (toDate != null) {
        queryParams['to_date'] = toDate;
      }

      // according to DB: point_transactions
      // according to DB: point_deposit_requests
      final uri = Uri.parse('$_baseUrl/backend/api/wallet/transactions.php')
          .replace(queryParameters: queryParams);

      final response = await HttpClientService.get(
        uri.toString(),
        useQueryParamToken: true, // MAMP 兼容性
      );

      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }

      final data = json.decode(response.body);

      if (data['success'] == true) {
        return TransactionHistoryResult.fromJson(data['data']);
      } else {
        throw Exception(
            data['message'] ?? 'Failed to load transaction history');
      }
    } catch (e) {
      throw Exception('網路錯誤: $e');
    }
  }

  /// 計算手續費
  static int calculateFee(int rewardPoints, double feeRate) {
    if (feeRate <= 0) return 0;
    return (rewardPoints * feeRate).round();
  }
}

/// 錢包統計數據模型
class WalletSummary {
  final UserInfo userInfo;
  final PointsSummary pointsSummary;
  final List<ActiveTask> activeTasks;
  final int activeTasksCount;

  WalletSummary({
    required this.userInfo,
    required this.pointsSummary,
    required this.activeTasks,
    required this.activeTasksCount,
  });

  factory WalletSummary.fromJson(Map<String, dynamic> json) {
    return WalletSummary(
      userInfo: UserInfo.fromJson(json['user_info']),
      pointsSummary: PointsSummary.fromJson(json['points_summary']),
      activeTasks: (json['active_tasks'] as List)
          .map((task) => ActiveTask.fromJson(task))
          .toList(),
      activeTasksCount: json['active_tasks_count'] ?? 0,
    );
  }
}

class UserInfo {
  final int id;
  final String name;
  final String? nickname;

  UserInfo({
    required this.id,
    required this.name,
    this.nickname,
  });

  factory UserInfo.fromJson(Map<String, dynamic> json) {
    return UserInfo(
      id: json['id'],
      name: json['name'] ?? '',
      nickname: json['nickname'],
    );
  }

  String get displayName => nickname?.isNotEmpty == true ? nickname! : name;
}

class PointsSummary {
  final int totalPoints;
  final int occupiedPoints;
  final int availablePoints;

  PointsSummary({
    required this.totalPoints,
    required this.occupiedPoints,
    required this.availablePoints,
  });

  factory PointsSummary.fromJson(Map<String, dynamic> json) {
    return PointsSummary(
      totalPoints: json['total_points'] ?? 0,
      occupiedPoints: json['occupied_points'] ?? 0,
      availablePoints: json['available_points'] ?? 0,
    );
  }
}

class ActiveTask {
  final String id;
  final String title;
  final int rewardPoint;
  final int statusId;
  final String createdAt;

  ActiveTask({
    required this.id,
    required this.title,
    required this.rewardPoint,
    required this.statusId,
    required this.createdAt,
  });

  factory ActiveTask.fromJson(Map<String, dynamic> json) {
    return ActiveTask(
      id: json['id'],
      title: json['title'] ?? '',
      rewardPoint: json['reward_point'] ?? 0,
      statusId: json['status_id'] ?? 0,
      createdAt: json['created_at'] ?? '',
    );
  }
}

/// 手續費設定模型
class FeeSettings {
  final bool feeEnabled;
  final double rate;
  final String ratePercentage;
  final String description;
  final CalculationExample calculationExample;

  FeeSettings({
    required this.feeEnabled,
    required this.rate,
    required this.ratePercentage,
    required this.description,
    required this.calculationExample,
  });

  factory FeeSettings.fromJson(Map<String, dynamic> json) {
    return FeeSettings(
      feeEnabled: json['fee_enabled'] ?? false,
      rate: (json['settings']?['rate'] ?? 0.0).toDouble(),
      ratePercentage: json['settings']?['rate_percentage'] ?? '0.00%',
      description: json['settings']?['description'] ?? 'No fees',
      calculationExample: CalculationExample.fromJson(
        json['calculation_example'] ?? {},
      ),
    );
  }
}

class CalculationExample {
  final int taskReward;
  final int feeAmount;
  final int creatorPays;
  final int acceptorReceives;

  CalculationExample({
    required this.taskReward,
    required this.feeAmount,
    required this.creatorPays,
    required this.acceptorReceives,
  });

  factory CalculationExample.fromJson(Map<String, dynamic> json) {
    return CalculationExample(
      taskReward: json['task_reward'] ?? 0,
      feeAmount: json['fee_amount'] ?? 0,
      creatorPays: json['creator_pays'] ?? 0,
      acceptorReceives: json['acceptor_receives'] ?? 0,
    );
  }
}

/// 銀行帳戶資訊模型
class BankAccountInfo {
  final bool hasActiveAccount;
  final BankAccount? activeAccount;
  final BankAccount? defaultInfo;

  BankAccountInfo({
    required this.hasActiveAccount,
    this.activeAccount,
    this.defaultInfo,
  });

  factory BankAccountInfo.fromJson(Map<String, dynamic> json) {
    return BankAccountInfo(
      hasActiveAccount: json['has_active_account'] ?? false,
      activeAccount: json['active_account'] != null
          ? BankAccount.fromJson(json['active_account'])
          : null,
      defaultInfo: json['default_info'] != null
          ? BankAccount.fromJson(json['default_info'])
          : null,
    );
  }

  BankAccount? get displayAccount => activeAccount ?? defaultInfo;

  bool get hasValidAccount => displayAccount != null;
}

class BankAccount {
  final int? id;
  final String bankName;
  final String accountNumber;
  final String? accountNumberFormatted;
  final String accountHolder;

  BankAccount({
    this.id,
    required this.bankName,
    required this.accountNumber,
    this.accountNumberFormatted,
    required this.accountHolder,
  });

  factory BankAccount.fromJson(Map<String, dynamic> json) {
    return BankAccount(
      id: json['id'],
      bankName: json['bank_name'] ?? '',
      accountNumber: json['account_number'] ?? '',
      accountNumberFormatted: json['account_number_formatted'],
      accountHolder: json['account_holder'] ?? '',
    );
  }

  String get displayAccountNumber => accountNumberFormatted ?? accountNumber;
}

/// 交易歷史結果模型
class TransactionHistoryResult {
  final List<PointTransaction> transactions;
  final PaginationInfo pagination;
  final Map<String, dynamic> filters;
  final Map<String, TransactionTypeStats> statistics;

  TransactionHistoryResult({
    required this.transactions,
    required this.pagination,
    required this.filters,
    required this.statistics,
  });

  factory TransactionHistoryResult.fromJson(Map<String, dynamic> json) {
    return TransactionHistoryResult(
      transactions: (json['transactions'] as List)
          .map((tx) => PointTransaction.fromJson(tx))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination']),
      filters: json['filters'] ?? {},
      statistics: (json['statistics'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, TransactionTypeStats.fromJson(value))),
    );
  }
}

class PointTransaction {
  final int id;
  final String transactionType;
  final int amount;
  final String description;
  final String? relatedTaskId;
  final String status;
  final String createdAt;
  final String formattedAmount;
  final bool isIncome;
  final String displayType;

  PointTransaction({
    required this.id,
    required this.transactionType,
    required this.amount,
    required this.description,
    this.relatedTaskId,
    required this.status,
    required this.createdAt,
    required this.formattedAmount,
    required this.isIncome,
    required this.displayType,
  });

  factory PointTransaction.fromJson(Map<String, dynamic> json) {
    return PointTransaction(
      id: json['id'],
      transactionType: json['transaction_type'],
      amount: json['amount'],
      description: json['description'],
      relatedTaskId: json['related_task_id'],
      status: json['status'],
      createdAt: json['created_at'],
      formattedAmount: json['formatted_amount'],
      isIncome: json['is_income'],
      displayType: json['display_type'],
    );
  }
}

class PaginationInfo {
  final int currentPage;
  final int perPage;
  final int total;
  final int totalPages;
  final bool hasNextPage;
  final bool hasPrevPage;

  PaginationInfo({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.totalPages,
    required this.hasNextPage,
    required this.hasPrevPage,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) {
    return PaginationInfo(
      currentPage: json['current_page'],
      perPage: json['per_page'],
      total: json['total'],
      totalPages: json['total_pages'],
      hasNextPage: json['has_next_page'],
      hasPrevPage: json['has_prev_page'],
    );
  }
}

class TransactionTypeStats {
  final int count;
  final int totalIncome;
  final int totalExpense;
  final String displayName;

  TransactionTypeStats({
    required this.count,
    required this.totalIncome,
    required this.totalExpense,
    required this.displayName,
  });

  factory TransactionTypeStats.fromJson(Map<String, dynamic> json) {
    return TransactionTypeStats(
      count: json['count'],
      totalIncome: json['total_income'],
      totalExpense: json['total_expense'],
      displayName: json['display_name'],
    );
  }
}

/// 儲值申請記錄結果模型
class DepositRequestsResult {
  final List<DepositRequest> requests;
  final PaginationInfo pagination;
  final Map<String, dynamic> filters;
  final Map<String, DepositStatusStats> statistics;

  DepositRequestsResult({
    required this.requests,
    required this.pagination,
    required this.filters,
    required this.statistics,
  });

  factory DepositRequestsResult.fromJson(Map<String, dynamic> json) {
    return DepositRequestsResult(
      requests: (json['requests'] as List)
          .map((req) => DepositRequest.fromJson(req))
          .toList(),
      pagination: PaginationInfo.fromJson(json['pagination']),
      filters: json['filters'] ?? {},
      statistics: (json['statistics'] as Map<String, dynamic>? ?? {}).map(
          (key, value) => MapEntry(key, DepositStatusStats.fromJson(value))),
    );
  }
}

/// 儲值申請記錄模型
class DepositRequest {
  final int id;
  final int userId;
  final int amountPoints;
  final String bankAccountLast5;
  final String status;
  final String? approverReplyDescription;
  final int? approverId;
  final String? approverName;
  final String createdAt;
  final String updatedAt;
  final String userName;
  final String userEmail;
  final String formattedAmount;
  final String statusDisplay;
  final String statusColor;

  DepositRequest({
    required this.id,
    required this.userId,
    required this.amountPoints,
    required this.bankAccountLast5,
    required this.status,
    this.approverReplyDescription,
    this.approverId,
    this.approverName,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
    required this.userEmail,
    required this.formattedAmount,
    required this.statusDisplay,
    required this.statusColor,
  });

  factory DepositRequest.fromJson(Map<String, dynamic> json) {
    return DepositRequest(
      id: json['id'],
      userId: json['user_id'],
      amountPoints: json['amount_points'],
      bankAccountLast5: json['bank_account_last5'],
      status: json['status'],
      approverReplyDescription: json['approver_reply_description'],
      approverId: json['approver_id'],
      approverName: json['approver_name'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
      userName: json['user_name'],
      userEmail: json['user_email'],
      formattedAmount: json['formatted_amount'],
      statusDisplay: json['status_display'],
      statusColor: json['status_color'],
    );
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}

/// 儲值狀態統計模型
class DepositStatusStats {
  final int count;
  final int totalAmount;
  final String displayName;

  DepositStatusStats({
    required this.count,
    required this.totalAmount,
    required this.displayName,
  });

  factory DepositStatusStats.fromJson(Map<String, dynamic> json) {
    return DepositStatusStats(
      count: json['count'],
      totalAmount: json['total_amount'],
      displayName: json['display_name'],
    );
  }
}
