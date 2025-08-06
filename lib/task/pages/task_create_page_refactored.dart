import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:here4help/task/viewmodels/task_form_viewmodel.dart';
import 'package:here4help/task/widgets/task_poster_info_card.dart';
import 'package:here4help/task/widgets/warning_message_card.dart';
import 'package:here4help/task/widgets/submit_task_button.dart';
import 'package:here4help/task/widgets/task_time_section.dart';
import 'package:here4help/task/widgets/task_basic_info_section.dart';
import 'package:here4help/task/widgets/language_requirement_section.dart';
import 'package:here4help/task/widgets/application_questions_section.dart';
import 'package:here4help/task/services/university_service.dart';
import 'package:here4help/task/services/language_service.dart';

class TaskCreatePageRefactored extends StatefulWidget {
  const TaskCreatePageRefactored({super.key});

  @override
  State<TaskCreatePageRefactored> createState() =>
      _TaskCreatePageRefactoredState();
}

class _TaskCreatePageRefactoredState extends State<TaskCreatePageRefactored> {
  late TaskFormViewModel _viewModel;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _viewModel = TaskFormViewModel();
    _initializeData();
  }

  Future<void> _initializeData() async {
    _viewModel.initializeForm();
    await _loadUniversities();
    await _loadLanguages();
  }

  Future<void> _loadUniversities() async {
    try {
      final universities = await UniversityService.getUniversities();
      _viewModel.updateUniversities(universities);
    } catch (e) {
      _viewModel.updateUniversities([
        {
          'abbr': 'NTU',
          'zh_name': '國立台灣大學',
          'en_name': 'National Taiwan University'
        },
        {
          'abbr': 'NCCU',
          'zh_name': '國立政治大學',
          'en_name': 'National Chengchi University'
        },
        {
          'abbr': 'NTHU',
          'zh_name': '國立清華大學',
          'en_name': 'National Tsing Hua University'
        },
        {
          'abbr': 'NCKU',
          'zh_name': '國立成功大學',
          'en_name': 'National Cheng Kung University'
        },
      ]);
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final languages = await LanguageService.getLanguages();
      _viewModel.updateLanguages(languages);
    } catch (e) {
      _viewModel.updateLanguages([
        {'code': 'en', 'name': 'English', 'native': 'English'},
        {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
        {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
        {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
      ]);
    }
  }

  Future<void> _submitTask() async {
    if (!_viewModel.validateForm()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: 實現任務提交邏輯
      await Future.delayed(const Duration(seconds: 2)); // 模擬 API 調用

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Task created successfully!'),
            backgroundColor: Colors.green,
          ),
        );

        // 導航回任務列表頁面
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create task: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create Task'),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Consumer<TaskFormViewModel>(
          builder: (context, viewModel, child) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 警告訊息
                  const WarningMessageCard(),

                  // 個人資料
                  const TaskPosterInfoCard(),

                  const SizedBox(height: 24),

                  // 任務基本資訊
                  const TaskBasicInfoSection(),

                  const SizedBox(height: 24),

                  // 時間設定
                  const TaskTimeSection(),

                  const SizedBox(height: 24),

                  // 語言要求
                  const LanguageRequirementSection(),

                  const SizedBox(height: 24),

                  // 申請問題
                  const ApplicationQuestionsSection(),

                  const SizedBox(height: 24),

                  // 提交按鈕
                  SubmitTaskButton(
                    onPressed: _submitTask,
                    isLoading: _isLoading,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }
}
