// post_form_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/university_service.dart';
import 'package:here4help/task/services/language_service.dart';
import 'package:here4help/task/services/task_service.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/utils/image_helper.dart';

const String kTaskTitleField = 'Task Title';
const String kRewardPointField = 'Reward Point';
const String kTimeField = 'Time';
const String kPostingPeriodField = 'Posting period';

class TaskCreatePage extends StatefulWidget {
  const TaskCreatePage({super.key});

  @override
  State<TaskCreatePage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<TaskCreatePage> {
  final MapController _mapController = MapController();
  final TextEditingController _rewardPointController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  late final TextEditingController _taskDescriptionController;
  String _languageRequirement = '';
  DateTime? _taskDate;
  DateTime? _periodStart;
  DateTime? _periodEnd;

  LatLng? _selectedLocation = const LatLng(25.0208, 121.5418);
  String _locationLabel = 'NCCU';

  final TextEditingController _locationSearchController =
      TextEditingController();

  final Set<String> _errorFields = {};
  List<String> _selectedLanguages = [];
  final List<String> _applicationQuestions = [];
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _languages = [];
  bool _showApplicationQuestionErrors =
      false; // 新增：控制是否顯示 application questions 錯誤提示

  @override
  void initState() {
    super.initState();

    // 初始化表單欄位
    _titleController.text = 'Opening Bank Account (Demo)';
    _taskDescriptionController = TextEditingController(
        text:
            'Need help with opening a bank account. Looking for someone who can guide me through the process and accompany me to the bank.');
    final formatter = NumberFormat('#,##0', 'en_US');
    _rewardPointController.text = formatter.format(500);
    _locationLabel = 'NCCU';
    _locationSearchController.text = 'NCCU';
    final now = DateTime.now();
    _taskDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _periodStart = DateTime(2025, 9, 10, 12, 0);
    _periodEnd = DateTime(2025, 9, 10, 13, 0);
    // 初始化為空列表，讓用戶可以自由添加問題
    _applicationQuestions.clear();
    _languageRequirement = 'English,Japanese';

    _loadUniversities();
    _loadLanguages();
  }

  Future<void> _loadUniversities() async {
    try {
      final universities = await UniversityService.getUniversities();
      setState(() {
        _universities = universities;
      });
    } catch (e) {
      setState(() {
        _universities = [
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
        ];
      });
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final languages = await LanguageService.getLanguages();
      setState(() {
        _languages = languages;
        // 設置初始選中的語言
        _selectedLanguages = _getLanguageCodesFromNames(_languageRequirement);
      });
    } catch (e) {
      setState(() {
        _languages = [
          {'code': 'en', 'name': 'English', 'native': 'English'},
          {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
          {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
          {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
        ];
        // 設置初始選中的語言
        _selectedLanguages = _getLanguageCodesFromNames(_languageRequirement);
      });
    }
  }

  // 根據語言名稱獲取語言代碼
  List<String> _getLanguageCodesFromNames(String languageNames) {
    List<String> codes = [];
    List<String> names = languageNames
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    // 如果語言列表還沒有加載，返回空列表
    if (_languages.isEmpty) {
      return codes;
    }

    for (String name in names) {
      // 嘗試匹配語言名稱或原生名稱
      final matchedLanguage = _languages.firstWhere(
        (lang) {
          final langName = lang['name']?.toString().toLowerCase() ?? '';
          final langNative = lang['native']?.toString().toLowerCase() ?? '';
          final searchName = name.toLowerCase();

          return langName.contains(searchName) ||
              langNative.contains(searchName) ||
              searchName.contains(langName) ||
              searchName.contains(langNative);
        },
        orElse: () => <String, dynamic>{},
      );

      if (matchedLanguage.isNotEmpty && matchedLanguage['name'] != null) {
        codes.add(matchedLanguage['name']!);
      }
    }

    return codes;
  }

  void _addApplicationQuestion() {
    // 檢查是否有未填寫的問題
    bool hasEmptyQuestion = false;
    for (int i = 0; i < _applicationQuestions.length; i++) {
      if (_applicationQuestions[i].trim().isEmpty) {
        hasEmptyQuestion = true;
        break;
      }
    }

    if (hasEmptyQuestion) {
      // 設置顯示錯誤狀態
      setState(() {
        _showApplicationQuestionErrors = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Please fill in all existing questions before adding a new one.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_applicationQuestions.length < 3) {
      setState(() {
        _applicationQuestions.add('');
        _showApplicationQuestionErrors = false; // 重置錯誤顯示狀態
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can add up to 3 questions maximum.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _removeApplicationQuestion(int index) {
    if (index >= 0 && index < _applicationQuestions.length) {
      setState(() {
        _applicationQuestions.removeAt(index);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 個人資料區塊
              _buildPersonalInfoSection(),
              const SizedBox(height: 16),

              // 任務基本資訊
              _buildTaskBasicInfoSection(),
              const SizedBox(height: 16),

              // 時間設定
              _buildTimeSection(),
              const SizedBox(height: 24),

              // 申請問題
              _buildQuestionsSection(),
              const SizedBox(height: 24),

              // 語言要求
              _buildLanguageSection(),
              const SizedBox(height: 24),

              // 警告訊息
              _buildWarningMessage(),
              const SizedBox(height: 24),

              // 提交按鈕
              _buildSubmitButton(),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonalInfoSection() {
    final userService = Provider.of<UserService>(context, listen: true);
    final user = userService.currentUser;
    final userName = user?.name ?? 'Unknown User';
    final avatarUrl = user?.avatar_url ?? '';

    // Debug: 打印用戶資訊
    debugPrint(
        '🔍 PersonalInfoSection - User: ${user?.name}, Avatar: ${user?.avatar_url}');
    debugPrint('🔍 PersonalInfoSection - 當前時間: ${DateTime.now()}');

    // 如果正在載入用戶資料，顯示載入狀態
    if (userService.isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.grey[300],
              backgroundImage: ImageHelper.getDefaultAvatar(),
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Loading...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Task Creator',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
            const CircularProgressIndicator(strokeWidth: 2),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        children: [
          // 用戶頭貼 - 使用 key 強制刷新
          CircleAvatar(
            key: ValueKey('avatar_${user?.id}_${user?.avatar_url}'),
            radius: 24,
            backgroundColor: Colors.grey[300],
            backgroundImage: ImageHelper.getAvatarImage(avatarUrl) ??
                ImageHelper.getDefaultAvatar(),
            child: ImageHelper.getAvatarImage(avatarUrl) == null
                ? Icon(Icons.person, color: Colors.grey[600])
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Task Creator',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }

  Widget _buildTaskBasicInfoSection() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

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
        const SizedBox(height: 12),

        // Task Title
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Task Title',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: theme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter a clear and descriptive task title',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.edit, color: theme.primary),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a task title';
                }
                return null;
              },
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Reward Point
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Reward Point',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: theme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
                color: Colors.white,
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    child: Text(
                      '💰',
                      style: TextStyle(
                        fontSize: 24,
                        color: theme.primary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: TextFormField(
                      controller: _rewardPointController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: const InputDecoration(
                        hintText: '0',
                        border: InputBorder.none, // 隱藏所有狀態下的邊框
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a reward point';
                        }
                        // 檢查是否為有效數字
                        final number = int.tryParse(value);
                        if (number == null) {
                          return 'Please enter a valid integer';
                        }
                        // 檢查是否大於0
                        if (number <= 0) {
                          return 'Reward point must be greater than 0';
                        }
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    child: Center(
                      child: Text(
                        '/hour',
                        style: TextStyle(
                          color: theme.primary,
                          fontWeight: FontWeight.w500,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Location
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Location',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () => _showLocationPicker(context),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on,
                        color: theme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              () {
                                final matched = _universities.firstWhere(
                                  (uni) =>
                                      uni['en_name'] == _locationLabel ||
                                      uni['zh_name'] == _locationLabel,
                                  orElse: () => <String, dynamic>{},
                                );
                                if (matched.isNotEmpty) {
                                  return matched['abbr']!;
                                }
                                return _locationLabel.isNotEmpty
                                    ? _locationLabel
                                    : 'Tap to select location';
                              }(),
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_locationLabel.isNotEmpty)
                              Text(
                                'Selected location',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: theme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Description
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Description',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: theme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _taskDescriptionController,
              maxLines: 4,
              maxLength: 1000,
              decoration: InputDecoration(
                hintText: 'Enter a detailed description of your task',
                hintStyle: TextStyle(color: Colors.grey[400]),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: Colors.grey[300]!),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(color: theme.primary, width: 2),
                ),
                filled: true,
                fillColor: Colors.white,
                prefixIcon: Icon(Icons.description, color: theme.primary),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a task description';
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTaskTitleCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Task Title',
      icon: Icons.title,
      isRequired: true,
      isError: _errorFields.contains(kTaskTitleField),
      child: TextFormField(
        controller: _titleController,
        decoration: InputDecoration(
          hintText: 'Enter a clear and descriptive task title',
          hintStyle: TextStyle(color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.grey[300]!),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: theme.error, width: 2),
          ),
          filled: true,
          fillColor: _errorFields.contains(kTaskTitleField)
              ? theme.error.withOpacity(0.1)
              : Colors.white,
          prefixIcon: Icon(
            Icons.edit,
            color: _errorFields.contains(kTaskTitleField)
                ? theme.error
                : theme.primary,
          ),
        ),
        onChanged: (_) {
          if (_errorFields.contains(kTaskTitleField)) {
            setState(() => _errorFields.remove(kTaskTitleField));
          }
        },
      ),
    );
  }

  Widget _buildRewardPointCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Reward Point',
      icon: Icons.attach_money,
      isRequired: true,
      isError: _errorFields.contains(kRewardPointField),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _errorFields.contains(kRewardPointField)
                ? theme.error
                : Colors.grey[300]!,
            width: _errorFields.contains(kRewardPointField) ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _errorFields.contains(kRewardPointField)
              ? theme.error.withOpacity(0.1)
              : Colors.white,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.primary.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: Icon(
                Icons.attach_money,
                color: theme.primary,
                size: 24,
              ),
            ),
            Expanded(
              child: TextFormField(
                controller: _rewardPointController,
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
                  _rewardPointController.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                  if (_errorFields.contains(kRewardPointField)) {
                    setState(() => _errorFields.remove(kRewardPointField));
                  }
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: Text(
                '/point',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Location',
      icon: Icons.location_on,
      child: GestureDetector(
        onTap: () => _showLocationPicker(context),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                Icons.location_on,
                color: theme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      () {
                        final matched = _universities.firstWhere(
                          (uni) =>
                              uni['en_name'] == _locationLabel ||
                              uni['zh_name'] == _locationLabel,
                          orElse: () => <String, dynamic>{},
                        );
                        if (matched.isNotEmpty) {
                          return matched['abbr']!;
                        }
                        return _locationLabel.isNotEmpty
                            ? _locationLabel
                            : 'Tap to select location';
                      }(),
                      style: TextStyle(
                        color: _locationLabel.isNotEmpty
                            ? Colors.black87
                            : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (_locationLabel.isNotEmpty)
                      Text(
                        'Selected location',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: theme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Task Date',
      icon: Icons.calendar_today,
      isRequired: true,
      isError: _errorFields.contains(kTimeField),
      child: GestureDetector(
        onTap: () async {
          _errorFields.remove('Time');
          _selectDate(context, (picked) {
            setState(() => _taskDate = picked);
          });
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: _errorFields.contains('Time')
                  ? theme.error
                  : Colors.grey[300]!,
              width: _errorFields.contains('Time') ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: _errorFields.contains('Time')
                ? theme.error.withOpacity(0.1)
                : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color:
                    _errorFields.contains('Time') ? theme.error : theme.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _taskDate != null
                      ? DateFormat('yyyy-MM-dd').format(_taskDate!)
                      : 'Select date',
                  style: TextStyle(
                    color:
                        _taskDate != null ? Colors.black87 : Colors.grey[500],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_drop_down,
                color: theme.primary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostingPeriodCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Posting Period',
      icon: Icons.schedule,
      isRequired: true,
      isError: _errorFields.contains(kPostingPeriodField),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _buildDateField(
                  'Start Date',
                  _periodStart,
                  (picked) async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(DateTime.now().year + 1),
                    );
                    if (picked != null) {
                      TimeOfDay? timePicked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (timePicked != null) {
                        DateTime combined = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          timePicked.hour,
                          timePicked.minute,
                        );
                        if (combined.isBefore(DateTime.now())) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'Start date cannot be earlier than the current time.'),
                              backgroundColor: theme.error,
                            ),
                          );
                        } else {
                          if (mounted) {
                            setState(() {
                              _periodStart = combined;
                            });
                          }
                        }
                      }
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Icon(Icons.arrow_forward, color: Colors.grey[400]),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDateField(
                  'End Date',
                  _periodEnd,
                  (picked) async {
                    DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime.now(),
                      lastDate: DateTime(DateTime.now().year + 1),
                    );
                    if (picked != null) {
                      TimeOfDay? timePicked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (timePicked != null) {
                        DateTime combined = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          timePicked.hour,
                          timePicked.minute,
                        );
                        if (_periodStart != null &&
                            combined.isBefore(_periodStart!)) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  'End date cannot be earlier than or equal to the start date.'),
                              backgroundColor: theme.error,
                            ),
                          );
                        } else {
                          if (mounted) {
                            setState(() {
                              _periodEnd = combined;
                            });
                          }
                        }
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateField(
      String label, DateTime? date, Function(DateTime) onTap) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => onTap(date ?? DateTime.now()),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                date != null
                    ? DateFormat('MM/dd HH:mm').format(date)
                    : 'Select',
                style: TextStyle(
                  color: date != null ? Colors.black87 : Colors.grey[500],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildApplicationQuestionsCard() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return _buildFormCard(
      title: 'Application Questions',
      icon: Icons.question_answer,
      child: Column(
        children: [
          ...List.generate(_applicationQuestions.length, (index) {
            final labelNumber = (index + 1).toString().padLeft(2, '0');
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _errorFields.contains('ApplicationQuestion$index') ||
                            (_showApplicationQuestionErrors &&
                                _applicationQuestions[index].trim().isEmpty)
                        ? theme.error
                        : Colors.grey[300]!,
                    width: _errorFields.contains('ApplicationQuestion$index') ||
                            (_showApplicationQuestionErrors &&
                                _applicationQuestions[index].trim().isEmpty)
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _errorFields.contains('ApplicationQuestion$index') ||
                          (_showApplicationQuestionErrors &&
                              _applicationQuestions[index].trim().isEmpty)
                      ? theme.error.withValues(alpha: 0.1)
                      : Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q$labelNumber',
                            style: TextStyle(
                              color: theme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Question ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (_applicationQuestions.length > 1)
                          MouseRegion(
                            cursor: SystemMouseCursors.click,
                            child: IconButton(
                              icon: Icon(
                                Icons.delete_outline,
                                color: theme.error,
                                size: 20,
                              ),
                              onPressed: () async {
                                final hasValue = _applicationQuestions[index]
                                    .trim()
                                    .isNotEmpty;
                                if (hasValue) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (BuildContext dialogContext) =>
                                        AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text(
                                          'Are you sure you want to delete this question?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () {
                                            if (Navigator.canPop(
                                                dialogContext)) {
                                              Navigator.of(dialogContext)
                                                  .pop(false);
                                            }
                                          },
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () {
                                            if (Navigator.canPop(
                                                dialogContext)) {
                                              Navigator.of(dialogContext)
                                                  .pop(true);
                                            }
                                          },
                                          child: Text('Delete',
                                              style: TextStyle(
                                                  color: theme.error)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    _removeApplicationQuestion(index);
                                  }
                                } else {
                                  _removeApplicationQuestion(index);
                                }
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      initialValue: _applicationQuestions[index],
                      decoration: InputDecoration(
                        hintText: 'Enter your question for applicants',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                      ),
                      onChanged: (value) {
                        setState(() {
                          _applicationQuestions[index] = value;
                          // 如果用戶開始填寫問題，清除錯誤顯示狀態
                          if (value.trim().isNotEmpty &&
                              _showApplicationQuestionErrors) {
                            _showApplicationQuestionErrors = false;
                          }
                        });
                      },
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${_applicationQuestions[index].length}/500 characters',
                          style: TextStyle(
                            fontSize: 12,
                            color: _applicationQuestions[index].length > 500
                                ? theme.error
                                : _applicationQuestions[index].length > 450
                                    ? Colors.orange
                                    : Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_applicationQuestions[index].length > 480)
                          Row(
                            children: [
                              Icon(
                                _applicationQuestions[index].length > 500
                                    ? Icons.error_outline
                                    : Icons.warning_amber_rounded,
                                size: 16,
                                color: _applicationQuestions[index].length > 500
                                    ? theme.error
                                    : Colors.orange,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _applicationQuestions[index].length > 500
                                    ? '字數超限'
                                    : '接近字數上限',
                                style: TextStyle(
                                  fontSize: 12,
                                  color:
                                      _applicationQuestions[index].length > 500
                                          ? theme.error
                                          : Colors.orange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        // 顯示未填寫問題的錯誤提示
                        if (_showApplicationQuestionErrors &&
                            _applicationQuestions[index].trim().isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  size: 16,
                                  color: theme.error,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Please fill in this question',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_applicationQuestions.length < 3)
            Center(
              child: OutlinedButton.icon(
                onPressed: _addApplicationQuestion,
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: theme.primary),
                  backgroundColor: theme.primary.withValues(alpha: 0.1),
                ),
                icon: Icon(Icons.add, color: theme.primary),
                label: Text(
                  'Add Question',
                  style: TextStyle(color: theme.primary),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageSection() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Language Requirements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: theme.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'Required',
                style: TextStyle(
                  color: theme.error,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<List<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                List<String> tempSelected = List.from(_selectedLanguages);
                TextEditingController searchController =
                    TextEditingController();
                List<Map<String, dynamic>> filteredLanguages =
                    List.from(_languages);

                return StatefulBuilder(
                  builder: (context, setState) {
                    return Container(
                      height: 400,
                      decoration: BoxDecoration(
                        color: theme.surface,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          topRight: Radius.circular(20),
                        ),
                      ),
                      child: Column(
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 8),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: theme.outlineVariant,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: TextField(
                              controller: searchController,
                              decoration: InputDecoration(
                                hintText: 'Search languages',
                                prefixIcon:
                                    Icon(Icons.search, color: theme.primary),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: theme.outlineVariant),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide:
                                      BorderSide(color: theme.outlineVariant),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: theme.primary),
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value.trim().isEmpty) {
                                    filteredLanguages = List.from(_languages);
                                  } else {
                                    filteredLanguages =
                                        _languages.where((lang) {
                                      final name = lang['name']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '';
                                      final native = lang['native']
                                              ?.toString()
                                              .toLowerCase() ??
                                          '';
                                      final searchTerm = value.toLowerCase();
                                      return name.contains(searchTerm) ||
                                          native.contains(searchTerm);
                                    }).toList();
                                  }
                                });
                              },
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: filteredLanguages.length,
                              itemBuilder: (context, index) {
                                final lang = filteredLanguages[index];
                                final isSelected =
                                    tempSelected.contains(lang['name']);
                                return CheckboxListTile(
                                  value: isSelected,
                                  title: Text(
                                    lang['name'] ?? lang['native'] ?? '',
                                    style: TextStyle(color: theme.onSurface),
                                  ),
                                  activeColor: theme.primary,
                                  onChanged: (checked) {
                                    setState(() {
                                      if (checked == true) {
                                        tempSelected.add(lang['name']);
                                      } else {
                                        tempSelected.remove(lang['name']);
                                      }
                                    });
                                  },
                                );
                              },
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () {
                                      if (Navigator.canPop(context)) {
                                        Navigator.of(context).pop(null);
                                      }
                                    },
                                    child: const Text('Cancel'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (Navigator.canPop(context)) {
                                        Navigator.of(context).pop(tempSelected);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: theme.primary,
                                    ),
                                    child: const Text('Confirm'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            );
            if (result != null) {
              setState(() {
                _selectedLanguages = result;
                _languageRequirement = _selectedLanguages.join(', ');
              });
            }
          },
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border.all(
                color: _errorFields.contains('Language Requirement')
                    ? theme.error
                    : theme.outlineVariant,
                width: _errorFields.contains('Language Requirement') ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _errorFields.contains('Language Requirement')
                  ? theme.error.withValues(alpha: 0.1)
                  : theme.surface,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: _errorFields.contains('Language Requirement')
                      ? theme.error
                      : theme.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedLanguages.isEmpty
                      ? Text(
                          'Select preferred languages',
                          style: TextStyle(
                              color: theme.onSurface.withValues(alpha: 0.6)),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedLanguages.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: theme.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  color: theme.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                Icon(
                  Icons.arrow_drop_down,
                  color: theme.primary,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWarningMessage() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.error.withOpacity(0.1),
        border: Border.all(color: theme.error.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: theme.error,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please abide by platform regulations and do not post false or fraudulent information. Violators will be held legally responsible.',
              style: TextStyle(
                color: theme.error,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primary,
          foregroundColor: theme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 2,
        ),
        onPressed: () async {
          final user =
              Provider.of<UserService>(context, listen: false).currentUser;
          final data = {
            'title': _titleController.text.trim(),
            'description': _taskDescriptionController.text.trim(),
            'reward_point':
                _formatRewardPoint(_rewardPointController.text.trim()),
            'location': () {
              // 檢查是否有匹配的大學
              final matched = _universities.firstWhere(
                (uni) =>
                    uni['en_name'] == _locationLabel ||
                    uni['zh_name'] == _locationLabel,
                orElse: () => <String, dynamic>{},
              );
              if (matched.isNotEmpty) {
                return matched['abbr']!; // 返回大學縮寫
              }
              return _locationLabel.isNotEmpty ? _locationLabel : 'N/A';
            }(),
            'task_date': _taskDate != null
                ? _taskDate!.toLocal().toString().split(' ')[0]
                : 'N/A',
            'periodStart': _periodStart != null
                ? _periodStart!.toLocal().toString().split(' ')[0]
                : 'N/A',
            'periodEnd': _periodEnd != null
                ? _periodEnd!.toLocal().toString().split(' ')[0]
                : 'N/A',
            'application_question': _applicationQuestions.join(' | '),
            'avatar_url': user?.avatar_url ?? '',
            'language_requirement': _selectedLanguages.join(','),
            'creator_id': user?.id ?? 'Unknown',
          };

          final requiredFields = {
            kTaskTitleField: data['title'],
            kRewardPointField: data['reward_point'],
            kTimeField: data['task_date'],
            kPostingPeriodField:
                data['periodStart'] != 'N/A' && data['periodEnd'] != 'N/A',
            'Description': data['description'],
          };

          _errorFields.clear();
          requiredFields.forEach((key, value) {
            if (key == kPostingPeriodField) {
              if (value != true) _errorFields.add(key);
            } else if (value == null ||
                (value as String).isEmpty ||
                value == 'N/A') {
              _errorFields.add(key);
            }
          });

          for (int i = 0; i < _applicationQuestions.length; i++) {
            if (_applicationQuestions[i].trim().isEmpty) {
              _errorFields.add('ApplicationQuestion$i');
            } else if (_applicationQuestions[i].length > 500) {
              _errorFields.add('ApplicationQuestion$i');
            }
          }

          if (_errorFields.isNotEmpty) {
            setState(() {});

            // 檢查是否有字數超限的問題
            bool hasLengthError = false;
            for (int i = 0; i < _applicationQuestions.length; i++) {
              if (_applicationQuestions[i].length > 500) {
                hasLengthError = true;
                break;
              }
            }

            String errorMessage = hasLengthError
                ? 'Please check all required fields and ensure questions are within 500 characters.'
                : 'Please fill in all required fields.';

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorMessage),
                backgroundColor: theme.error,
              ),
            );
            return;
          }

          // 使用 SharedPreferences 儲存資料
          try {
            debugPrint('🔍 正在保存任務資料到 SharedPreferences...');
            debugPrint('🔍 要保存的資料: ${jsonEncode(data)}');

            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('taskData', jsonEncode(data));

            // 驗證資料是否正確保存
            final savedData = prefs.getString('taskData');
            debugPrint('🔍 驗證已保存的資料: $savedData');

            debugPrint('✅ 任務資料保存成功，準備導航到預覽頁面');

            // 導航到預覽頁面
            if (mounted) {
              try {
                context.go('/task/create/preview');
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Navigation error: $e'),
                    backgroundColor: theme.error,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving task data: $e'),
                  backgroundColor: theme.error,
                ),
              );
            }
          }
        },
        child: const Text(
          'Preview & Submit',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildFormCard({
    required String title,
    required IconData icon,
    required Widget child,
    bool isRequired = false,
    bool isError = false,
  }) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isError ? theme.error : theme.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isError ? theme.error : theme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isError ? theme.error : Colors.black87,
                    ),
                  ),
                ),
                if (isRequired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Required',
                      style: TextStyle(
                        color: theme.error,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  void _selectDate(
      BuildContext context, ValueChanged<DateTime> onPicked) async {
    DateTime now = DateTime.now();
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) onPicked(picked);
  }

  void _showLocationPicker(BuildContext context) {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    LatLng center = _selectedLocation ?? const LatLng(25.0173, 121.5415);

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) {
        bool hasSearched = false;
        bool dialogActive = true;
        return StatefulBuilder(
          builder: (context, setState) {
            if (!hasSearched) {
              hasSearched = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (dialogActive) {
                  _moveToSearchLocation(_locationSearchController.text, (fn) {
                    if (dialogActive) setState(fn);
                  });
                }
              });
            }
            return AlertDialog(
              title: const Text('Select your location'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _locationSearchController,
                            decoration: const InputDecoration(
                              hintText: 'Search location',
                            ),
                            onSubmitted: (value) async {
                              await _moveToSearchLocation(value, setState);
                            },
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.search),
                          onPressed: () async {
                            await _moveToSearchLocation(
                                _locationSearchController.text, setState);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 16.0,
                          onTap: (tapPosition, point) async {
                            setState(() {
                              _selectedLocation = point;
                              _mapController.move(
                                  point, _mapController.camera.zoom);
                            });
                            final label = await _reverseGeocode(point);
                            setState(() {
                              _locationLabel = label;
                            });
                          },
                        ),
                        children: [
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.example.app',
                          ),
                          if (_selectedLocation != null)
                            MarkerLayer(
                              markers: [
                                Marker(
                                  width: 40,
                                  height: 40,
                                  point: _selectedLocation!,
                                  child: Icon(Icons.location_pin,
                                      color: theme.primary, size: 40),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    dialogActive = false;
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop();
                    }
                  },
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    dialogActive = false;
                    if (Navigator.canPop(dialogContext)) {
                      Navigator.of(dialogContext).pop({
                        'location': _selectedLocation,
                        'label': _locationLabel
                      });
                    }
                  },
                  child: const Text('Confirm Location'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      if (result != null && mounted) {
        setState(() {
          _selectedLocation = result['location'];
          _locationLabel = result['label'];
        });
      }
    });
  }

  void _useCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _showError('Location permission denied.');
        return;
      }
    }

    final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
    final point = LatLng(position.latitude, position.longitude);
    setState(() {
      _selectedLocation = point;
    });
    final label = await _reverseGeocode(point);
    setState(() {
      _locationLabel = label;
    });
  }

  void _showError(String msg) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Location Error'),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  /// 創建任務的方法
  Future<void> _createTask(Map<String, dynamic> taskData) async {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    try {
      final taskService = TaskService();
      final success = await taskService.createTask(taskData);

      if (success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('任務創建成功！'),
              backgroundColor: Colors.green,
            ),
          );
          // 導航回任務列表頁面
          if (mounted) {
            try {
              context.go('/task/list');
            } catch (e) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Navigation error: $e'),
                  backgroundColor: theme.error,
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('創建失敗: ${taskService.error ?? '未知錯誤'}'),
              backgroundColor: theme.error,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('創建任務時發生錯誤: $e'),
            backgroundColor: theme.error,
          ),
        );
      }
    }
  }

  Widget _buildTimeSection() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Time Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 16),

        // Task Date
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Task Date',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: theme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () async {
                  _errorFields.remove('Time');
                  _selectDate(context, (picked) {
                    setState(() => _taskDate = picked);
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _errorFields.contains('Time')
                          ? theme.error
                          : Colors.grey[300]!,
                      width: _errorFields.contains('Time') ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _errorFields.contains('Time')
                        ? theme.error.withOpacity(0.1)
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _errorFields.contains('Time')
                            ? theme.error
                            : theme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _taskDate != null
                              ? DateFormat('yyyy-MM-dd').format(_taskDate!)
                              : 'Select date',
                          style: TextStyle(
                            color: _taskDate != null
                                ? Colors.black87
                                : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        color: theme.primary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Posting Period
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Posting Period',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: theme.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Required',
                    style: TextStyle(
                      color: theme.error,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildDateField(
                    'Start Date',
                    _periodStart,
                    (picked) async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 1),
                      );
                      if (picked != null) {
                        TimeOfDay? timePicked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (timePicked != null) {
                          DateTime combined = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            timePicked.hour,
                            timePicked.minute,
                          );
                          if (combined.isBefore(DateTime.now())) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'Start date cannot be earlier than the current time.'),
                                backgroundColor: theme.error,
                              ),
                            );
                          } else {
                            if (mounted) {
                              setState(() {
                                _periodStart = combined;
                              });
                            }
                          }
                        }
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                const Icon(Icons.arrow_forward, color: Colors.grey),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildDateField(
                    'End Date',
                    _periodEnd,
                    (picked) async {
                      DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime.now(),
                        lastDate: DateTime(DateTime.now().year + 1),
                      );
                      if (picked != null) {
                        TimeOfDay? timePicked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (timePicked != null) {
                          DateTime combined = DateTime(
                            picked.year,
                            picked.month,
                            picked.day,
                            timePicked.hour,
                            timePicked.minute,
                          );
                          if (_periodStart != null &&
                              combined.isBefore(_periodStart!)) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                    'End date cannot be earlier than or equal to the start date.'),
                                backgroundColor: theme.error,
                              ),
                            );
                          } else {
                            if (mounted) {
                              setState(() {
                                _periodEnd = combined;
                              });
                            }
                          }
                        }
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuestionsSection() {
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Application Questions',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: theme.primary,
          ),
        ),
        const SizedBox(height: 16),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _applicationQuestions.length,
          itemBuilder: (context, index) {
            final labelNumber = (index + 1).toString().padLeft(2, '0');
            return Padding(
              key: ValueKey('question_$index'),
              padding: const EdgeInsets.only(bottom: 12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: _errorFields.contains('ApplicationQuestion$index') ||
                            (_showApplicationQuestionErrors &&
                                _applicationQuestions[index].trim().isEmpty)
                        ? theme.error
                        : Colors.grey[300]!,
                    width: _errorFields.contains('ApplicationQuestion$index') ||
                            (_showApplicationQuestionErrors &&
                                _applicationQuestions[index].trim().isEmpty)
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _errorFields.contains('ApplicationQuestion$index') ||
                          (_showApplicationQuestionErrors &&
                              _applicationQuestions[index].trim().isEmpty)
                      ? theme.error.withValues(alpha: 0.1)
                      : Colors.white,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q-$labelNumber',
                            style: TextStyle(
                              color: theme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Question ${index + 1}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: theme.error,
                            size: 20,
                          ),
                          onPressed: () async {
                            // 確保索引在有效範圍內
                            if (index >= 0 &&
                                index < _applicationQuestions.length) {
                              final hasValue = _applicationQuestions[index]
                                  .trim()
                                  .isNotEmpty;
                              if (hasValue) {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext dialogContext) =>
                                      AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: Text(
                                        'Are you sure you want to delete question ${index + 1}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () {
                                          if (Navigator.canPop(dialogContext)) {
                                            Navigator.of(dialogContext)
                                                .pop(false);
                                          }
                                        },
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          if (Navigator.canPop(dialogContext)) {
                                            Navigator.of(dialogContext)
                                                .pop(true);
                                          }
                                        },
                                        child: Text('Delete',
                                            style:
                                                TextStyle(color: theme.error)),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _removeApplicationQuestion(index);
                                }
                              } else {
                                _removeApplicationQuestion(index);
                              }
                            }
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextFormField(
                          initialValue: _applicationQuestions[index],
                          maxLength: 500, // 設定字數上限為500字
                          maxLines: 4, // 限制最大行數
                          decoration: InputDecoration(
                            hintText:
                                'Job seekers must answer questions before applying, helping you screen talents faster',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.grey[50],
                            counterText: '', // 隱藏預設的字數計數器
                          ),
                          onChanged: (value) {
                            setState(() {
                              _applicationQuestions[index] = value;
                              // 如果用戶開始填寫問題，清除錯誤顯示狀態
                              if (value.trim().isNotEmpty &&
                                  _showApplicationQuestionErrors) {
                                _showApplicationQuestionErrors = false;
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${_applicationQuestions[index].length}/500 characters',
                              style: TextStyle(
                                fontSize: 12,
                                color: _applicationQuestions[index].length > 500
                                    ? theme.error
                                    : _applicationQuestions[index].length > 450
                                        ? Colors.orange
                                        : Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_applicationQuestions[index].length > 480)
                              Row(
                                children: [
                                  Icon(
                                    _applicationQuestions[index].length > 500
                                        ? Icons.error_outline
                                        : Icons.warning_amber_rounded,
                                    size: 16,
                                    color: _applicationQuestions[index].length >
                                            500
                                        ? theme.error
                                        : Colors.orange,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _applicationQuestions[index].length > 500
                                        ? '字數超限'
                                        : '接近字數上限',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color:
                                          _applicationQuestions[index].length >
                                                  500
                                              ? theme.error
                                              : Colors.orange,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            // 顯示未填寫問題的錯誤提示
                            if (_showApplicationQuestionErrors &&
                                _applicationQuestions[index].trim().isEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: theme.error,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Please fill in this question',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.error,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        if (_applicationQuestions.length < 3)
          Center(
            child: OutlinedButton.icon(
              onPressed: _addApplicationQuestion,
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: theme.primary),
                backgroundColor: theme.primary.withValues(alpha: 0.1),
              ),
              icon: Icon(Icons.add, color: theme.primary),
              label: Text(
                'Add Question',
                style: TextStyle(color: theme.primary),
              ),
            ),
          ),
      ],
    );
  }
}

String _extractLandmarkName(String displayName) {
  return displayName.split(',').first.trim();
}

Future<String> _reverseGeocode(LatLng point) async {
  final url =
      Uri.parse('https://nominatim.openstreetmap.org/reverse?format=json'
          '&lat=${point.latitude}&lon=${point.longitude}&accept-language=en');
  final response = await http.get(url, headers: {'User-Agent': 'flutter_app'});
  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    return _extractLandmarkName(data['display_name'] ?? 'Unknown location');
  } else {
    return 'Unknown location';
  }
}

extension _MoveToSearchLocationExtension on _PostFormPageState {
  Future<void> _moveToSearchLocation(String query,
      [void Function(void Function())? dialogSetState]) async {
    if (query.trim().isEmpty) return;

    // 檢查大學匹配 - 優先檢查縮寫，然後檢查英文名稱
    final matched = _universities.firstWhere(
      (uni) =>
          uni['abbr']!.toLowerCase() == query.toLowerCase() ||
          uni['en_name']!.toLowerCase().contains(query.toLowerCase()) ||
          uni['zh_name']!.toLowerCase().contains(query.toLowerCase()),
      orElse: () => <String, dynamic>{},
    );

    if (matched.isNotEmpty) {
      // 如果找到匹配的大學，使用中文名稱進行搜尋
      query = matched['zh_name']!;
    }

    try {
      final url = Uri.parse(
          'https://nominatim.openstreetmap.org/search?q=$query&format=json&countrycodes=tw&accept-language=en');
      final response =
          await http.get(url, headers: {'User-Agent': 'flutter_app'});

      if (response.statusCode == 200) {
        final List results = json.decode(response.body);
        if (results.isNotEmpty) {
          final lat = double.parse(results[0]['lat']);
          final lon = double.parse(results[0]['lon']);
          LatLng newCenter = LatLng(lat, lon);

          if (dialogSetState != null) {
            dialogSetState(() {
              _selectedLocation = newCenter;
              _mapController.move(newCenter, _mapController.camera.zoom);
            });
          } else if (mounted) {
            setState(() {
              _selectedLocation = newCenter;
              _mapController.move(newCenter, _mapController.camera.zoom);
            });
          }

          final label = await _reverseGeocode(newCenter);
          if (dialogSetState != null) {
            dialogSetState(() {
              _locationLabel = label;
            });
          } else if (mounted) {
            setState(() {
              _locationLabel = label;
            });
          }
        } else {
          if (mounted) {
            _showError('Location not found. Please try a different address.');
          }
        }
      } else {
        if (mounted) {
          _showError(
              'Unable to search location. Please check your internet connection.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Failed to search location. Please try again.');
      }
    }
  }

  // 格式化 reward_point，移除格式化字符並返回純數字
  String _formatRewardPoint(String value) {
    if (value.isEmpty) return '0';
    try {
      // 移除所有非數字字符（除了小數點）
      final cleanValue = value.replaceAll(RegExp(r'[^\d.]'), '');
      if (cleanValue.isEmpty) return '0';

      final num = double.tryParse(cleanValue);
      if (num == null) return '0';
      return num.toStringAsFixed(0); // 返回整數格式
    } catch (e) {
      return '0';
    }
  }
}
