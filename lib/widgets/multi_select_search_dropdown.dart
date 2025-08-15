import 'package:flutter/material.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:provider/provider.dart';

class MultiSelectSearchDropdown extends StatefulWidget {
  final List<String> options;
  final Set<String> selectedValues;
  final Function(Set<String>) onChanged;
  final String label;
  final String hint;
  final String? searchHint;

  const MultiSelectSearchDropdown({
    super.key,
    required this.options,
    required this.selectedValues,
    required this.onChanged,
    required this.label,
    required this.hint,
    this.searchHint,
  });

  @override
  State<MultiSelectSearchDropdown> createState() =>
      _MultiSelectSearchDropdownState();
}

class _MultiSelectSearchDropdownState extends State<MultiSelectSearchDropdown> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isOpen = false;
  List<String> _filteredOptions = [];

  @override
  void initState() {
    super.initState();
    _filteredOptions = widget.options;
    _searchController.addListener(_filterOptions);
  }

  @override
  void didUpdateWidget(MultiSelectSearchDropdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.options != widget.options) {
      _filterOptions();
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _filterOptions() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredOptions = widget.options
          .where((option) => option.toLowerCase().contains(query))
          .toList();
    });
  }

  void _toggleOption(String option) {
    final newSelectedValues = Set<String>.from(widget.selectedValues);
    if (newSelectedValues.contains(option)) {
      newSelectedValues.remove(option);
    } else {
      newSelectedValues.add(option);
    }
    widget.onChanged(newSelectedValues);
  }

  void _selectAll() {
    widget.onChanged(Set<String>.from(_filteredOptions));
  }

  void _clearAll() {
    widget.onChanged({});
  }

  String _getDisplayText() {
    if (widget.selectedValues.isEmpty) {
      return widget.hint;
    }
    if (widget.selectedValues.length == 1) {
      return widget.selectedValues.first;
    }
    return '${widget.selectedValues.length} selected';
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeConfigManager>(
      builder: (context, themeManager, child) {
        final theme = themeManager.effectiveTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: theme.onSurface,
              ),
            ),
            const SizedBox(height: 8),

            // Dropdown button
            GestureDetector(
              onTap: () {
                setState(() {
                  _isOpen = !_isOpen;
                });
                if (_isOpen) {
                  _searchFocusNode.requestFocus();
                }
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: theme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _getDisplayText(),
                        style: TextStyle(
                          color: widget.selectedValues.isEmpty
                              ? theme.onSurface.withValues(alpha: 0.6)
                              : theme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      _isOpen
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: theme.onSurface,
                    ),
                  ],
                ),
              ),
            ),

            // Dropdown content
            if (_isOpen) ...[
              const SizedBox(height: 4),
              Container(
                constraints: const BoxConstraints(maxHeight: 300),
                decoration: BoxDecoration(
                  color: theme.surface,
                  border: Border.all(color: theme.outlineVariant),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search field
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        decoration: InputDecoration(
                          hintText: widget.searchHint ?? 'Search...',
                          prefixIcon: const Icon(Icons.search),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),

                    // Action buttons
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: _selectAll,
                            child: const Text('Select All'),
                          ),
                          const SizedBox(width: 8),
                          TextButton(
                            onPressed: _clearAll,
                            child: const Text('Clear All'),
                          ),
                        ],
                      ),
                    ),

                    const Divider(height: 1),

                    // Options list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _filteredOptions.length,
                        itemBuilder: (context, index) {
                          final option = _filteredOptions[index];
                          final isSelected =
                              widget.selectedValues.contains(option);

                          return ListTile(
                            dense: true,
                            title: Text(
                              option,
                              style: TextStyle(
                                color: isSelected
                                    ? theme.primary
                                    : theme.onSurface,
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.normal,
                              ),
                            ),
                            leading: Checkbox(
                              value: isSelected,
                              onChanged: (_) => _toggleOption(option),
                              activeColor: theme.primary,
                            ),
                            onTap: () => _toggleOption(option),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
