import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';
import 'package:here4help/services/theme_config_manager.dart';

/// 搜索和篩選組件
/// 從原 ChatListPage 中抽取的搜索欄和排序功能
class SearchFilterWidget extends StatefulWidget {
  const SearchFilterWidget({super.key});

  @override
  State<SearchFilterWidget> createState() => _SearchFilterWidgetState();
}

class _SearchFilterWidgetState extends State<SearchFilterWidget> {
  late TextEditingController _searchController;
  late FocusNode _searchFocusNode;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _searchFocusNode = FocusNode();

    // 監聽 Provider 變化來同步 TextField
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatListProvider>();
      _searchController.text = chatProvider.searchQuery;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ChatListProvider, ThemeConfigManager>(
      builder: (context, chatProvider, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        // 當分頁切換時，同步搜尋欄內容
        if (_searchController.text != chatProvider.searchQuery) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _searchController.text = chatProvider.searchQuery;
          });
        }

        return Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            children: [
              // 搜尋欄
              TextField(
                controller: _searchController,
                focusNode: _searchFocusNode,
                onChanged: (value) {
                  chatProvider.updateSearchQuery(value.toLowerCase());
                },
                onEditingComplete: () {
                  _searchFocusNode.unfocus();
                },
                decoration: InputDecoration(
                  hintText: 'Search task titles...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (chatProvider.searchQuery.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            chatProvider.updateSearchQuery('');
                            _searchFocusNode.unfocus();
                          },
                          tooltip: 'Clear',
                        ),
                      IconButton(
                        icon: Icon(
                          Icons.filter_list,
                          color: chatProvider.hasActiveFilters
                              ? theme.primary
                              : null,
                        ),
                        tooltip: 'Filter options',
                        onPressed: () {
                          // TODO: 實現篩選選項對話框
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: theme.primary),
                        tooltip: 'Reset',
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          chatProvider.resetFilters();
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),

              // 排序選項區域
              Container(
                height: 32,
                margin: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    // 更新時間排序
                    _buildCompactSortChip(
                      context: context,
                      chatProvider: chatProvider,
                      theme: theme,
                      label: 'Time',
                      sortBy: 'updated_time',
                      icon: Icons.update,
                    ),
                    const SizedBox(width: 8),

                    // 應徵人數排序（僅限 Posted Tasks 分頁）
                    if (chatProvider.currentTabIndex == 0) ...[
                      _buildCompactSortChip(
                        context: context,
                        chatProvider: chatProvider,
                        theme: theme,
                        label: 'Applicants',
                        sortBy: 'applicant_count',
                        icon: Icons.people,
                      ),
                      const SizedBox(width: 8),
                    ],

                    // 任務狀態排序
                    _buildCompactSortChip(
                      context: context,
                      chatProvider: chatProvider,
                      theme: theme,
                      label: 'Status',
                      sortBy: 'status_code',
                      icon: Icons.sort_by_alpha,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactSortChip({
    required BuildContext context,
    required ChatListProvider chatProvider,
    required dynamic theme,
    required String label,
    required String sortBy,
    required IconData icon,
  }) {
    final isActive = chatProvider.currentSortBy == sortBy;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => chatProvider.setSortOrder(sortBy),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isActive ? theme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isActive
                  ? theme.primary
                  : theme.outlineVariant.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: isActive ? theme.onPrimary : theme.onSurface,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                  color: isActive ? theme.onPrimary : theme.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                isActive
                    ? (chatProvider.sortAscending
                        ? Icons.arrow_upward
                        : Icons.arrow_downward)
                    : Icons.unfold_more,
                size: 12,
                color: isActive ? theme.onPrimary : theme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
