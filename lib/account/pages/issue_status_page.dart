import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/api/support_event_api.dart';
import 'package:here4help/widgets/support_event_card.dart';

/// 客服事件狀態頁面
///
/// 整合原有的 issue status 顯示與新的客服事件系統
/// 支援即時更新與狀態篩選
class IssueStatusPage extends StatefulWidget {
  final String? chatRoomId;
  final String? title;
  // 保留原有的靜態顯示參數以向後相容
  final bool hasIssue;
  final int status; // 0: Submitted, 1: In Progress, 2: Resolved
  final String submittedDate;

  const IssueStatusPage({
    super.key,
    this.chatRoomId,
    this.title,
    this.hasIssue = true,
    this.status = 1,
    this.submittedDate = 'April 8, 2024',
  });

  @override
  State<IssueStatusPage> createState() => _IssueStatusPageState();
}

class _IssueStatusPageState extends State<IssueStatusPage> {
  List<Map<String, dynamic>> _events = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _selectedFilter = 'all';

  final List<String> _filterOptions = [
    'all',
    'submitted',
    'in_progress',
  ];

  @override
  void initState() {
    super.initState();
    // 載入使用者的客服事件
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 實現獲取使用者所有客服事件的 API
      final events = await SupportEventApi.getUserEvents();

      if (mounted) {
        setState(() {
          _events = events;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filteredEvents {
    // 只顯示非 resolved 的事件（活躍事件）
    final activeEvents =
        _events.where((event) => event['status'] != 'resolved').toList();

    if (_selectedFilter == 'all') {
      return activeEvents;
    }
    return activeEvents
        .where((event) => event['status'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Support Cases'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadEvents,
          ),
        ],
      ),
      body: Column(
        children: [
          // 篩選器（僅顯示活躍狀態）
          _buildFilterBar(),

          // 事件列表
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      // 新增 FAB 建立客服事件
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateIssueDialog,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filterOptions.map((filter) {
            final isSelected = _selectedFilter == filter;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(_getFilterDisplayName(filter)),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                  }
                },
                backgroundColor: Colors.grey[200],
                selectedColor:
                    Theme.of(context).primaryColor.withValues(alpha: 0.2),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildEventsList() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
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
              'Failed to load events',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadEvents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final filteredEvents = _filteredEvents;

    if (filteredEvents.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_note,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _selectedFilter == 'all'
                  ? 'No issues pending at the moment'
                  : 'No ${_getFilterDisplayName(_selectedFilter).toLowerCase()} issues',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the + button to create a new issue',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadEvents,
      child: ListView.builder(
        itemCount: filteredEvents.length,
        itemBuilder: (context, index) {
          final event = filteredEvents[index];
          return SupportEventCard(
            event: event,
            onTap: () => _showEventDetail(event),
            onClose: () => _closeEvent(event),
            onRate: () => _rateEvent(event),
          );
        },
      ),
    );
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'all':
        return 'All';
      case 'submitted':
        return 'Submitted';
      case 'in_progress':
        return 'In Progress';
      default:
        return filter;
    }
  }

  /// 顯示建立客服事件的 Dialog
  void _showCreateIssueDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateIssueDialog(
        onCreated: (roomId) {
          // 重新載入事件列表
          _loadEvents();
          // 導航至聊天室
          Navigator.of(context).pushNamed('/account/support/chat', arguments: {
            'room_id': roomId,
          });
        },
      ),
    );
  }

  void _showEventDetail(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => _EventDetailDialog(event: event),
    );
  }

  void _closeEvent(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => _CloseEventDialog(
        event: event,
        onClosed: _loadEvents,
      ),
    );
  }

  void _rateEvent(Map<String, dynamic> event) {
    showDialog(
      context: context,
      builder: (context) => _RateEventDialog(
        event: event,
        onRated: _loadEvents,
      ),
    );
  }
}

/// 事件詳情對話框
class _EventDetailDialog extends StatelessWidget {
  final Map<String, dynamic> event;

  const _EventDetailDialog({required this.event});

