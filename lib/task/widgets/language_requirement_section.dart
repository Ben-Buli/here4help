import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/viewmodels/task_form_viewmodel.dart';

class LanguageRequirementSection extends StatelessWidget {
  const LanguageRequirementSection({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;
    final viewModel = Provider.of<TaskFormViewModel>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Language Requirements',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.surface.withOpacity(0.8),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: theme.outlineVariant.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Select required languages',
                style: TextStyle(
                  fontSize: 14,
                  color: theme.onSurface.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: viewModel.languages.map((language) {
                  final languageName = language['name'] as String? ?? '';
                  final isSelected =
                      viewModel.selectedLanguages.contains(languageName);

                  return FilterChip(
                    label: Text(languageName),
                    selected: isSelected,
                    onSelected: (selected) {
                      if (selected) {
                        viewModel.addLanguage(languageName);
                      } else {
                        viewModel.removeLanguage(languageName);
                      }
                    },
                    selectedColor: theme.primary.withOpacity(0.2),
                    checkmarkColor: theme.primary,
                    labelStyle: TextStyle(
                      color: isSelected ? theme.primary : theme.onSurface,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: theme.surface,
                    side: BorderSide(
                      color: isSelected
                          ? theme.primary
                          : theme.outlineVariant.withOpacity(0.3),
                    ),
                  );
                }).toList(),
              ),
              if (viewModel.selectedLanguages.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Selected languages: ${viewModel.selectedLanguages.join(', ')}',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
