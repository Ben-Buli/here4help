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
import 'package:here4help/utils/path_mapper.dart';

const String kTaskTitleField = 'Task Title';
const String kSalaryField = 'Salary';
const String kTimeField = 'Time';
const String kPostingPeriodField = 'Posting period';

class TaskCreatePage extends StatefulWidget {
  const TaskCreatePage({super.key});

  @override
  State<TaskCreatePage> createState() => _PostFormPageState();
}

class _PostFormPageState extends State<TaskCreatePage> {
  final MapController _mapController = MapController();
  final TextEditingController _salaryController = TextEditingController();
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
  final List<String> _applicationQuestions = [''];
  List<Map<String, dynamic>> _universities = [];
  List<Map<String, dynamic>> _languages = [];

  @override
  void initState() {
    super.initState();

    // 初始化表單欄位
    _titleController.text = 'Opening Bank Account (Demo)';
    _taskDescriptionController = TextEditingController(
        text:
            'Need help with opening a bank account. Looking for someone who can guide me through the process and accompany me to the bank.');
    final formatter = NumberFormat('#,##0', 'en_US');
    _salaryController.text = formatter.format(500);
    _locationLabel = 'NCCU';
    _locationSearchController.text = 'NCCU';
    final now = DateTime.now();
    _taskDate = DateTime(now.year, now.month, now.day, now.hour, now.minute);
    _periodStart = DateTime(2025, 9, 10, 12, 0);
    _periodEnd = DateTime(2025, 9, 10, 13, 0);
    _applicationQuestions[0] = 'Do you have relevant experience?';
    _languageRequirement = 'English,Japanese';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedLanguages = _languageRequirement.split(',');
        });
        // 測試頭像讀取功能
        _testAvatarLoading();
      }
    });

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
      });
    } catch (e) {
      setState(() {
        _languages = [
          {'code': 'en', 'name': 'English', 'native': 'English'},
          {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
          {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
          {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
        ];
      });
    }
  }

  void _addApplicationQuestion() {
    if (_applicationQuestions.isEmpty ||
        _applicationQuestions.last.trim().isNotEmpty) {
      setState(() {
        _applicationQuestions.add('');
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the previous question first.'),
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

  ImageProvider? _getAvatarImage() {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      try {
        // 檢查是否是 Flutter assets 路徑
        final isAsset = PathMapper.isFlutterAsset(avatarUrl);

        // 檢查是否是本地資源
        final isLocalAsset = ImageHelper.isLocalAsset(avatarUrl);

        // 檢查是否是網路圖片
        final isNetworkImage = ImageHelper.isNetworkImage(avatarUrl);

        // 直接測試 AssetImage 創建
        if (avatarUrl.startsWith('assets/')) {
          final directAssetImage = AssetImage(avatarUrl);
        }

        final imageProvider = ImageHelper.getAvatarImage(avatarUrl);
        return imageProvider;
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  Widget? _getAvatarChild() {
    final user = Provider.of<UserService>(context, listen: false).currentUser;
    final avatarUrl = user?.avatar_url;

    if (avatarUrl == null || avatarUrl.isEmpty) {
      final themeManager =
          Provider.of<ThemeConfigManager>(context, listen: false);
      final theme = themeManager.effectiveTheme;
      return Icon(
        Icons.person,
        color: theme.primary,
        size: 24,
      );
    }
    return null;
  }

  /// 測試頭像讀取功能
  void _testAvatarLoading() {
    final user = Provider.of<UserService>(context, listen: false).currentUser;

    if (user?.avatar_url != null && user!.avatar_url.isNotEmpty) {
      try {
        // 直接測試 AssetImage
        if (user.avatar_url.startsWith('assets/')) {
          final assetImage = AssetImage(user.avatar_url);

          // 測試 PathMapper.isFlutterAsset
          final isFlutterAsset = PathMapper.isFlutterAsset(user.avatar_url);
        }

        final imageProvider = ImageHelper.getAvatarImage(user.avatar_url);
      } catch (e) {
        // Error handling
      }
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
    final themeManager =
        Provider.of<ThemeConfigManager>(context, listen: false);
    final theme = themeManager.effectiveTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Personal Information',
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
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Row(
            children: [
              Builder(
                builder: (context) {
                  final avatarImage = _getAvatarImage();
                  return CircleAvatar(
                    radius: 24,
                    backgroundColor: theme.primary.withOpacity(0.1),
                    backgroundImage: avatarImage,
                    onBackgroundImageError: avatarImage != null
                        ? (exception, stackTrace) {
                            debugPrint('❌ Avatar loading error: $exception');
                          }
                        : null,
                    child: _getAvatarChild(),
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Provider.of<UserService>(context, listen: false)
                              .currentUser
                              ?.name ??
                          'Unknown Poster',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Task Creator',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 20,
              ),
            ],
          ),
        ),
      ],
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red,
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
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

        // Salary
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Reward',
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red,
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
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(8),
                        bottomLeft: Radius.circular(8),
                      ),
                    ),
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
                      controller: _salaryController,
                      keyboardType: TextInputType.number,
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
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a salary';
                        }
                        // 檢查是否為有效數字
                        final number = double.tryParse(value);
                        if (number == null) {
                          return 'Please enter a valid number';
                        }
                        // 檢查是否小於0
                        if (number < 0) {
                          return 'Salary cannot be negative';
                        }
                        return null;
                      },
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 12),
                    decoration: BoxDecoration(
                      color: theme.primary.withOpacity(0.1),
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(8),
                        bottomRight: Radius.circular(8),
                      ),
                    ),
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red,
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
                  borderSide:
                      const BorderSide(color: AppColors.primary, width: 2),
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
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: const BorderSide(color: Colors.red, width: 2),
          ),
          filled: true,
          fillColor: _errorFields.contains(kTaskTitleField)
              ? Colors.red[50]
              : Colors.white,
          prefixIcon: Icon(
            Icons.edit,
            color: _errorFields.contains(kTaskTitleField)
                ? Colors.red
                : AppColors.primary,
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

  Widget _buildSalaryCard() {
    return _buildFormCard(
      title: 'Reward',
      icon: Icons.attach_money,
      isRequired: true,
      isError: _errorFields.contains(kSalaryField),
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: _errorFields.contains(kSalaryField)
                ? Colors.red
                : Colors.grey[300]!,
            width: _errorFields.contains(kSalaryField) ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: _errorFields.contains(kSalaryField)
              ? Colors.red[50]
              : Colors.white,
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
                controller: _salaryController,
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
                  _salaryController.value = TextEditingValue(
                    text: formatted,
                    selection:
                        TextSelection.collapsed(offset: formatted.length),
                  );
                  if (_errorFields.contains(kSalaryField)) {
                    setState(() => _errorFields.remove(kSalaryField));
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
                '/hour',
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
              const Icon(
                Icons.location_on,
                color: AppColors.primary,
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
              const Icon(
                Icons.chevron_right,
                color: AppColors.primary,
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
                  ? Colors.red
                  : Colors.grey[300]!,
              width: _errorFields.contains('Time') ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color:
                _errorFields.contains('Time') ? Colors.red[50] : Colors.white,
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                color:
                    _errorFields.contains('Time') ? Colors.red : theme.primary,
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
                            const SnackBar(
                              content: Text(
                                  'Start date cannot be earlier than the current time.'),
                              backgroundColor: Colors.red,
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
                            const SnackBar(
                              content: Text(
                                  'End date cannot be earlier than or equal to the start date.'),
                              backgroundColor: Colors.red,
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
                            _applicationQuestions[index].length > 500
                        ? Colors.red
                        : Colors.grey[300]!,
                    width: _errorFields.contains('ApplicationQuestion$index') ||
                            _applicationQuestions[index].length > 500
                        ? 2
                        : 1,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: _errorFields.contains('ApplicationQuestion$index') ||
                          _applicationQuestions[index].length > 500
                      ? Colors.red[50]
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
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Q$labelNumber',
                            style: const TextStyle(
                              color: AppColors.primary,
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
                                color: Colors.red[400],
                                size: 20,
                              ),
                              onPressed: () async {
                                final hasValue = _applicationQuestions[index]
                                    .trim()
                                    .isNotEmpty;
                                if (hasValue) {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Confirm Delete'),
                                      content: const Text(
                                          'Are you sure you want to delete this question?'),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text('Delete',
                                              style:
                                                  TextStyle(color: Colors.red)),
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
                        });
                      },
                    ),
                  ],
                ),
              ),
            );
          }),
          if (_applicationQuestions.length < 3)
            Center(
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: TextButton.icon(
                  onPressed: _addApplicationQuestion,
                  icon: const Icon(Icons.add, color: AppColors.primary),
                  label: const Text(
                    'Add Question',
                    style: TextStyle(color: AppColors.primary),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLanguageRequirementCard() {
    return _buildFormCard(
      title: 'Language Requirements',
      icon: Icons.language,
      isRequired: true,
      isError: _errorFields.contains('Language Requirement'),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () async {
            final result = await showModalBottomSheet<List<String>>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (context) {
                List<String> tempSelected = List.from(_selectedLanguages);
                TextEditingController searchController =
                    TextEditingController();
                return Container(
                  height: 400,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search languages',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _languages.length,
                          itemBuilder: (context, index) {
                            final lang = _languages[index];
                            final isSelected =
                                tempSelected.contains(lang['code']);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(lang['native'] ?? lang['name'] ?? ''),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    tempSelected.add(lang['code']);
                                  } else {
                                    tempSelected.remove(lang['code']);
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
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, tempSelected),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
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
                    ? Colors.red
                    : Colors.grey[300]!,
                width: _errorFields.contains('Language Requirement') ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _errorFields.contains('Language Requirement')
                  ? Colors.red[50]
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: _errorFields.contains('Language Requirement')
                      ? Colors.red
                      : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedLanguages.isEmpty
                      ? Text(
                          'Select preferred languages',
                          style: TextStyle(color: Colors.grey[500]),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedLanguages.map((code) {
                            final language = _languages.firstWhere(
                              (lang) => lang['code'] == code,
                              orElse: () => {'native': code},
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                language['native'] ?? code,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWarningMessage() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        border: Border.all(color: Colors.orange[200]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            color: Colors.orange[700],
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please abide by platform regulations and do not post false or fraudulent information. Violators will be held legally responsible.',
              style: TextStyle(
                color: Colors.orange[800],
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
          final userName = user?.name ?? 'Unknown Poster';
          final data = {
            'title': _titleController.text.trim(),
            'description': _taskDescriptionController.text.trim(),
            'salary': _salaryController.text.trim(),
            'location': _locationLabel.isNotEmpty ? _locationLabel : 'N/A',
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
            'creator_name': userName,
            'avatar_url': user?.avatar_url ?? '',
            'language_requirement': _selectedLanguages.join(','),
            'creator_id': user?.id ?? 'Unknown',
          };

          final requiredFields = {
            kTaskTitleField: data['title'],
            kSalaryField: data['salary'],
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
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          // 使用 SharedPreferences 儲存資料
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('taskData', jsonEncode(data));

            // 導航到預覽頁面
            if (mounted) {
              context.push('/task/create/preview');
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error saving task data: $e'),
                  backgroundColor: Colors.red,
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
                    color: (isError ? Colors.red : AppColors.primary)
                        .withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: isError ? Colors.red : AppColors.primary,
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
                      color: isError ? Colors.red : Colors.black87,
                    ),
                  ),
                ),
                if (isRequired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'Required',
                      style: TextStyle(
                        color: Colors.red,
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
    LatLng center = _selectedLocation ?? const LatLng(25.0173, 121.5415);

    showDialog(
      context: context,
      builder: (context) {
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
                                  child: const Icon(Icons.location_pin,
                                      color: Colors.red, size: 40),
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
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    dialogActive = false;
                    Navigator.pop(context, {
                      'location': _selectedLocation,
                      'label': _locationLabel
                    });
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
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Incomplete Form'),
        content: Text(msg),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('OK')),
        ],
      ),
    );
  }

  /// 創建任務的方法
  Future<void> _createTask(Map<String, dynamic> taskData) async {
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
          context.go('/task/list');
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('創建失敗: ${taskService.error ?? '未知錯誤'}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('創建任務時發生錯誤: $e'),
            backgroundColor: Colors.red,
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red,
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
                          ? Colors.red
                          : Colors.grey[300]!,
                      width: _errorFields.contains('Time') ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(8),
                    color: _errorFields.contains('Time')
                        ? Colors.red[50]
                        : Colors.white,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: _errorFields.contains('Time')
                            ? Colors.red
                            : AppColors.primary,
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
                      const Icon(
                        Icons.arrow_drop_down,
                        color: AppColors.primary,
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
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    'Required',
                    style: TextStyle(
                      color: Colors.red,
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
                              const SnackBar(
                                content: Text(
                                    'Start date cannot be earlier than the current time.'),
                                backgroundColor: Colors.red,
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
                              const SnackBar(
                                content: Text(
                                    'End date cannot be earlier than or equal to the start date.'),
                                backgroundColor: Colors.red,
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
        ...List.generate(_applicationQuestions.length, (index) {
          final labelNumber = (index + 1).toString().padLeft(2, '0');
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(
                  color: _errorFields.contains('ApplicationQuestion$index')
                      ? Colors.red
                      : Colors.grey[300]!,
                  width: _errorFields.contains('ApplicationQuestion$index')
                      ? 2
                      : 1,
                ),
                borderRadius: BorderRadius.circular(8),
                color: _errorFields.contains('ApplicationQuestion$index')
                    ? Colors.red[50]
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
                      if (_applicationQuestions.length > 1)
                        IconButton(
                          icon: Icon(
                            Icons.delete,
                            color: Colors.red[400],
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
                                  builder: (context) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: Text(
                                        'Are you sure you want to delete question ${index + 1}?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete',
                                            style:
                                                TextStyle(color: Colors.red)),
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
                              'Enter your question for applicants (max 500 characters)',
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
                                  ? Colors.red
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
                                  color:
                                      _applicationQuestions[index].length > 500
                                          ? Colors.red
                                          : Colors.orange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _applicationQuestions[index].length > 500
                                      ? '字數超限'
                                      : '接近字數上限',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _applicationQuestions[index].length >
                                            500
                                        ? Colors.red
                                        : Colors.orange,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                        ],
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
            child: TextButton.icon(
              onPressed: _addApplicationQuestion,
              icon: const Icon(Icons.add, color: AppColors.primary),
              label: const Text(
                'Add Question',
                style: TextStyle(color: AppColors.primary),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildLanguageSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Language Requirements',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                'Required',
                style: TextStyle(
                  color: Colors.red,
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
                return Container(
                  height: 400,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
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
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: 'Search languages',
                            prefixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _languages.length,
                          itemBuilder: (context, index) {
                            final lang = _languages[index];
                            final isSelected =
                                tempSelected.contains(lang['code']);
                            return CheckboxListTile(
                              value: isSelected,
                              title: Text(lang['native'] ?? lang['name'] ?? ''),
                              onChanged: (checked) {
                                setState(() {
                                  if (checked == true) {
                                    tempSelected.add(lang['code']);
                                  } else {
                                    tempSelected.remove(lang['code']);
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
                                onPressed: () => Navigator.pop(context, null),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () =>
                                    Navigator.pop(context, tempSelected),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
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
                    ? Colors.red
                    : Colors.grey[300]!,
                width: _errorFields.contains('Language Requirement') ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(8),
              color: _errorFields.contains('Language Requirement')
                  ? Colors.red[50]
                  : Colors.white,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.language,
                  color: _errorFields.contains('Language Requirement')
                      ? Colors.red
                      : AppColors.primary,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _selectedLanguages.isEmpty
                      ? Text(
                          'Select preferred languages',
                          style: TextStyle(color: Colors.grey[500]),
                        )
                      : Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: _selectedLanguages.map((code) {
                            final language = _languages.firstWhere(
                              (lang) => lang['code'] == code,
                              orElse: () => {'native': code},
                            );
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                language['native'] ?? code,
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                ),
                const Icon(
                  Icons.arrow_drop_down,
                  color: AppColors.primary,
                ),
              ],
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
    final matched = _universities.firstWhere(
      (uni) =>
          uni['en_name']!.toLowerCase().contains(query.toLowerCase()) ||
          uni['abbr']!.toLowerCase() == query.toLowerCase(),
      orElse: () => <String, dynamic>{},
    );
    if (matched.isNotEmpty) {
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
          if (mounted) _showError('Location not found.');
        }
      } else {
        if (mounted) _showError('Location not found.');
      }
    } catch (e) {
      if (mounted) _showError('Failed to search location: $e');
    }
  }
}
