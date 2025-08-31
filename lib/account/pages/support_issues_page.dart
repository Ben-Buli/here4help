import 'package:flutter/material.dart';

class SupportIssuesPage extends StatefulWidget {
  const SupportIssuesPage({super.key});

  @override
  State<SupportIssuesPage> createState() => _SupportIssuesPageState();
}

class _SupportIssuesPageState extends State<SupportIssuesPage> {
  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _items = const [];
  String _filter = 'all';

  final List<Map<String, String>> _filters = const [
    {'key': 'all', 'label': 'All'},
    {'key': 'support', 'label': 'Support'},
    {'key': 'dispute', 'label': 'Dispute'},
  ];

  @override
  void initState() {
    super.initState();
    _loadIssues();
  }

  Future<void> _loadIssues() async {
    if (_isLoading) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // TODO: 串接 GET /support/issues（目前使用假資料骨架，避免阻塞）
      await Future<void>.delayed(const Duration(milliseconds: 200));
      final mock = List.generate(6, (i) {
        return {
          'room_id': 'room_$i',
          'title': i.isEven ? 'Payment Issue #$i' : 'Dispute for Task #$i',
          'type': i.isEven ? 'support' : 'dispute',
          'status':
              i % 3 == 0 ? 'open' : (i % 3 == 1 ? 'in_progress' : 'resolved'),
          'unread': i % 2,
          'updated_at': DateTime.now()
              .subtract(Duration(minutes: i * 7))
              .toIso8601String(),
        };
      });
      setState(() {
        _items = mock;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _filtered {
    if (_filter == 'all') return _items;
    return _items.where((e) => e['type'] == _filter).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Support Issues'),
        actions: [
          IconButton(onPressed: _loadIssues, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildFilterBar(context),
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              _error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _buildList(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: _filters.map((f) {
          final selected = _filter == f['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(f['label'] ?? ''),
              selected: selected,
              onSelected: (_) => setState(() => _filter = f['key'] ?? 'all'),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(BuildContext context) {
    if (_filtered.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text('No issues found.'),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _filtered.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = _filtered[index];
        return ListTile(
          leading: Icon(
              item['type'] == 'support' ? Icons.support_agent : Icons.gavel),
          title: Text(
            item['title'] ?? '',
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
          subtitle: Text('${item['type']} · ${item['status']}'),
          trailing: _buildUnread(item['unread'] as int? ?? 0),
          onTap: () {
            // 導向 /account/support/chat，使用 extra 傳遞 roomId
            // 實際 router 由 shell_pages.dart 接收 extra
            Navigator.of(context).pushNamed('/account/support/chat');
          },
        );
      },
    );
  }

  Widget _buildUnread(int unread) {
    if (unread <= 0) return const SizedBox.shrink();
    final cap = unread > 99 ? '99+' : '$unread';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(12),
      ),
      child:
          Text(cap, style: const TextStyle(color: Colors.white, fontSize: 12)),
    );
  }
}
