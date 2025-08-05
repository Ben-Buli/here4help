import 'package:flutter/material.dart';
import 'package:here4help/constants/app_colors.dart';

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
          child: Row(
            children: [
              const Text(
                'Credit Score',
                style: TextStyle(
                  color: Color(0xFF2563EB),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
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
            children: const [
              // Posted 任務歷史
              _TaskHistoryList(type: 'posted'),
              // Accepted 任務歷史
              _TaskHistoryList(type: 'accepted'),
            ],
          ),
        ),
      ],
    );
  }
}

class _TaskHistoryList extends StatelessWidget {
  final String type;
  const _TaskHistoryList({required this.type});

  @override
  Widget build(BuildContext context) {
    // 這裡可根據 type 載入不同資料
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        ListTile(
          leading: Icon(
            type == 'posted' ? Icons.assignment_outlined : Icons.check,
            color: AppColors.primary,
          ),
          title: Text(
            type == 'posted' ? 'Posted Task Example' : 'Accepted Task Example',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: const Text('Task details here...'),
        ),
        // ...可根據資料動態產生
      ],
    );
  }
}
