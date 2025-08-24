import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/api/review_api.dart';
import 'package:here4help/widgets/review_dialog.dart';

class TaskHistoryPage extends StatefulWidget {
  const TaskHistoryPage({super.key});

  @override
  State<TaskHistoryPage> createState() => _TaskHistoryPageState();
}

class _TaskHistoryPageState extends State<TaskHistoryPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 只回傳內容，不再包 AppScaffold
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: const Row(
            children: [
              Text(
                'Credit Score',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Spacer(),
              Text(
                '4.9',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 22,
                ),
              ),
            ],
          ),
        ),
        Container(
          color: Colors.white,
          child: TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(
                icon: Icon(Icons.assignment_outlined),
                text: 'Posted',
              ),
              Tab(
                icon: Icon(Icons.check),
                text: 'Applied',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: const [
              // Posted 任務歷史
              _TaskHistoryList(type: 'posted'),
              // Applied 任務歷史
              _TaskHistoryList(type: 'applied'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskHistoryList extends StatefulWidget {
  final String type;
  const _TaskHistoryList({required this.type});

  @override
  State<_TaskHistoryList> createState() => _TaskHistoryListState();
}

class _TaskHistoryListState extends State<_TaskHistoryList> {
  List<Map<String, dynamic>> _tasks = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _currentPage = 1;
  bool _hasNextPage = false;
  int _unreviewedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTaskHistory();
  }

  Future<void> _loadTaskHistory({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _currentPage = 1;
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final role = widget.type == 'posted' ? 'poster' : 'acceptor';
      final response = await TaskHistoryApi.getTaskHistory(
        role: role,
        page: _currentPage,
        perPage: 20,
      );

      if (response['success'] == true) {
        final data = response['data'];
        setState(() {
          if (isRefresh) {
            _tasks = List<Map<String, dynamic>>.from(data['tasks']);
          } else {
            _tasks.addAll(List<Map<String, dynamic>>.from(data['tasks']));
          }
          _hasNextPage = data['pagination']['has_next'] ?? false;
          _unreviewedCount = data['stats']['unreviewed_count'] ?? 0;
          _isLoading = false;
        });
      } else {
        throw Exception(response['message'] ?? 'Failed to load task history');
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreTasks() async {
    if (!_hasNextPage || _isLoading) return;

    setState(() {
      _currentPage++;
      _isLoading = true;
    });

    await _loadTaskHistory();
  }

  void _onReviewSubmitted() {
    // 刷新列表
    _loadTaskHistory(isRefresh: true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading && _tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null && _tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => _loadTaskHistory(isRefresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              widget.type == 'posted' ? Icons.assignment_outlined : Icons.check,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              widget.type == 'posted'
                  ? 'No posted tasks yet'
                  : 'No applied tasks yet',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.type == 'posted'
                  ? 'Start by creating your first task'
                  : 'Browse available tasks to get started',
              style: TextStyle(color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _loadTaskHistory(isRefresh: true),
      child: Column(
        children: [
          // 統計資訊
          if (_unreviewedCount > 0)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.rate_review, color: Colors.orange[700]),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'You have $_unreviewedCount task${_unreviewedCount > 1 ? 's' : ''} waiting for review',
                      style: TextStyle(
                        color: Colors.orange[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 任務列表
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _tasks.length + (_hasNextPage ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _tasks.length) {
                  // 載入更多按鈕
                  return Padding(
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : ElevatedButton(
                              onPressed: _loadMoreTasks,
                              child: const Text('Load More'),
                            ),
                    ),
                  );
                }

                final task = _tasks[index];
                return _TaskHistoryCard(
                  task: task,
                  type: widget.type,
                  onReviewSubmitted: _onReviewSubmitted,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskHistoryCard extends StatelessWidget {
  final Map<String, dynamic> task;
  final String type;
  final VoidCallback onReviewSubmitted;

  const _TaskHistoryCard({
    required this.task,
    required this.type,
    required this.onReviewSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final canReview = task['can_review'] == 1;
    final hasReviewed = type == 'posted'
        ? task['has_reviewed_acceptor'] == 1
        : task['has_reviewed_poster'] == 1;
    final receivedRating =
        type == 'posted' ? task['received_rating'] : task['received_rating'];

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 任務標題和狀態
            Row(
              children: [
                Expanded(
                  child: Text(
                    task['title'] ?? 'Untitled Task',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(task['status_code']),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task['status_name'] ?? 'Unknown',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // 任務詳情
            if (task['description'] != null)
              Text(
                task['description'],
                style: TextStyle(color: Colors.grey[600]),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            const SizedBox(height: 8),

            // 對方資訊
            if (type == 'posted' && task['acceptor_name'] != null)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Applied by: ${task['acceptor_name']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              )
            else if (type == 'applied' && task['poster_name'] != null)
              Row(
                children: [
                  Icon(Icons.person, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Posted by: ${task['poster_name']}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            // 底部資訊
            Row(
              children: [
                // 獎勵點數
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${task['reward_points']} pts',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // 評價狀態
                if (receivedRating != null)
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 16),
                      Text(
                        receivedRating.toString(),
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),

                const Spacer(),

                // 評價按鈕
                if (canReview && !hasReviewed)
                  QuickReviewButton(
                    taskId: task['id'],
                    taskerId: type == 'posted'
                        ? task['acceptor_id'].toString()
                        : task['poster_id'].toString(),
                    taskerName: type == 'posted'
                        ? task['acceptor_name'] ?? 'Unknown'
                        : task['poster_name'] ?? 'Unknown',
                    taskTitle: task['title'] ?? 'Untitled Task',
                    onReviewSubmitted: onReviewSubmitted,
                  )
                else if (hasReviewed)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Text(
                      'Reviewed',
                      style: TextStyle(
                        color: Colors.green[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
              ],
            ),

            // 時間
            const SizedBox(height: 8),
            Text(
              'Updated: ${_formatDate(task['updated_at'])}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String? statusCode) {
    switch (statusCode) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'in_progress':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return 'Unknown';

    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return dateString;
    }
  }
}
