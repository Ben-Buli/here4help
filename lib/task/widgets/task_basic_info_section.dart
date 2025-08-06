import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/viewmodels/task_form_viewmodel.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:intl/intl.dart';

class TaskBasicInfoSection extends StatelessWidget {
  const TaskBasicInfoSection({super.key});

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
          'Task Basic Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Title
        _buildTextField(
          context: context,
          controller: viewModel.titleController,
          label: 'Task Title',
          hint: 'Enter task title',
          icon: Icons.title,
          isRequired: true,
          errorField: 'Task Title',
          viewModel: viewModel,
        ),

        const SizedBox(height: 16),

        // Salary
        _buildSalaryField(context, viewModel),

        const SizedBox(height: 16),

        // Location
        _buildLocationField(context, viewModel),

        const SizedBox(height: 16),

        // Description
        _buildTextField(
          context: context,
          controller: viewModel.taskDescriptionController,
          label: 'Task Description',
          hint: 'Describe the task in detail',
          icon: Icons.description,
          isRequired: false,
          maxLines: 4,
          viewModel: viewModel,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isRequired,
    String? errorField,
    int maxLines = 1,
    required TaskFormViewModel viewModel,
  }) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;
    final hasError = errorField != null && viewModel.hasError(errorField);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: theme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.onSurface,
              ),
            ),
            if (isRequired) ...[
              const SizedBox(width: 4),
              const Text(
                '*',
                style: TextStyle(
                  color: Colors.red,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey[300]!,
              width: hasError ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: hasError ? Colors.red[50] : Colors.white,
          ),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            decoration: InputDecoration(
              hintText: hint,
              border: InputBorder.none,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (value) {
              if (errorField != null && hasError) {
                viewModel.removeError(errorField);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSalaryField(BuildContext context, TaskFormViewModel viewModel) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;
    final hasError = viewModel.hasError('Salary');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.attach_money, color: theme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Reward',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            const Text(
              '*',
              style: TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: hasError ? Colors.red : Colors.grey[300]!,
              width: hasError ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: hasError ? Colors.red[50] : Colors.white,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8),
                    bottomLeft: Radius.circular(8),
                  ),
                ),
                child: const Icon(
                  Icons.attach_money,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              Expanded(
                child: TextFormField(
                  controller: viewModel.salaryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    hintText: '0',
                    border: InputBorder.none,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    final formatter = NumberFormat('#,##0', 'en_US');
                    final digits = value.replaceAll(RegExp(r'[^\d]'), '');
                    final number = int.tryParse(digits) ?? 0;
                    final formatted = formatter.format(number);
                    viewModel.salaryController.value = TextEditingValue(
                      text: formatted,
                      selection:
                          TextSelection.collapsed(offset: formatted.length),
                    );
                    if (hasError) {
                      viewModel.removeError('Salary');
                    }
                  },
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Text(
                  '/hour',
                  style: TextStyle(
                    color: theme.primary,
                    fontWeight: FontWeight.w500,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLocationField(
      BuildContext context, TaskFormViewModel viewModel) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.location_on, color: theme.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Location',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: theme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
          ),
          child: ListTile(
            leading: Icon(Icons.location_on, color: theme.primary),
            title: Text(viewModel.locationLabel.isNotEmpty
                ? viewModel.locationLabel
                : 'Select location'),
            subtitle: viewModel.locationLabel.isNotEmpty
                ? const Text('Selected location')
                : null,
            trailing: const Icon(Icons.chevron_right, color: AppColors.primary),
            onTap: () {
              // TODO: Implement location selection
            },
          ),
        ),
      ],
    );
  }
}
