import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/viewmodels/task_form_viewmodel.dart';

class ApplicationQuestionsSection extends StatelessWidget {
  const ApplicationQuestionsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;
    final viewModel = Provider.of<TaskFormViewModel>(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Application Questions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.primary,
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: () => viewModel.addApplicationQuestion(),
              icon: Icon(
                Icons.add_circle_outline,
                color: theme.primary,
              ),
              tooltip: 'Add question',
            ),
          ],
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
            children: [
              if (viewModel.applicationQuestions.isEmpty)
                _buildEmptyState(context, theme)
              else
                ...viewModel.applicationQuestions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  return _buildQuestionField(
                    context: context,
                    index: index,
                    question: question,
                    viewModel: viewModel,
                    theme: theme,
                  );
                }).toList(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, dynamic theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(
            Icons.question_answer_outlined,
            size: 48,
            color: theme.onSurface.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'No application questions yet',
            style: TextStyle(
              fontSize: 16,
              color: theme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Add questions to help you evaluate applicants',
            style: TextStyle(
              fontSize: 14,
              color: theme.onSurface.withOpacity(0.4),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildQuestionField({
    required BuildContext context,
    required int index,
    required String question,
    required TaskFormViewModel viewModel,
    required dynamic theme,
  }) {
    final hasError = viewModel.hasError('Application Question ${index + 1}');

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasError ? Colors.red : theme.outlineVariant.withOpacity(0.3),
          width: hasError ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Question ${index + 1}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: theme.primary,
                  ),
                ),
              ),
              const Spacer(),
              if (viewModel.applicationQuestions.length > 1)
                IconButton(
                  onPressed: () => viewModel.removeApplicationQuestion(index),
                  icon: Icon(
                    Icons.delete_outline,
                    color: Colors.red[400],
                    size: 20,
                  ),
                  tooltip: 'Remove question',
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: question,
            maxLines: 3,
            maxLength: 200,
            decoration: InputDecoration(
              hintText: 'Enter your question here...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(
                  color: hasError
                      ? Colors.red
                      : theme.outlineVariant.withOpacity(0.3),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.primary),
              ),
              errorBorder: const OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(8)),
                borderSide: BorderSide(color: Colors.red),
              ),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              counterText: '',
            ),
            onChanged: (value) {
              viewModel.updateApplicationQuestion(index, value);
              if (hasError) {
                viewModel.removeError('Application Question ${index + 1}');
              }
            },
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${question.length}/200 characters',
                style: TextStyle(
                  fontSize: 12,
                  color: theme.onSurface.withOpacity(0.5),
                ),
              ),
              if (hasError)
                Text(
                  'This field is required',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
