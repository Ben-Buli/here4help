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
    'open',
    'in_progress',
    'resolved',
    'closed_by_customer',
  ];

  @override
  void initState() {
    super.initState();
    // 如果有 chatRoomId，載入客服事件；否則顯示靜態狀態
    if (widget.chatRoomId != null) {
      _loadEvents();
    }
  }

  Future<void> _loadEvents() async {
    if (_isLoading || widget.chatRoomId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final events = await SupportEventApi.getEvents(
        chatRoomId: widget.chatRoomId!,
      );

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
    if (_selectedFilter == 'all') {
      return _events;
    }
    return _events
        .where((event) => event['status'] == _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // 如果沒有 chatRoomId，顯示原有的靜態狀態
    if (widget.chatRoomId == null) {
      return _buildLegacyIssueStatus();
    }

    // 新的客服事件系統
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title ?? 'Support Events'),
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
          // 篩選器
          _buildFilterBar(),

          // 事件列表
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
    );
  }

  /// 原有的靜態 issue status 顯示（向後相容）
  Widget _buildLegacyIssueStatus() {
    return widget.hasIssue
        ? Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildStep('Submitted', 0, widget.status,
                      date: widget.submittedDate),
                  _buildStep('In Progress', 1, widget.status),
                  _buildStep('Resolved', 2, widget.status),
                ],
              ),
            ),
          )
        : const Center(
            child: Text(
              'No issues pending at the moment.',
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
          );
  }

  Widget _buildStep(String label, int step, int current, {String? date}) {
    final isActive = current >= step;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          isActive ? Icons.radio_button_checked : Icons.radio_button_unchecked,
          color: isActive ? AppColors.primary : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: isActive ? AppColors.primary : Colors.grey,
          ),
        ),
        if (date != null)
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: Text(
              date,
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
          ),
      ],
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
                  ? 'No events found'
                  : 'No ${_getFilterDisplayName(_selectedFilter).toLowerCase()} events',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Events will appear here when they are created',
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
      case 'open':
        return 'Open';
      case 'in_progress':
        return 'In Progress';
      case 'resolved':
        return 'Resolved';
      case 'closed_by_customer':
        return 'Closed';
      default:
        return filter;
    }
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
