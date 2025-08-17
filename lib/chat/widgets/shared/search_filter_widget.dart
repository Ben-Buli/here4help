import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/chat/providers/chat_list_provider.dart';

/// 共享的搜尋篩選組件
/// 可以在 Posted Tasks 和 My Works 兩個分頁中重用
class SharedSearchFilterWidget extends StatefulWidget {
  final int tabIndex;
  final List<String> availableLocations;
  final List<String> availableStatuses;

  const SharedSearchFilterWidget({
    super.key,
    required this.tabIndex,
    required this.availableLocations,
    required this.availableStatuses,
  });

  @override
  State<SharedSearchFilterWidget> createState() =>
      _SharedSearchFilterWidgetState();
}

class _SharedSearchFilterWidgetState extends State<SharedSearchFilterWidget> {
  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedLocations = {};
  final Set<String> _selectedStatuses = {};

  @override
  void initState() {
    super.initState();
    // 移除危險的同步邏輯，避免無限循環
    // 改為在 build 中直接讀取 Provider 狀態
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Consumer<ChatListProvider>(
      builder: (context, chatProvider, child) {
        // 確保當前分頁
        if (chatProvider.currentTabIndex != widget.tabIndex) {
          return const SizedBox.shrink();
        }

        // 直接從 Provider 讀取狀態，避免本地狀態同步
        final currentSearchQuery = chatProvider.searchQuery;
        final currentLocations = chatProvider.selectedLocations;
        final currentStatuses = chatProvider.selectedStatuses;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 搜尋欄
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '搜尋任務...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          chatProvider.setSearchQuery('');
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: theme.colorScheme.surface,
              ),
              onChanged: (value) {
                chatProvider.setSearchQuery(value);
              },
            ),

            const SizedBox(height: 12),

            // 排序狀態提示
            if (chatProvider.searchQuery.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 16,
                    color: theme.primaryColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      chatProvider.currentSortBy == 'relevance'
                          ? '排序：相關性（搜尋建議）'
                          : '排序：${chatProvider.currentSortBy.replaceAll('_', ' ')}（已覆蓋）',
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.primaryColor.withValues(alpha: 0.7),
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
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        // 相關性排序（僅在有搜尋時顯示）
                        if (chatProvider.searchQuery.isNotEmpty)
                          _buildSortChip(
                            'relevance',
                            '相關性',
                            chatProvider.currentSortBy == 'relevance',
                            chatProvider,
                          ),

                        // 時間排序
                        _buildSortChip(
                          'updated_time',
                          '最近更新',
                          chatProvider.currentSortBy == 'updated_time',
                          chatProvider,
                        ),

                        // 狀態排序
                        _buildSortChip(
                          'status_id',
                          '狀態 ID',
                          chatProvider.currentSortBy == 'status_id',
                          chatProvider,
                        ),

                        // 應徵者數量排序
                        _buildSortChip(
                          'applicant_count',
                          '應徵者數',
                          chatProvider.currentSortBy == 'applicant_count',
                          chatProvider,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // 跨地點搜尋選項（僅在有搜尋時顯示）
            if (chatProvider.searchQuery.isNotEmpty)
              Row(
                children: [
                  Checkbox(
                    value: chatProvider.crossLocationSearch,
                    onChanged: (value) {
                      chatProvider.setCrossLocationSearch(value ?? false);
                    },
                  ),
                  const Text('跨地點搜尋'),
                ],
              ),

            const SizedBox(height: 12),

            // 位置篩選
            if (widget.availableLocations.isNotEmpty)
              _buildFilterSection(
                '位置',
                widget.availableLocations,
                currentLocations, // 使用 Provider 狀態
                (locations) {
                  chatProvider.updateLocationFilter(locations);
                },
              ),

            // 狀態篩選
            if (widget.availableStatuses.isNotEmpty)
              _buildFilterSection(
                '狀態',
                widget.availableStatuses,
                currentStatuses, // 使用 Provider 狀態
                (statuses) {
                  chatProvider.updateStatusFilter(statuses);
                },
              ),

            // 清除篩選按鈕
            if (chatProvider.hasActiveFilters)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      chatProvider.resetFilters();
                      _searchController.clear();
                      // 移除本地狀態清理，避免狀態不同步
                    },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('清除篩選'),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  /// 構建排序選項
  Widget _buildSortChip(
    String sortBy,
    String label,
    bool isSelected,
    ChatListProvider provider,
  ) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (selected) {
            provider.setSortOrder(sortBy, ascending: false); // 預設降序
          }
        },
        selectedColor: Theme.of(context).primaryColor.withValues(alpha: 0.2),
        checkmarkColor: Theme.of(context).primaryColor,
      ),
    );
  }

  /// 構建篩選區域
  Widget _buildFilterSection(
    String title,
    List<String> options,
    Set<String> selected,
    Function(Set<String>) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: options.map((option) {
            final isSelected = selected.contains(option);
            return FilterChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (isSelected) {
                final newSelection = Set<String>.from(selected);
                if (isSelected) {
                  newSelection.add(option);
                } else {
                  newSelection.remove(option);
                }
                onChanged(newSelection);
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}
