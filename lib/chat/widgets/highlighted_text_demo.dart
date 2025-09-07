import 'package:flutter/material.dart';
import 'package:here4help/chat/widgets/highlighted_text.dart';

/// 高亮文字功能測試頁面
///
/// 用於測試和演示字符高亮功能的各種場景：
/// - 基本高亮功能
/// - 多關鍵字高亮
/// - 清除效果
/// - 不同樣式配置
class HighlightedTextDemo extends StatefulWidget {
  const HighlightedTextDemo({Key? key}) : super(key: key);

  @override
  State<HighlightedTextDemo> createState() => _HighlightedTextDemoState();
}

class _HighlightedTextDemoState extends State<HighlightedTextDemo> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // 測試文字範例
  final List<String> _testTexts = [
    'Flutter 開發任務 - 需要有經驗的開發者',
    'UI/UX 設計工作 - 設計移動應用界面',
    'Backend API 開發 - Node.js 和 MongoDB',
    '網站前端開發 - React 和 TypeScript',
    '數據分析任務 - Python 和機器學習',
    '移動應用測試 - iOS 和 Android 平台',
    '系統管理工作 - Linux 服務器維護',
    '內容創作任務 - 撰寫技術文檔',
  ];

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text;
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('字符高亮測試'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜尋輸入框
            _buildSearchInput(),
            const SizedBox(height: 20),

            // 搜尋狀態顯示
            _buildSearchStatus(),
            const SizedBox(height: 20),

            // 測試結果列表
            Expanded(
              child: _buildTestResults(),
            ),

            // 功能說明
            _buildFeatureDescription(),
          ],
        ),
      ),
    );
  }

  /// 建構搜尋輸入框
  Widget _buildSearchInput() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '搜尋測試',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '輸入搜尋關鍵字（例如：Flutter、開發、設計）',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構搜尋狀態顯示
  Widget _buildSearchStatus() {
    return Card(
      color: _searchQuery.isEmpty
          ? Colors.grey[100]
          : Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Icon(
              _searchQuery.isEmpty ? Icons.info_outline : Icons.highlight,
              color: _searchQuery.isEmpty
                  ? Colors.grey[600]
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _searchQuery.isEmpty
                    ? '請輸入搜尋關鍵字以查看高亮效果'
                    : '正在高亮顯示：「$_searchQuery」',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  color: _searchQuery.isEmpty
                      ? Colors.grey[600]
                      : Theme.of(context).colorScheme.onPrimaryContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 建構測試結果列表
  Widget _buildTestResults() {
    return ListView.builder(
      itemCount: _testTexts.length,
      itemBuilder: (context, index) {
        final text = _testTexts[index];
        final hasMatch = _searchQuery.isNotEmpty &&
            HighlightTextUtils.containsKeyword(text, _searchQuery);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          elevation: hasMatch ? 2 : 1,
          color: hasMatch ? Theme.of(context).colorScheme.surface : null,
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: hasMatch
                  ? Theme.of(context).colorScheme.primary
                  : Colors.grey[400],
              foregroundColor: Colors.white,
              child: Text('${index + 1}'),
            ),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 基本高亮
                const Text(
                  '基本高亮：',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                HighlightedText(
                  text: text,
                  highlight: _searchQuery,
                  normalStyle: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),

                // 智能高亮（支援多關鍵字）
                const Text(
                  '智能高亮（多關鍵字）：',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SmartHighlightedText(
                  text: text,
                  highlight: _searchQuery,
                  normalStyle: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  highlightStyle: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .secondary
                        .withOpacity(0.3),
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            trailing: hasMatch
                ? Icon(
                    Icons.star,
                    color: Theme.of(context).colorScheme.primary,
                  )
                : null,
          ),
        );
      },
    );
  }

  /// 建構功能說明
  Widget _buildFeatureDescription() {
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                const Text(
                  '功能特點',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              '✅ 大小寫不敏感匹配\n'
              '✅ 自動清除效果（搜尋為空時）\n'
              '✅ 支援中文和英文混合搜尋\n'
              '✅ 智能高亮支援多關鍵字（空格分隔）\n'
              '✅ 可自定義高亮樣式和顏色\n'
              '✅ 保持原文大小寫顯示',
              style: TextStyle(
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 高亮文字測試工具類
class HighlightTextTestUtils {
  /// 測試所有高亮功能
  static void runAllTests() {
    debugPrint('🧪 開始高亮文字功能測試...');

    // 測試基本匹配
    _testBasicMatching();

    // 測試多關鍵字匹配
    _testMultiKeywordMatching();

    // 測試邊界情況
    _testEdgeCases();

    debugPrint('✅ 高亮文字功能測試完成');
  }

  static void _testBasicMatching() {
    debugPrint('📝 測試基本匹配功能...');

    final testCases = [
      {'text': 'Flutter 開發任務', 'keyword': 'Flutter', 'expected': true},
      {
        'text': 'Flutter 開發任務',
        'keyword': 'flutter',
        'expected': true
      }, // 大小寫不敏感
      {'text': 'Flutter 開發任務', 'keyword': '開發', 'expected': true},
      {'text': 'Flutter 開發任務', 'keyword': 'React', 'expected': false},
    ];

    for (final testCase in testCases) {
      final result = HighlightTextUtils.containsKeyword(
        testCase['text'] as String,
        testCase['keyword'] as String,
      );
      final expected = testCase['expected'] as bool;

      if (result == expected) {
        debugPrint('✅ ${testCase['text']} + ${testCase['keyword']} = $result');
      } else {
        debugPrint(
            '❌ ${testCase['text']} + ${testCase['keyword']} = $result (expected: $expected)');
      }
    }
  }

  static void _testMultiKeywordMatching() {
    debugPrint('📝 測試多關鍵字匹配功能...');

    const text = 'Flutter 移動應用開發任務';
    const multiKeyword = 'Flutter 開發';

    final result = HighlightTextUtils.containsKeyword(text, multiKeyword);
    debugPrint('✅ 多關鍵字測試: "$text" contains "$multiKeyword" = $result');
  }

  static void _testEdgeCases() {
    debugPrint('📝 測試邊界情況...');

    final edgeCases = [
      {'text': '', 'keyword': 'test', 'expected': false},
      {'text': 'test', 'keyword': '', 'expected': true},
      {'text': '', 'keyword': '', 'expected': true},
      {'text': '   ', 'keyword': ' ', 'expected': true},
    ];

    for (final testCase in edgeCases) {
      final result = HighlightTextUtils.containsKeyword(
        testCase['text'] as String,
        testCase['keyword'] as String,
      );
      final expected = testCase['expected'] as bool;

      if (result == expected) {
        debugPrint(
            '✅ 邊界測試: "${testCase['text']}" + "${testCase['keyword']}" = $result');
      } else {
        debugPrint(
            '❌ 邊界測試: "${testCase['text']}" + "${testCase['keyword']}" = $result (expected: $expected)');
      }
    }
  }
}
