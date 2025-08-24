import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/models/task_card.dart';
import 'package:here4help/task/services/ratings_service.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Posted tasks state
  List<TaskCard> _postedTasks = [];
  bool _isLoadingPosted = true;
  String? _postedError;

  // Accepted tasks state
  List<TaskCard> _acceptedTasks = [];
  bool _isLoadingAccepted =
      false; // start as not loading; trigger on tab switch
  String? _acceptedError;

  // Not selected applications state
  List<TaskCard> _notSelectedTasks = [];
  bool _isLoadingNotSelected =
      false; // start as not loading; trigger on tab switch
  String? _notSelectedError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // 改為3個分頁
    _tabController.addListener(_onTabChanged);
    _loadPostedTasks();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.index == 0 && _postedTasks.isEmpty) {
      _loadPostedTasks();
    } else if (_tabController.index == 1 && _acceptedTasks.isEmpty) {
      _loadAcceptedTasks();
    } else if (_tabController.index == 2 && _notSelectedTasks.isEmpty) {
      _loadNotSelectedTasks();
    }
  }

  Future<void> _loadPostedTasks({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _postedTasks.clear();
        _isLoadingPosted = true;
        _postedError = null;
      });
    }

    try {
      final result = await RatingsService.fetchPosted(1);
      setState(() {
        _postedTasks = result.items;
        _isLoadingPosted = false;
        _postedError = null;
      });
    } catch (e) {
      setState(() {
        _postedError = e.toString();
        _isLoadingPosted = false;
      });
    }
  }

  Future<void> _loadAcceptedTasks({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _acceptedTasks.clear();
        _isLoadingAccepted = true;
        _acceptedError = null;
      });
    }
    if (!refresh) {
      setState(() {
        _isLoadingAccepted = true;
        _acceptedError = null;
      });
    }

    try {
      final result = await RatingsService.fetchAccepted(1);
      setState(() {
        _acceptedTasks = result.items;
        _isLoadingAccepted = false;
        _acceptedError = null;
      });
    } catch (e) {
      setState(() {
        _acceptedError = e.toString();
        _isLoadingAccepted = false;
      });
    }
  }

  Future<void> _loadNotSelectedTasks({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _notSelectedTasks.clear();
        _isLoadingNotSelected = true;
        _notSelectedError = null;
      });
    }
    if (!refresh) {
      setState(() {
        _isLoadingNotSelected = true;
        _notSelectedError = null;
      });
    }

    try {
      final result = await RatingsService.fetchNotSelected(1);
      setState(() {
        _notSelectedTasks = result.items;
        _isLoadingNotSelected = false;
        _notSelectedError = null;
      });
    } catch (e) {
      setState(() {
        _notSelectedError = e.toString();
        _isLoadingNotSelected = false;
      });
    }
  }

  void _showReviewDialog(TaskCard task) {
    double rating = 1.0;
    final commentController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Rate: ${task.title}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(task.taskDate.toString().split(' ')[0]),
                  const Spacer(),
                  Text('${task.rewardPoint} points',
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              const SizedBox(height: 16),
              const Text('Rating:'),
              const SizedBox(height: 8),
              RatingBar.builder(
                initialRating: rating,
                minRating: 1,
                direction: Axis.horizontal,
                allowHalfRating: false,
                itemCount: 5,
                itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
                itemBuilder: (context, _) => const Icon(
                  Icons.star,
                  color: Colors.amber,
                ),
                onRatingUpdate: (newRating) {
                  setState(() {
                    rating = newRating;
                  });
                },
              ),
              const SizedBox(height: 16),
              const Text('Comment:'),
              const SizedBox(height: 8),
              TextField(
                controller: commentController,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Please share your experience...',
                ),
                maxLines: 3,
              ),
              if (errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final comment = commentController.text.trim();
                if (comment.isEmpty) {
                  setState(() {
                    errorMessage = 'Comment is required';
                  });
                  return;
                }

                try {
                  await RatingsService.createRating(
                    task.taskId,
                    rating.toInt(),
                    comment,
                  );

                  if (mounted) {
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('Rating submitted successfully')),
                    );
                    // Refresh the current tab
                    _loadPostedTasks(refresh: true);
                  }
                } catch (e) {
                  setState(() {
                    errorMessage = e.toString();
                  });
                }
              },
              child: const Text('Submit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showReadOnlyRatingDialog(TaskRating rating) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rating'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RatingBarIndicator(
              rating: rating.rating.toDouble(),
              itemBuilder: (context, index) => const Icon(
                Icons.star,
                color: Colors.amber,
              ),
              itemCount: 5,
              itemSize: 30,
            ),
            const SizedBox(height: 16),
            Text(
              'Comment:',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Text(rating.comment),
            const SizedBox(height: 16),
            Text(
              'Rated by: ${rating.rater.name}${rating.rater.isYou ? ' (You)' : ''}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Created at: ${rating.createdAt.toString()}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTaskSummaryDialog(TaskCard task) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Task Summary'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Title: ${task.title}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Date: ${task.taskDate.toString().split(' ')[0]}'),
            const SizedBox(height: 8),
            Text('Reward: ${task.rewardPoint} points'),
            const SizedBox(height: 8),
            Text('Status: ${task.statusName}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(TaskCard task, TaskCardType type) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ListTile(
        leading:
            const Icon(Icons.calendar_today_outlined, color: AppColors.primary),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task.title,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            _buildActionArea(task, type),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.taskDate.toString().split(' ')[0]),
            Consumer<ThemeConfigManager>(
              builder: (context, themeManager, child) {
                return Text('${task.rewardPoint} points',
                    style:
                        TextStyle(color: themeManager.currentTheme.secondary));
              },
            ),
          ],
        ),
        onTap: () {
          if (type == TaskCardType.notSelected) {
            _showTaskSummaryDialog(task);
          } else if (task.hasRating) {
            _showReadOnlyRatingDialog(task.rating!);
          }
        },
      ),
    );
  }

  Widget _buildActionArea(TaskCard task, TaskCardType type) {
    switch (type) {
      case TaskCardType.posted:
        return _buildPostedActionArea(task);
      case TaskCardType.accepted:
        return _buildAcceptedActionArea(task);
      case TaskCardType.notSelected:
        return _buildNotSelectedActionArea(task);
    }
  }

  Widget _buildPostedActionArea(TaskCard task) {
    if (task.isUnfinished) {
      // Show status pill
      return _buildStatusPill(task.statusName);
    } else if (task.isCompleted) {
      if (task.hasRating) {
        // Show rating with star
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            Text(
              task.rating!.rating.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      } else if (task.canRate) {
        // Show "Rate" button
        return ElevatedButton(
          onPressed: () => _showReviewDialog(task),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            minimumSize: const Size(60, 32),
          ),
          child: const Text('Rate'),
        );
      } else {
        // Show "Awaiting review" for completed tasks without rating that can't be rated
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Awaiting review',
            style: TextStyle(fontSize: 10),
          ),
        );
      }
    }

    return _buildStatusPill(task.statusName);
  }

  Widget _buildAcceptedActionArea(TaskCard task) {
    if (task.isUnfinished) {
      return _buildStatusPill(task.statusName);
    } else if (task.isCompleted) {
      if (task.hasRating) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star, color: Colors.amber, size: 18),
            Text(
              task.rating!.rating.toString(),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Text(
            'Awaiting review',
            style: TextStyle(fontSize: 10),
          ),
        );
      }
    }

    return _buildStatusPill(task.statusName);
  }

  Widget _buildNotSelectedActionArea(TaskCard task) {
    return _buildStatusPill(task.statusName);
  }

  Widget _buildStatusPill(String statusName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        statusName,
        style: const TextStyle(
          color: Color(0xFF374151),
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildTabContent(List<TaskCard> tasks, bool isLoading, String? error,
      TaskCardType type, VoidCallback onRefresh) {
    if (isLoading && tasks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && tasks.isEmpty) {
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
              'Failed to load data',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRefresh,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (tasks.isEmpty) {
      return const Center(
        child: Text('No relative tasks found.'),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: tasks.length,
        itemBuilder: (context, index) {
          return _buildTaskCard(tasks[index], type);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 保持原有的架構，只回傳內容，不包 AppScaffold
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
                text: 'Accepted',
              ),
              Tab(
                icon: Icon(Icons.cancel_outlined),
                text: 'Not Selected',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Posted
              _buildTabContent(
                _postedTasks,
                _isLoadingPosted,
                _postedError,
                TaskCardType.posted,
                () => _loadPostedTasks(refresh: true),
              ),
              // Accepted
              _buildTabContent(
                _acceptedTasks,
                _isLoadingAccepted,
                _acceptedError,
                TaskCardType.accepted,
                () => _loadAcceptedTasks(refresh: true),
              ),
              // Not Selected
              _buildTabContent(
                _notSelectedTasks,
                _isLoadingNotSelected,
                _notSelectedError,
                TaskCardType.notSelected,
                () => _loadNotSelectedTasks(refresh: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum TaskCardType {
  posted,
  accepted,
  notSelected,
}
