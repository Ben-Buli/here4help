import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/task/viewmodels/task_form_viewmodel.dart';
import 'package:intl/intl.dart';

class TaskTimeSection extends StatelessWidget {
  const TaskTimeSection({super.key});

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
          'Task Date',
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
            border: Border.all(
              color: viewModel.hasError('Time')
                  ? Colors.red
                  : theme.outlineVariant.withOpacity(0.3),
              width: viewModel.hasError('Time') ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              // Task Date
              ListTile(
                leading: Icon(
                  Icons.calendar_today,
                  color: theme.primary,
                ),
                title: const Text('Task Date'),
                subtitle: Text(
                  viewModel.taskDate != null
                      ? DateFormat('yyyy-MM-dd HH:mm')
                          .format(viewModel.taskDate!)
                      : 'Select date',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectTaskDate(context, viewModel),
              ),
              const Divider(),
              // Period Start
              ListTile(
                leading: Icon(
                  Icons.access_time,
                  color: theme.primary,
                ),
                title: const Text('Period Start'),
                subtitle: Text(
                  viewModel.periodStart != null
                      ? DateFormat('HH:mm').format(viewModel.periodStart!)
                      : 'Select start time',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectPeriodStart(context, viewModel),
              ),
              const Divider(),
              // Period End
              ListTile(
                leading: Icon(
                  Icons.access_time_filled,
                  color: theme.primary,
                ),
                title: const Text('Period End'),
                subtitle: Text(
                  viewModel.periodEnd != null
                      ? DateFormat('HH:mm').format(viewModel.periodEnd!)
                      : 'Select end time',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _selectPeriodEnd(context, viewModel),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _selectTaskDate(
      BuildContext context, TaskFormViewModel viewModel) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: viewModel.taskDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      final TimeOfDay? time = await showTimePicker(
        context: context,
        initialTime:
            TimeOfDay.fromDateTime(viewModel.taskDate ?? DateTime.now()),
      );

      if (time != null) {
        final DateTime selectedDateTime = DateTime(
          picked.year,
          picked.month,
          picked.day,
          time.hour,
          time.minute,
        );
        viewModel.updateTaskDate(selectedDateTime);
        viewModel.removeError('Time');
      }
    }
  }

  Future<void> _selectPeriodStart(
      BuildContext context, TaskFormViewModel viewModel) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(viewModel.periodStart ?? DateTime.now()),
    );

    if (time != null) {
      final DateTime selectedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        time.hour,
        time.minute,
      );
      viewModel.updatePeriodStart(selectedTime);
    }
  }

  Future<void> _selectPeriodEnd(
      BuildContext context, TaskFormViewModel viewModel) async {
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime:
          TimeOfDay.fromDateTime(viewModel.periodEnd ?? DateTime.now()),
    );

    if (time != null) {
      final DateTime selectedTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        time.hour,
        time.minute,
      );
      viewModel.updatePeriodEnd(selectedTime);
    }
  }
}