  @override
  Widget build(BuildContext context) {
    final logs = event['logs'] as List<dynamic>? ?? [];

    return AlertDialog(
      title: Text(event['title'] ?? 'Event Detail'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // 描述
            if (event['description'] != null &&
                event['description'].isNotEmpty) ...[
              const Text(
                'Description:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(event['description']),
              const SizedBox(height: 16),
            ],

            // 狀態歷程
            const Text(
              'Status History:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...logs.map((log) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.circle,
                        size: 8,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${log['old_status'] ?? 'Initial'} → ${log['new_status']}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w500),
                            ),
                            if (log['admin_name'] != null)
                              Text(
                                'by ${log['admin_name']}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            Text(
                              _formatDateTime(log['created_at']),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),

            // 評分與評論
            if (event['rating'] != null) ...[
              const SizedBox(height: 16),
              const Text(
                'Customer Rating:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  ...List.generate(5, (index) {
                    return Icon(
                      index < event['rating'] ? Icons.star : Icons.star_border,
                      size: 20,
                      color: Colors.amber,
                    );
                  }),
                  const SizedBox(width: 8),
                  Text('${event['rating']}/5'),
                ],
              ),
              if (event['review'] != null && event['review'].isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(event['review']),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }

  String _formatDateTime(String? dateTimeString) {
    if (dateTimeString == null) return '';

    try {
      final dateTime = DateTime.parse(dateTimeString);
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dateTimeString;
    }
  }
}

/// 結案事件對話框
class _CloseEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onClosed;

  const _CloseEventDialog({
    required this.event,
    required this.onClosed,
  });

  @override
  State<_CloseEventDialog> createState() => _CloseEventDialogState();
}

class _CloseEventDialogState extends State<_CloseEventDialog> {
  int? _rating;
  final TextEditingController _reviewController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitClose() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupportEventApi.closeEvent(
        eventId: widget.event['id'].toString(),
        rating: _rating,
        review: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Event closed successfully')),
        );
        widget.onClosed();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to close event: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Close Event'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Event: ${widget.event['title']}'),
            const SizedBox(height: 16),
            const Text(
              'Rate this service (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < (_rating ?? 0) ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Additional comments (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitClose,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Close Event'),
        ),
      ],
    );
  }
}

/// 評分事件對話框
class _RateEventDialog extends StatefulWidget {
  final Map<String, dynamic> event;
  final VoidCallback onRated;

  const _RateEventDialog({
    required this.event,
    required this.onRated,
  });

  @override
  State<_RateEventDialog> createState() => _RateEventDialogState();
}

class _RateEventDialogState extends State<_RateEventDialog> {
  int _rating = 5;
  final TextEditingController _reviewController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _reviewController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    setState(() {
      _isLoading = true;
    });

    try {
      await SupportEventApi.submitRating(
        eventId: widget.event['id'].toString(),
        rating: _rating,
        review: _reviewController.text.trim().isNotEmpty
            ? _reviewController.text.trim()
            : null,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rating submitted successfully')),
        );
        widget.onRated();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit rating: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Rate Service'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Event: ${widget.event['title']}'),
            const SizedBox(height: 16),
            const Text(
              'How would you rate this service?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  icon: Icon(
                    index < _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _rating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 16),
            const Text(
              'Additional comments (optional):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _reviewController,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'Share your experience...',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitRating,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Submit Rating'),
        ),
      ],
    );
  }
}

/// 建立客服事件 Dialog
class _CreateIssueDialog extends StatefulWidget {
  final Function(String roomId) onCreated;

  const _CreateIssueDialog({
    required this.onCreated,
  });

  @override
  State<_CreateIssueDialog> createState() => _CreateIssueDialogState();
}

class _CreateIssueDialogState extends State<_CreateIssueDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitIssue() async {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a description')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final result = await SupportEventApi.createIssue(
        title: title,
        description: description,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Support case created successfully')),
        );
        widget.onCreated(result['room_id']);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create support case: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Support Case'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Subject / Title *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                hintText: 'Brief description of your issue',
                border: OutlineInputBorder(),
              ),
              maxLength: 100,
            ),
            const SizedBox(height: 16),
            const Text(
              'Description *',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                hintText: 'Please describe your issue in detail',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              maxLength: 500,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitIssue,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Create Case'),
        ),
      ],
    );
  }
}
