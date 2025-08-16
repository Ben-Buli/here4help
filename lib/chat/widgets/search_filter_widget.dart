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
                textCapitalization: TextCapitalization.sentences, // 允許大寫輸入
                keyboardType: TextInputType.text, // 確保使用文字鍵盤
                onChanged: (value) {
                  // 保持原始大小寫，讓搜尋邏輯處理大小寫不敏感匹配
                  chatProvider.updateSearchQuery(value);
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
                          _showFilterOptions(context, chatProvider, theme);
                        },
                      ),
                      IconButton(
                        icon: Icon(Icons.refresh, color: theme.primary),
                        tooltip: 'Reset',
                        onPressed: () {
                          _searchController.clear();
                          _searchFocusNode.unfocus();
                          chatProvider.resetFilters();
                          // 滾動到頂部
                          _scrollToTop();
                        },
                      ),
                    ],
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // 排序狀態提示
              if (chatProvider.searchQuery.isNotEmpty)
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: theme.primary.withValues(alpha: 0.7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        chatProvider.currentSortBy == 'relevance'
                            ? 'Sorting by relevance (recommended for search)'
                            : 'Sorting by ${chatProvider.currentSortBy.replaceAll('_', ' ')} (overridden)',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.primary.withValues(alpha: 0.7),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              // 排序選項
              Row(
                children: [
                  Text(
                    'Order by: ',
                    style: TextStyle(
                      fontSize: 12,
                      color: theme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // 相關性排序（只有有搜尋時才顯示）
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          if (chatProvider.searchQuery.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(right: 8.0),
                              child: _buildCompactSortChip(
                                context: context,
                                chatProvider: chatProvider,
                                theme: theme,
                                label: 'Relevance',
                                sortBy: 'relevance',
                                icon: Icons.search,
                              ),
                            ),
                          // 時間排序
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildCompactSortChip(
                              context: context,
                              chatProvider: chatProvider,
                              theme: theme,
                              label: 'Updated Time',
                              sortBy: 'updated_time',
                              icon: Icons.access_time,
                            ),
                          ),
                          // 狀態排序
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildCompactSortChip(
                              context: context,
                              chatProvider: chatProvider,
                              theme: theme,
                              label: 'Status Order',
                              sortBy: 'status_order',
                              icon: Icons.sort_by_alpha,
                            ),
                          ),
                          // 熱門度(應徵者數量）排序
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildCompactSortChip(
                              context: context,
                              chatProvider: chatProvider,
                              theme: theme,
                              label: 'Popularity',
                              sortBy: 'applicant_count',
                              icon: Icons.people,
                            ),
                          ),
                          // 狀態ID排序
                          Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: _buildCompactSortChip(
                              context: context,
                              chatProvider: chatProvider,
                              theme: theme,
                              label: 'Status ID',
                              sortBy: 'status_id',
                              icon: Icons.sort,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              // ),
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

  /// 顯示篩選選項對話框
  void _showFilterOptions(
      BuildContext context, ChatListProvider chatProvider, dynamic theme) {
    // 創建暫時的篩選狀態
    Set<String> tempSelectedLocations =
        Set.from(chatProvider.selectedLocations);
    Set<String> tempSelectedStatuses = Set.from(chatProvider.selectedStatuses);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setModalState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.7,
            maxChildSize: 0.9,
            minChildSize: 0.5,
            expand: false,
            builder: (context, scrollController) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 標題
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Filter Options',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: theme.onSurface,
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  Expanded(
                    child: ListView(
                      controller: scrollController,
                      children: [
                        // 位置篩選
                        Text(
                          'Location',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: Text('Select Location',
                                  style: TextStyle(
                                      color: theme.onSurface
                                          .withValues(alpha: 0.6))),
                              value: tempSelectedLocations.isEmpty
                                  ? (chatProvider.selectedLocations.isEmpty
                                      ? null
                                      : 'All')
                                  : tempSelectedLocations.first,
                              items: [
                                'All',
                                'NCCU',
                                'NTU',
                                'NTUST',
                                'Taipei',
                                'New Taipei City'
                              ]
                                  .map((location) => DropdownMenuItem(
                                        value: location,
                                        child: Text(location),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == 'All' || value == null) {
                                    tempSelectedLocations.clear();
                                  } else {
                                    tempSelectedLocations.clear();
                                    tempSelectedLocations.add(value);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 狀態篩選
                        Text(
                          'Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: theme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            border: Border.all(color: theme.outlineVariant),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              hint: Text('Select Status',
                                  style: TextStyle(
                                      color: theme.onSurface
                                          .withValues(alpha: 0.6))),
                              value: tempSelectedStatuses.isEmpty
                                  ? (chatProvider.selectedStatuses.isEmpty
                                      ? null
                                      : 'All')
                                  : tempSelectedStatuses.first,
                              items: [
                                'All',
                                'Open',
                                'In Progress',
                                'Completed',
                                'Pending Review'
                              ]
                                  .map((status) => DropdownMenuItem(
                                        value: status,
                                        child: Text(status),
                                      ))
                                  .toList(),
                              onChanged: (value) {
                                setModalState(() {
                                  if (value == 'All' || value == null) {
                                    tempSelectedStatuses.clear();
                                  } else {
                                    tempSelectedStatuses.clear();
                                    tempSelectedStatuses.add(value);
                                  }
                                });
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // 跨位置搜尋開關
                        if (chatProvider.searchQuery.isNotEmpty)
                          Row(
                            children: [
                              Checkbox(
                                value: chatProvider.crossLocationSearch,
                                onChanged: (value) {
                                  chatProvider
                                      .setCrossLocationSearch(value ?? false);
                                },
                              ),
                              Text(
                                '跨位置搜尋',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: theme.onSurface.withValues(alpha: 0.8),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '(忽略位置篩選，搜尋所有地點)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.onSurface.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),

                  // 底部按鈕
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setModalState(() {
                              tempSelectedLocations.clear();
                              tempSelectedStatuses.clear();
                            });
                          },
                          child: const Text('Clear All'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            // 應用篩選條件
                            chatProvider
                                .updateLocationFilter(tempSelectedLocations);
                            chatProvider
                                .updateStatusFilter(tempSelectedStatuses);
                            Navigator.of(context).pop();
                          },
                          child: const Text('Apply'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// 滾動到頂部
  void _scrollToTop() {
    try {
      final scrollController = PrimaryScrollController.of(context);
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    } catch (e) {
      debugPrint('❌ ScrollController error: $e');
    }
  }
}
