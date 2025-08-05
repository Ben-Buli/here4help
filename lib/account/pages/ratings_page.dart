import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/services/theme_config_manager.dart';

class RatingsPage extends StatefulWidget {
  const RatingsPage({super.key});

  @override
  State<RatingsPage> createState() => _RatingsPageState();
}

class _RatingsPageState extends State<RatingsPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 假資料
  final List<Map<String, dynamic>> postedTasks = [
    {
      'title': 'Open Bank Account',
      'date': 'Feb 15, 2024',
      'price': 1500,
      'rating': 4.5,
      'review': 'Great Service',
      'reviewed': true,
    },
    {
      'title': 'Document translate',
      'date': 'Jan 20, 2024',
      'price': 900,
      'rating': 4.0,
      'review': 'Super great Service',
      'reviewed': true,
    },
    {
      'title': 'mobile plan apply',
      'date': 'Feb 15, 2024',
      'price': 1000,
      'rating': null,
      'review': null,
      'reviewed': false,
    },
  ];

  final List<Map<String, dynamic>> acceptedTasks = [
    {
      'title': 'Open Bank Account',
      'date': 'Feb 15, 2024',
      'price': 1500,
      'rating': 4.5,
      'review': 'Great Service',
      'reviewed': true,
    },
    {
      'title': 'Document translate',
      'date': 'Jan 20, 2024',
      'price': 900,
      'rating': 4.0,
      'review': 'Super great Service',
      'reviewed': true,
    },
    {
      'title': 'mobile plan apply',
      'date': 'Feb 15, 2024',
      'price': 1000,
      'rating': null,
      'review': null,
      'reviewed': false,
    },
  ];

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

  void _showReviewDialog(Map<String, dynamic> task, bool isPosted) {
    double? selectedRating;
    final TextEditingController reviewController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Text(task['title']),
            const Spacer(),
            Text(task['date'],
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 星等
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                return IconButton(
                  icon: Icon(
                    Icons.star,
                    color: (selectedRating != null && selectedRating! > i)
                        ? Colors.amber
                        : Colors.grey[300],
                  ),
                  onPressed: () {
                    setState(() {
                      selectedRating = i + 1.0;
                    });
                    // 立即刷新 dialog
                    Navigator.of(context).pop();
                    _showReviewDialog(task, isPosted);
                  },
                );
              }),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: reviewController,
              decoration: const InputDecoration(
                hintText: 'Add your view (optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              // TODO: 儲存評分與評論
              Navigator.pop(context);
              setState(() {
                task['rating'] = selectedRating ?? 5.0;
                task['review'] = reviewController.text;
                task['reviewed'] = true;
              });
            },
            child: const Text('save'),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, bool isPosted) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: ListTile(
        leading: const Icon(Icons.event_note, color: AppColors.primary),
        title: Row(
          children: [
            Expanded(
              child: Text(
                task['title'],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            if (task['rating'] != null)
              Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 18),
                  Text('${task['rating']}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task['date']),
            if (task['review'] != null)
              Text(task['review'],
                  style: const TextStyle(color: Colors.black87)),
            Consumer<ThemeConfigManager>(
              builder: (context, themeManager, child) {
                return Text('${task['price']} NTD',
                    style:
                        TextStyle(color: themeManager.currentTheme.secondary));
              },
            ),
            if (!task['reviewed'])
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton(
                  onPressed: () => _showReviewDialog(task, isPosted),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isPosted ? AppColors.primary : Colors.grey,
                    minimumSize: const Size(80, 32),
                  ),
                  child: Text(isPosted ? 'Review' : 'Awaiting review'),
                ),
              ),
          ],
        ),
        onTap: () {
          // 點擊可檢視詳細評價
          if (task['reviewed']) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(task['title']),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.star, color: Colors.amber),
                        Text('${task['rating']}'),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(task['review'] ?? ''),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('close'),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
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
                text: 'Accepted',
              ),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Posted
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: postedTasks.length,
                itemBuilder: (context, index) {
                  final task = postedTasks[index];
                  return _buildTaskCard(task, true);
                },
              ),
              // Accepted
              ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: acceptedTasks.length,
                itemBuilder: (context, index) {
                  final task = acceptedTasks[index];
                  return _buildTaskCard(task, false);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
