import 'package:flutter/material.dart';
import 'package:here4help/services/wallet_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:provider/provider.dart';

// **
// according to DB: point_deposit_requests

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  State<PointHistoryPage> createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 交易記錄相關狀態
  List<PointTransaction> transactions = [];
  List<PointTransaction> allTransactions = []; // 儲存所有交易記錄
  bool isLoading = true;
  bool isLoadingMore = false;
  String? errorMessage;
  int currentPage = 1;
  bool hasNextPage = false;
  String? selectedType;

  // 儲值申請記錄相關狀態
  List<DepositRequest> depositRequests = [];
  List<DepositRequest> allDepositRequests = []; // 儲存所有儲值申請記錄
  bool isDepositLoading = true;
  bool isDepositLoadingMore = false;
  String? depositErrorMessage;
  int depositCurrentPage = 1;
  bool depositHasNextPage = false;
  String? selectedStatus;

  final ScrollController _scrollController = ScrollController();
  final ScrollController _depositScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadTransactions();
    _loadDepositRequests();
    _scrollController.addListener(_onScroll);
    _depositScrollController.addListener(_onDepositScroll);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _depositScrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels ==
        _scrollController.position.maxScrollExtent) {
      if (hasNextPage && !isLoadingMore) {
        _loadMoreTransactions();
      }
    }
  }

  Future<void> _loadTransactions({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          currentPage = 1;
          transactions.clear();
          isLoading = true;
          errorMessage = null;
        });
      }

      final userService = Provider.of<UserService>(context, listen: false);
      // 確保使用者資料已載入
      await userService.ensureUserLoaded();

      final result = await WalletService.getTransactionHistory(
        userService,
        page: currentPage,
      );

      setState(() {
        if (refresh || currentPage == 1) {
          allTransactions = result.transactions;
          transactions = _filterTransactions(allTransactions);
        } else {
          allTransactions.addAll(result.transactions);
          transactions = _filterTransactions(allTransactions);
        }
        hasNextPage = result.pagination.hasNextPage;
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

  Future<void> _loadMoreTransactions() async {
    if (!hasNextPage || isLoadingMore) return;

    setState(() {
      isLoadingMore = true;
      currentPage++;
    });

    await _loadTransactions();
  }

  void _onDepositScroll() {
    if (_depositScrollController.position.pixels ==
        _depositScrollController.position.maxScrollExtent) {
      if (depositHasNextPage && !isDepositLoadingMore) {
        _loadMoreDepositRequests();
      }
    }
  }

  Future<void> _loadDepositRequests({bool refresh = false}) async {
    try {
      if (refresh) {
        setState(() {
          depositCurrentPage = 1;
          depositRequests.clear();
          isDepositLoading = true;
          depositErrorMessage = null;
        });
      }

      final userService = Provider.of<UserService>(context, listen: false);
      await userService.ensureUserLoaded();

      final result = await WalletService.getDepositRequests(
        userService,
        page: depositCurrentPage,
      );

      setState(() {
        if (refresh || depositCurrentPage == 1) {
          allDepositRequests = result.requests;
          depositRequests = _filterDepositRequests(allDepositRequests);
        } else {
          allDepositRequests.addAll(result.requests);
          depositRequests = _filterDepositRequests(allDepositRequests);
        }
        depositHasNextPage = result.pagination.hasNextPage;
        isDepositLoading = false;
        isDepositLoadingMore = false;
      });
    } catch (e) {
      setState(() {
        depositErrorMessage = e.toString();
        isDepositLoading = false;
        isDepositLoadingMore = false;
      });
    }
  }

  Future<void> _loadMoreDepositRequests() async {
    if (!depositHasNextPage || isDepositLoadingMore) return;

    setState(() {
      isDepositLoadingMore = true;
      depositCurrentPage++;
    });

    await _loadDepositRequests();
  }

  /// 無刷新篩選方法
  void _applyFilter(String? filterType) {
    setState(() {
      selectedType = filterType;
      transactions = _filterTransactions(allTransactions);
    });
  }

  /// 篩選交易記錄
  List<PointTransaction> _filterTransactions(List<PointTransaction> allTx) {
    if (selectedType == null) {
      return allTx;
    }
    return allTx.where((tx) => tx.transactionType == selectedType).toList();
  }

  /// 無刷新篩選儲值申請記錄
  void _applyStatusFilter(String? filterStatus) {
    setState(() {
      selectedStatus = filterStatus;
      depositRequests = _filterDepositRequests(allDepositRequests);
    });
  }

  /// 篩選儲值申請記錄
  List<DepositRequest> _filterDepositRequests(List<DepositRequest> allReqs) {
    if (selectedStatus == null) {
      return allReqs;
    }
    return allReqs.where((req) => req.status == selectedStatus).toList();
  }

  /// 獲取所有`point_transactions`交易類型顯示名稱
  String _getTypeDisplayName(String type) {
    const displayNames = {
      'earn': 'Task Earnings',
      'spend': 'Task Spending',
      'deposit': 'Deposits',
      'fee': 'Fees',
      'refund': 'Refunds',
      'adjustment': 'Adjustments'
    };
    return displayNames[type] ?? type;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Tab Bar
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            border: Border(
              bottom: BorderSide(
                color: Theme.of(context).dividerColor,
                width: 0.5,
              ),
            ),
          ),
          child: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(
                icon: Icon(Icons.history),
                text: 'Transaction History',
              ),
              Tab(
                icon: Icon(Icons.request_page),
                text: 'Deposit Requests',
              ),
            ],
          ),
        ),
        // Tab Bar View
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _buildTransactionHistoryTab(),
              _buildDepositRequestsTab(),
            ],
          ),
        ),
      ],
    );
  }

  /// 交易記錄分頁
  Widget _buildTransactionHistoryTab() {
    return Column(
      children: [
        // 篩選區域
        _buildFilterSection(),
        // 交易列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadTransactions(refresh: true),
            child: _buildBody(),
          ),
        ),
      ],
    );
  }

  /// 儲值申請記錄分頁
  Widget _buildDepositRequestsTab() {
    return Column(
      children: [
        // 狀態篩選區域
        _buildDepositFilterSection(),
        // 儲值申請列表
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadDepositRequests(refresh: true),
            child: _buildDepositBody(),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: selectedType,
              decoration: const InputDecoration(
                labelText: 'Filter by Type',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Types'),
                ),
                DropdownMenuItem<String?>(
                  value: 'earn',
                  child: Text('Task Earnings'),
                ),
                DropdownMenuItem<String?>(
                  value: 'spend',
                  child: Text('Task Spending'),
                ),
                DropdownMenuItem<String?>(
                  value: 'deposit',
                  child: Text('Deposits'),
                ),
                DropdownMenuItem<String?>(
                  value: 'fee',
                  child: Text('Service Fees'),
                ),
                DropdownMenuItem<String?>(
                  value: 'refund',
                  child: Text('Refunds'),
                ),
                DropdownMenuItem<String?>(
                  value: 'adjustment',
                  child: Text('Adjustments'),
                ),
              ],
              onChanged: (value) {
                _applyFilter(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          if (selectedType != null)
            IconButton(
              onPressed: () {
                _applyFilter(null);
              },
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Filter',
            ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (isLoading && transactions.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (errorMessage != null && transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load transactions',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadTransactions(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              selectedType != null
                  ? 'No ${_getTypeDisplayName(selectedType!).toLowerCase()} transactions'
                  : 'Your transaction history will appear here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      itemCount: transactions.length + (isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == transactions.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final transaction = transactions[index];
        return _buildTransactionItem(transaction);
      },
    );
  }

  Widget _buildTransactionItem(PointTransaction transaction) {
    final isIncome = transaction.isIncome;
    final color = isIncome
        ? const Color.fromARGB(255, 127, 173, 128)
        : const Color.fromARGB(255, 178, 108, 105);

    return Column(
      children: [
        ListTile(
          isThreeLine: true,
          leading: CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            child: Icon(
              _getTransactionIcon(transaction.transactionType),
              color: color,
              size: 20,
            ),
          ),
          title: Text(
            transaction.displayType,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                transaction.description,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                _formatDate(transaction.createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey[500],
                ),
              ),
            ],
          ),
          trailing: Text(
            transaction.formattedAmount,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: color,
            ),
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  IconData _getTransactionIcon(String type) {
    const icons = {
      'earn': Icons.trending_up,
      'spend': Icons.trending_down,
      'deposit': Icons.add_circle,
      'fee': Icons.remove_circle,
      'refund': Icons.refresh,
      'adjustment': Icons.tune,
    };
    return icons[type] ?? Icons.list_alt;
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        return 'Today ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return dateString;
    }
  }

  /// 儲值申請篩選區域
  Widget _buildDepositFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String?>(
              value: selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Filter by Status',
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All Statuses'),
                ),
                DropdownMenuItem<String?>(
                  value: 'pending',
                  child: Text('Pending Review'),
                ),
                DropdownMenuItem<String?>(
                  value: 'approved',
                  child: Text('Approved'),
                ),
                DropdownMenuItem<String?>(
                  value: 'rejected',
                  child: Text('Rejected'),
                ),
              ],
              onChanged: (value) {
                _applyStatusFilter(value);
              },
            ),
          ),
          const SizedBox(width: 12),
          if (selectedStatus != null)
            IconButton(
              onPressed: () {
                _applyStatusFilter(null);
              },
              icon: const Icon(Icons.clear),
              tooltip: 'Clear Filter',
            ),
        ],
      ),
    );
  }

  /// 儲值申請記錄主體
  Widget _buildDepositBody() {
    if (isDepositLoading && depositRequests.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (depositErrorMessage != null && depositRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'Failed to load deposit requests',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              depositErrorMessage!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadDepositRequests(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (depositRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.request_page,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No deposit requests found',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              selectedStatus != null
                  ? 'No ${selectedStatus!} requests'
                  : 'Your deposit requests will appear here',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _depositScrollController,
      itemCount: depositRequests.length + (isDepositLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == depositRequests.length) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(),
            ),
          );
        }

        final request = depositRequests[index];
        return _buildDepositRequestItem(request);
      },
    );
  }

  /// 儲值申請項目
  Widget _buildDepositRequestItem(DepositRequest request) {
    Color statusColor;
    IconData statusIcon;

    switch (request.status) {
      case 'pending':
        statusColor = Colors.orange;
        statusIcon = Icons.schedule;
        break;
      case 'approved':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Column(
      children: [
        ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: statusColor.withOpacity(0.1),
            child: Icon(
              statusIcon,
              color: statusColor,
              size: 16,
            ),
          ),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  'Deposit Request #${request.id}',
                  style: const TextStyle(
                      fontWeight: FontWeight.w500, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                request.formattedAmount,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: statusColor,
                ),
              ),
            ],
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Bank Account: ***${request.bankAccountLast5}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                overflow: TextOverflow.ellipsis,
              ),
              if (request.approverReplyDescription != null)
                Text(
                  'Reply: ${request.approverReplyDescription}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDate(request.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Text(
                      request.statusDisplay,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }
}
