import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/task/services/university_service.dart';
import 'package:here4help/task/services/language_service.dart';

import 'package:here4help/services/theme_config_manager.dart';
import 'package:here4help/constants/countries.dart';
import 'package:here4help/constants/genders.dart';
import 'package:here4help/constants/languages.dart';
import 'package:here4help/constants/universities.dart';
import 'package:here4help/services/api/profile_api.dart';
import 'package:here4help/widgets/avatar_upload_widget.dart';
import 'package:here4help/utils/avatar_url_test.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // 控制每個欄位是否進入編輯狀態
  String? editingField;
  bool isLoading = false;
  bool hasChanges = false;

  // 用戶資料
  UserModel? user;
  bool _userLoaded = false;

  // 欄位控制器
  final Map<String, TextEditingController> controllers = {
    'name': TextEditingController(),
    'nickname': TextEditingController(),
    'phone': TextEditingController(),
    'dateOfBirth': TextEditingController(),
    'country': TextEditingController(),
    'address': TextEditingController(),
    'primaryLanguage': TextEditingController(),
    'languageRequirement': TextEditingController(),
    'school': TextEditingController(),
    'aboutMe': TextEditingController(),
    'referralCode': TextEditingController(),
  };

  /// bool 欄位單獨用變數控制
  bool isPermanentAddress = false;

  // #region 資料載入
  // 大學列表
  List<Map<String, dynamic>> universities = [];
  String? selectedSchool;

  // 語言列表
  List<Map<String, dynamic>> languages = [];
  String? selectedPrimaryLanguage;
  List<String> selectedLanguageRequirements = [];

  // 原始資料（用於比較是否有變更）
  Map<String, dynamic> originalData = {};

  // 欄位驗證錯誤
  Map<String, String?> fieldErrors = {};

  // #endregion

  // region 生日格式
  /// [送出資料前再執行格式化]
  /// 將 8 碼日期 19970115 -> 1997-01-15
  String _compactDobToDashed(String input) {
    if (RegExp(r'^\d{8}$').hasMatch(input)) {
      final y = input.substring(0, 4);
      final m = input.substring(4, 6);
      final d = input.substring(6, 8);
      return '$y-$m-$d';
    }
    return input;
  }

  /// [取得資料後再執行去分隔線]
  /// 將 yyyy-mm-dd -> 19970115（若不是這種格式，就把非數字拿掉）
  String _dashedDobToCompact(String input) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(input);
    if (match != null) {
      return '${match.group(1)}${match.group(2)}${match.group(3)}';
    }
    return input.replaceAll(RegExp(r'\D'), '');
  }

  // #endregion

  // #region 初始化
  @override
  void initState() {
    super.initState();

    // 測試新的頭像 URL 管理系統
    AvatarUrlTest.runAllTests();

    _loadUserData();
    _loadUniversities();
    _loadLanguages();
  }
  // #endregion

  // #region 資料載入

  Future<void> _loadUserData() async {
    final userService = Provider.of<UserService>(context, listen: false);
    final current = userService.currentUser;
    if (current == null) {
      setState(() {
        _userLoaded = true; // loaded but no user; avoid spinner forever
      });
      return;
    }
    user = current;

    // region 初始化控制器
    controllers['name']!.text = user!.name;
    controllers['nickname']!.text = user!.nickname;
    controllers['phone']!.text = user!.phone;
    controllers['dateOfBirth']!.text =
        _dashedDobToCompact(user!.date_of_birth ?? '');
    controllers['country']!.text = user!.country ?? '';
    controllers['address']!.text = user!.address ?? '';
    debugPrint('is_permanent_address: ${user!.is_permanent_address}');
    isPermanentAddress = user!.is_permanent_address ?? false;
    controllers['aboutMe']!.text = user!.about_me ?? '';
    controllers['referralCode']!.text = user!.referral_code ?? '';
    controllers['primaryLanguage']!.text = user!.primary_language;
    controllers['aboutMe']!.text = user!.about_me ?? '';

    selectedSchool = user!.school;
    // Normalize empty school to null to avoid invalid dropdown value
    if (selectedSchool != null && selectedSchool!.trim().isEmpty) {
      selectedSchool = null;
    }
    // #endregion

    // region 確保語言數據已載入後再設置
    // 確保語言數據已載入後再設置
    selectedPrimaryLanguage = user!.primary_language;
    // Normalize empty primary language to null to avoid invalid dropdown value
    if (selectedPrimaryLanguage != null &&
        selectedPrimaryLanguage!.trim().isEmpty) {
      selectedPrimaryLanguage = null;
    }

    isPermanentAddress = user!.is_permanent_address ?? false;

    // 載入語言需求
    if (user!.language_requirement != null) {
      selectedLanguageRequirements = user!.language_requirement!.split(',');
    }

    // 儲存原始資料
    originalData = {
      'name': controllers['name']!.text,
      'nickname': controllers['nickname']!.text,
      'phone': controllers['phone']!.text,
      'dateOfBirth': controllers['dateOfBirth']!.text,
      'gender': user!.gender,
      'country': controllers['country']!.text,
      'address': controllers['address']!.text,
      'about_me': controllers['aboutMe']!.text,
      'school': selectedSchool,
      'referralCode': controllers['referralCode']!.text,
      'primaryLanguage': selectedPrimaryLanguage,
      'languageRequirements': selectedLanguageRequirements,
      'isPermanentAddress': isPermanentAddress,
    };
    setState(() {
      _userLoaded = true;
    });
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await UniversityService.getUniversities();
      setState(() {
        universities = unis;
      });
    } catch (e) {
      // 如果無法載入大學列表，使用預設列表
      debugPrint('Exchagnge default data, Error loading [universities]: $e');
      setState(() {
        universities = Universities.all;
      });
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await LanguageService.getLanguages();
      setState(() {
        languages = langs;
      });
    } catch (e) {
      // 如果無法載入語言列表，使用預設列表
      debugPrint('Exchagnge default data, Error loading [languages]: $e');
      setState(() {
        languages = Languages.all;
      });
    }
  }

  // #endregion

  // #region 資料比較

  void _checkForChanges() {
    final currentData = {
      'name': controllers['name']!.text,
      'nickname': controllers['nickname']!.text,
      'phone': controllers['phone']!.text,
      'dateOfBirth': _dashedDobToCompact(controllers['dateOfBirth']!.text),
      'gender': user!.gender,
      'country': controllers['country']!.text,
      'address': controllers['address']!.text,
      'aboutMe': controllers['aboutMe']!.text,
      'school': selectedSchool,
      'referralCode': controllers['referralCode']!.text,
      'primaryLanguage': selectedPrimaryLanguage,
      // 'languageRequirements': selectedLanguageRequirements,
      'about_me': controllers['aboutMe']!.text,
      'isPermanentAddress': isPermanentAddress,
    };

    setState(() {
      hasChanges = !mapEquals(originalData, currentData);
    });
  }

  // #endregion

  // #region 欄位更新

  /// 個別欄位更新函數
  Future<void> _updateSingleField(String fieldKey, dynamic value) async {
    // 先進行前端驗證
    String? validationError;

    switch (fieldKey) {
      case 'name':
        validationError = _validateField(fieldKey, controllers['name']!.text);
        break;
      case 'nickname':
        validationError =
            _validateField(fieldKey, controllers['nickname']!.text);
        break;
      case 'phone':
        validationError = _validateField(fieldKey, controllers['phone']!.text);
        break;
      case 'dob':
        validationError = _validateField(
            fieldKey, _dashedDobToCompact(controllers['dateOfBirth']!.text));
        break;
      case 'country':
        validationError =
            _validateField(fieldKey, controllers['country']!.text);
        break;
      case 'address':
        validationError =
            _validateField(fieldKey, controllers['address']!.text);
        break;
      case 'aboutMe':
        validationError =
            _validateField(fieldKey, controllers['aboutMe']!.text);
        break;
      case 'school':
        validationError = _validateField(fieldKey, selectedSchool ?? '');
        break;
    }

    if (validationError != null) {
      _showValidationError(validationError);
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      Map<String, dynamic> updateData = {};

      // 根據欄位類型設置更新資料
      switch (fieldKey) {
        case 'name':
          updateData['name'] = controllers['name']!.text;
          break;
        case 'nickname':
          updateData['nickname'] = controllers['nickname']!.text;
          break;
        case 'phone':
          updateData['phone'] = controllers['phone']!.text;
          break;
        case 'dob':
          updateData['dateOfBirth'] =
              _compactDobToDashed(controllers['dateOfBirth']!.text);
          break;
        case 'gender':
          updateData['gender'] = user!.gender;
          break;
        case 'country':
          updateData['country'] = controllers['country']!.text;
          break;
        case 'address':
          updateData['address'] = controllers['address']!.text;
          updateData['isPermanentAddress'] = isPermanentAddress;
          break;
        case 'aboutMe':
          updateData['aboutMe'] = controllers['aboutMe']!.text;
          break;
        case 'school':
          updateData['school'] = selectedSchool;
          break;
        case 'primaryLanguage':
          updateData['primaryLanguage'] = selectedPrimaryLanguage;
          break;
      }

      final response = await ProfileApi.updateProfile(
        name: updateData['name'],
        nickname: updateData['nickname'],
        phone: updateData['phone'],
        dateOfBirth: updateData['dateOfBirth'],
        gender: updateData['gender'],
        country: updateData['country'],
        address: updateData['address'],
        isPermanentAddress: updateData['isPermanentAddress'],
        primaryLanguage: updateData['primaryLanguage'],
        school: updateData['school'],
        aboutMe: updateData['aboutMe'],
      );

      if (!mounted) return;

      if (response['success'] == true) {
        // 更新本地用戶資料
        final userService = Provider.of<UserService>(context, listen: false);
        userService.setUser(UserModel.fromJson(response['data']));

        // 重新載入用戶資料
        await _loadUserData();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  '${_getFieldDisplayName(fieldKey)} updated successfully')),
        );
      } else {
        throw Exception(response['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('Error updating ${_getFieldDisplayName(fieldKey)}: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // #endregion

  // #region 縮放選單文字工具，避免溢出
  /// 共用：建立縮放避免超寬的 DropdownMenuItem
  DropdownMenuItem<String> _scaledMenuItem(
    String value,
    String label, {
    TextStyle? style,
  }) {
    return DropdownMenuItem<String>(
      value: value,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: double.infinity),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            label,
            style: style,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }

  /// 共用：選中值的 builder，讓選中區域也能縮小避免把 Row 撐爆
  List<Widget> _buildSelectedItemBuilders(
    List<String> labels, {
    TextStyle? style,
  }) {
    return labels
        .map((label) => ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: double.infinity),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  style: style,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ))
        .toList();
  }
  // #endregion

  // #region 欄位顯示名稱

  String _getFieldDisplayName(String fieldKey) {
    switch (fieldKey) {
      case 'name':
        return 'Name';
      case 'nickname':
        return 'Nickname';
      case 'phone':
        return 'Phone';
      case 'dob':
        return 'Birthday';
      case 'gender':
        return 'Gender';
      case 'country':
        return 'Country';
      case 'address':
        return 'Address';
      case 'aboutMe':
        return 'About Me';
      case 'school':
        return 'School';
      case 'primaryLanguage':
        return 'Primary Language';
      default:
        return 'Field';
    }
  }

  // #endregion

  // #region 欄位驗證

  /// 驗證欄位資料
  String? _validateField(String fieldKey, String value) {
    switch (fieldKey) {
      case 'name':
        if (value.trim().isEmpty) {
          return 'Name cannot be empty';
        }
        if (value.length > 100) {
          return 'Name cannot exceed 100 characters';
        }
        break;
      case 'nickname':
        if (value.length > 50) {
          return 'Nickname cannot exceed 50 characters';
        }
        break;
      case 'phone':
        if (value.isNotEmpty &&
            !RegExp(r'^[\+]?[0-9\-\(\)\s]+$').hasMatch(value)) {
          return 'Invalid phone number format';
        }
        break;
      case 'dob':
        // 支援 8 碼 (YYYYMMDD) 或帶 dash (YYYY-MM-DD)。統一抽數字驗證。
        final raw = value.trim();
        final digits = raw.replaceAll(RegExp(r'\D'), '');
        if (digits.isEmpty) {
          // 允許空白生日
          break;
        }
        if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
          return 'Please enter exactly 8 digits as YYYYMMDD';
        }

        final year = int.tryParse(digits.substring(0, 4));
        final month = int.tryParse(digits.substring(4, 6));
        final day = int.tryParse(digits.substring(6, 8));
        if (year == null || month == null || day == null) {
          return 'Invalid numbers in date';
        }

        final now = DateTime.now();
        if (year > now.year) {
          // 年份大於當前年份（幽默訊息）
          return "Are you a time traveler from the future? Please check your year.👀";
        }

        // 轉為 YYYY-MM-DD 並驗證實際日期存在
        final dashed = _compactDobToDashed(digits);
        DateTime? dob;
        try {
          dob = DateTime.parse(dashed);
        } catch (_) {
          return 'Invalid date (please check month/day values)';
        }
        // 防止自動校正，如 2025-02-31 -> 2025-03-03
        if (dob.year != year || dob.month != month || dob.day != day) {
          return 'Invalid date (please check month/day values)';
        }

        // 年齡上限：122 歲又 162 天（幽默訊息）。近似處理：以現在日期往回推 122y + 162d。
        final threshold = DateTime(now.year - 122, now.month, now.day)
            .subtract(const Duration(days: 162));
        if (dob.isBefore(threshold)) {
          return "It looks like you're our most distinguished elder yet!🎉";
        }
        break;
      case 'country':
        if (value.length > 100) {
          return 'Country name cannot exceed 100 characters';
        }
        break;
      case 'address':
        if (value.length > 255) {
          return 'Address cannot exceed 255 characters';
        }
        break;
      case 'aboutMe':
        if (value.length > 1000) {
          return 'About me cannot exceed 1000 characters';
        }
        break;
      case 'school':
        if (value.length > 20) {
          return 'School code cannot exceed 20 characters';
        }
        break;
    }
    return null;
  }

  /// 顯示驗證錯誤
  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 實時驗證欄位
  void _validateFieldRealTime(String fieldKey, String value) {
    final error = _validateField(fieldKey, value);
    setState(() {
      fieldErrors[fieldKey] = error;
    });
  }

  Future<bool> _onWillPop() async {
    if (hasChanges) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Unsaved Changes'),
          content: const Text(
              'You have unsaved changes. Are you sure you want to leave?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  Widget _buildAvatar() {
    return Center(
      child: AvatarUploadWidget(
        currentAvatarUrl: user!.avatar_url,
        userName: user!.name,
        onAvatarChanged: (newAvatarUrl) async {
          // 更新本地用戶資料
          final userService = Provider.of<UserService>(context, listen: false);
          final updatedUser = user!.copyWith(avatar_url: newAvatarUrl);
          userService.setUser(updatedUser);

          // 重新載入用戶資料
          await _loadUserData();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Avatar updated successfully')),
          );
        },
        size: 96, // 48 * 2 = 96 radius
      ),
    );
  }

  @override
  void dispose() {
    for (final controller in controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_userLoaded) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please sign in to view your profile')),
      );
    }
    return PopScope(
      canPop: !hasChanges,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final allow = await _onWillPop();
        if (allow && mounted) Navigator.of(context).maybePop();
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // 頭貼
                _buildAvatar(),
                const SizedBox(height: 24),

                // Name 欄位
                _profileField(
                  label: 'Name',
                  value: controllers['name']!.text,
                  fieldKey: 'name',
                  isEditing: editingField == 'name',
                  editWidget: TextField(
                    controller: controllers['name']!,
                    decoration: InputDecoration(
                      errorText: fieldErrors['name'],
                      counterText: '${controllers['name']!.text.length}/100',
                    ),
                    onChanged: (value) {
                      _checkForChanges();
                      _validateFieldRealTime('name', value);
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'name';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['name']!.text = originalData['name'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField('name', controllers['name']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Nickname
                _profileField(
                  label: 'Nickname',
                  value: controllers['nickname']!.text,
                  fieldKey: 'nickname',
                  isEditing: editingField == 'nickname',
                  editWidget: TextField(
                    controller: controllers['nickname']!,
                    decoration: InputDecoration(
                      errorText: fieldErrors['nickname'],
                      counterText: '${controllers['nickname']!.text.length}/50',
                    ),
                    onChanged: (value) {
                      _checkForChanges();
                      _validateFieldRealTime('nickname', value);
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'nickname';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['nickname']!.text = originalData['nickname'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'nickname', controllers['nickname']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Email (不可編輯)
                _profileField(
                  label: 'Email',
                  value: user!.email,
                  fieldKey: 'email',
                  isEditing: false,
                  editWidget: const SizedBox.shrink(),
                  onEdit: () {},
                  onCancel: () {},
                  onDone: () {},
                  readOnly: true,
                ),

                // Referral Code (不可編輯)
                _profileField(
                  label: 'Referral Code',
                  value: controllers['referralCode']!.text,
                  fieldKey: 'referralCode',
                  isEditing: false,
                  editWidget: const SizedBox.shrink(),
                  onEdit: () {},
                  onCancel: () {},
                  onDone: () {},
                  readOnly: true,
                ),

                // Phone
                _profileField(
                  label: 'Phone',
                  value: controllers['phone']!.text,
                  fieldKey: 'phone',
                  isEditing: editingField == 'phone',
                  editWidget: TextField(
                    controller: controllers['phone']!,
                    decoration: InputDecoration(
                      errorText: fieldErrors['phone'],
                      hintText: '+886912345678 or 0912345678',
                    ),
                    onChanged: (value) {
                      _checkForChanges();
                      _validateFieldRealTime('phone', value);
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'phone';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['phone']!.text = originalData['phone'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'phone', controllers['phone']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Date of Birth
                _profileField(
                  label: 'Birthday',
                  value: _compactDobToDashed(controllers['dateOfBirth']!.text),
                  fieldKey: 'dob',
                  isEditing: editingField == 'dob',
                  editWidget: TextField(
                    controller: controllers['dateOfBirth']!,
                    decoration: InputDecoration(
                      errorText: fieldErrors['dob'],
                      hintText: 'YYYYMMDD (e.g., 19900115)',
                    ),
                    onChanged: (value) {
                      _checkForChanges();
                      _validateFieldRealTime('dob', value);
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'dob';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['dateOfBirth']!.text =
                          originalData['dateOfBirth'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField('dob',
                        _compactDobToDashed(controllers['dateOfBirth']!.text));
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Gender (下拉選單)
                _profileField(
                  label: 'Gender',
                  value: user!.gender ?? 'Not specified',
                  fieldKey: 'gender',
                  isEditing: editingField == 'gender',
                  editWidget: Consumer<ThemeConfigManager>(
                    builder: (context, themeManager, child) {
                      return DropdownButtonFormField<String>(
                        value: (user!.gender != null &&
                                Genders.all.contains(user!.gender))
                            ? user!.gender
                            : 'Prefer not to disclose',
                        isExpanded: true,
                        isDense: true,
                        menuMaxHeight: 420,
                        style: TextStyle(color: themeManager.inputTextColor),
                        decoration: InputDecoration(
                          labelStyle:
                              TextStyle(color: themeManager.inputTextColor),
                          filled: true,
                          fillColor: themeManager.currentTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: Genders.all
                            .map((g) => _scaledMenuItem(
                                  g,
                                  g,
                                  style: TextStyle(
                                      color: themeManager.inputTextColor),
                                ))
                            .toList(),
                        selectedItemBuilder: (context) =>
                            _buildSelectedItemBuilders(
                          Genders.all,
                          style: TextStyle(color: themeManager.inputTextColor),
                        ),
                        onChanged: (value) {
                          setState(() {
                            user = user!.copyWith(gender: value);
                            _checkForChanges();
                          });
                        },
                      );
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'gender';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      user = user!.copyWith(gender: originalData['gender']);
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField('gender', user!.gender);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // School (下拉選單)
                _profileField(
                  label: 'School',
                  value: selectedSchool ?? 'Not specified',
                  fieldKey: 'school',
                  isEditing: editingField == 'school',
                  editWidget: DropdownButtonFormField<String>(
                    value: (selectedSchool != null &&
                            universities.any((u) =>
                                (u['abbr'] as String?) == selectedSchool))
                        ? selectedSchool
                        : null,
                    isExpanded: true,
                    isDense: true,
                    menuMaxHeight: 420,
                    items: universities
                        .map((uni) {
                          final abbr = (uni['abbr'] ?? '') as String;
                          final en = (uni['en_name'] ?? '') as String;
                          if (abbr.isEmpty) return null;
                          final label = en.isNotEmpty ? '$abbr - $en' : abbr;
                          return _scaledMenuItem(abbr, label);
                        })
                        .whereType<DropdownMenuItem<String>>()
                        .toList(),
                    selectedItemBuilder: (context) {
                      final labels = universities
                          .map((uni) {
                            final abbr = (uni['abbr'] ?? '') as String;
                            if (abbr.isEmpty) return null;
                            return abbr;
                          })
                          .whereType<String>()
                          .toList();
                      return _buildSelectedItemBuilders(labels);
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedSchool = value;
                        _checkForChanges();
                      });
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'school';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      selectedSchool = originalData['school'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField('school', selectedSchool);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Primary Language (下拉選單)
                _profileField(
                  label: 'Primary Language',
                  value: selectedPrimaryLanguage != null
                      ? languages.firstWhere(
                            (lang) => lang['name'] == selectedPrimaryLanguage,
                            orElse: () => <String, dynamic>{},
                          )['name'] ??
                          selectedPrimaryLanguage
                      : 'English',
                  fieldKey: 'primaryLanguage',
                  isEditing: editingField == 'primaryLanguage',
                  editWidget: DropdownButtonFormField<String>(
                    value: (selectedPrimaryLanguage != null &&
                            languages.any((lang) =>
                                (lang['name'] as String?) ==
                                selectedPrimaryLanguage))
                        ? selectedPrimaryLanguage
                        : null,
                    isExpanded: true,
                    isDense: true,
                    menuMaxHeight: 420,
                    items: languages
                        .map((lang) {
                          final name = (lang['name'] ?? '') as String;
                          if (name.isEmpty) return null;
                          return _scaledMenuItem(name, name);
                        })
                        .whereType<DropdownMenuItem<String>>()
                        .toList(),
                    selectedItemBuilder: (context) {
                      final labels = languages
                          .map((lang) {
                            final name = (lang['name'] ?? '') as String;
                            if (name.isEmpty) return null;
                            return name;
                          })
                          .whereType<String>()
                          .toList();
                      return _buildSelectedItemBuilders(labels);
                    },
                    onChanged: (value) {
                      setState(() {
                        selectedPrimaryLanguage = value;
                        _checkForChanges();
                      });
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'primaryLanguage';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      selectedPrimaryLanguage = originalData['primaryLanguage'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'primaryLanguage', selectedPrimaryLanguage);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Language Requirements (多選下拉選單) // 不是需求範圍，先不做
                // _profileField(
                //   label: 'Language Requirements',
                //   value: selectedLanguageRequirements.isNotEmpty
                //       ? selectedLanguageRequirements.join(', ')
                //       : 'Not specified',
                //   fieldKey: 'languageRequirements',
                //   isEditing: editingField == 'languageRequirements',
                //   editWidget: Column(
                //     children: [
                //       // 已選擇的語言標籤
                //       if (selectedLanguageRequirements.isNotEmpty)
                //         Wrap(
                //           spacing: 8,
                //           runSpacing: 4,
                //           children:
                //               selectedLanguageRequirements.map((langCode) {
                //             final lang = languages.firstWhere(
                //               (lang) => lang['code'] == langCode,
                //               orElse: () => <String, dynamic>{},
                //             );
                //             return Chip(
                //               label: Text(lang['native'] ?? langCode),
                //               onDeleted: () {
                //                 setState(() {
                //                   selectedLanguageRequirements.remove(langCode);
                //                   _checkForChanges();
                //                 });
                //               },
                //               backgroundColor: Theme.of(context).primaryColor,
                //               labelStyle: const TextStyle(color: Colors.white),
                //               deleteIconColor: Colors.white,
                //             );
                //           }).toList(),
                //         ),
                //       const SizedBox(height: 8),
                //       // 添加語言按鈕
                //       if (selectedLanguageRequirements.length < 5)
                //         ElevatedButton.icon(
                //           onPressed: _showLanguageSelector,
                //           icon: const Icon(Icons.add),
                //           label: const Text('Add Language'),
                //           style: ElevatedButton.styleFrom(
                //             backgroundColor: Theme.of(context).primaryColor,
                //             foregroundColor: Colors.white,
                //           ),
                //         ),
                //     ],
                //   ),
                //   onEdit: () {
                //     setState(() {
                //       editingField = 'languageRequirements';
                //     });
                //   },
                //   onCancel: () {
                //     setState(() {
                //       editingField = null;
                //       selectedLanguageRequirements =
                //           List.from(originalData['languageRequirements']);
                //       _checkForChanges();
                //     });
                //   },
                //   onDone: () {
                //     setState(() {
                //       editingField = null;
                //       _checkForChanges();
                //     });
                //   },
                // ),

                // Country
                _profileField(
                  label: 'Country',
                  value: controllers['country']!.text,
                  fieldKey: 'country',
                  isEditing: editingField == 'country',
                  editWidget: DropdownButtonFormField<String>(
                    value:
                        Countries.all.contains(controllers['country']!.text) &&
                                controllers['country']!.text.isNotEmpty
                            ? controllers['country']!.text
                            : null,
                    isExpanded: true,
                    isDense: true,
                    menuMaxHeight: 420,
                    items: Countries.all
                        .map((country) => _scaledMenuItem(country, country))
                        .toList(),
                    selectedItemBuilder: (context) =>
                        _buildSelectedItemBuilders(Countries.all),
                    onChanged: (value) {
                      setState(() {
                        controllers['country']!.text = value ?? '';
                        _checkForChanges();
                      });
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'country';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['country']!.text = originalData['country'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'country', controllers['country']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // Address with Permanent Address checkbox
                _profileField(
                  label: 'Address',
                  value: controllers['address']!.text,
                  fieldKey: 'address',
                  isEditing: editingField == 'address',
                  editWidget: Column(
                    children: [
                      TextField(
                        controller: controllers['address']!,
                        maxLines: 3,
                        decoration: InputDecoration(
                          errorText: fieldErrors['address'],
                          counterText:
                              '${controllers['address']!.text.length}/255',
                        ),
                        onChanged: (value) {
                          _checkForChanges();
                          _validateFieldRealTime('address', value);
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Checkbox(
                            value: isPermanentAddress,
                            onChanged: (value) {
                              setState(() {
                                isPermanentAddress = value ?? false;
                                _checkForChanges();
                              });
                            },
                          ),
                          const Text('Permanent Address'),
                        ],
                      ),
                    ],
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'address';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['address']!.text = originalData['address'];
                      isPermanentAddress = originalData['isPermanentAddress'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'address', controllers['address']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                // About Me
                _profileField(
                  label: 'About Me',
                  value: controllers['aboutMe']!.text,
                  fieldKey: 'aboutMe',
                  isEditing: editingField == 'aboutMe',
                  editWidget: TextField(
                    controller: controllers['aboutMe']!,
                    maxLines: 3,
                    decoration: InputDecoration(
                      errorText: fieldErrors['aboutMe'],
                      counterText:
                          '${controllers['aboutMe']!.text.length}/1000',
                      hintText: 'Tell us about yourself...',
                    ),
                    onChanged: (value) {
                      _checkForChanges();
                      _validateFieldRealTime('aboutMe', value);
                    },
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'aboutMe';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      controllers['aboutMe']!.text = originalData['aboutMe'];
                      _checkForChanges();
                    });
                  },
                  onDone: () async {
                    await _updateSingleField(
                        'aboutMe', controllers['aboutMe']!.text);
                    setState(() {
                      editingField = null;
                    });
                  },
                ),

                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // void _showLanguageSelector() {
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return StatefulBuilder(
  //         builder: (context, setDialogState) {
  //           return AlertDialog(
  //             title: const Text('Select Languages'),
  //             content: SizedBox(
  //               width: double.maxFinite,
  //               height: 400,
  //               child: Column(
  //                 children: [
  //                   // 搜尋框
  //                   TextField(
  //                     decoration: const InputDecoration(
  //                       prefixIcon: Icon(Icons.search),
  //                       border: OutlineInputBorder(),
  //                     ),
  //                     onChanged: (value) {
  //                       setDialogState(() {});
  //                     },
  //                   ),
  //                   const SizedBox(height: 16),
  //                   // 語言列表
  //                   Expanded(
  //                     child: ListView.builder(
  //                       itemCount: languages.length,
  //                       itemBuilder: (context, index) {
  //                         final lang = languages[index];
  //                         final isSelected = selectedLanguageRequirements
  //                             .contains(lang['code']);

  //                         return CheckboxListTile(
  //                           title: Text(lang['native'] ?? ''),
  //                           subtitle: Text(lang['name'] ?? ''),
  //                           value: isSelected,
  //                           onChanged: (bool? value) {
  //                             setDialogState(() {
  //                               if (value == true &&
  //                                   selectedLanguageRequirements.length < 5) {
  //                                 selectedLanguageRequirements
  //                                     .add(lang['code']!);
  //                               } else if (value == false) {
  //                                 selectedLanguageRequirements
  //                                     .remove(lang['code']!);
  //                               }
  //                             });
  //                           },
  //                         );
  //                       },
  //                     ),
  //                   ),
  //                 ],
  //               ),
  //             ),
  //             actions: [
  //               TextButton(
  //                 onPressed: () => Navigator.of(context).pop(),
  //                 child: const Text('Cancel'),
  //               ),
  //               TextButton(
  //                 onPressed: () {
  //                   setState(() {
  //                     _checkForChanges();
  //                   });
  //                   Navigator.of(context).pop();
  //                 },
  //                 child: const Text('OK'),
  //               ),
  //             ],
  //           );
  //         },
  //       );
  //     },
  //   );
  // }

  Widget _profileField({
    required String label,
    required String value,
    required String fieldKey,
    required bool isEditing,
    required Widget editWidget,
    required VoidCallback onEdit,
    required VoidCallback onCancel,
    required VoidCallback onDone,
    bool readOnly = false,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 60),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (!readOnly)
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  onPressed: onEdit,
                ),
            ],
          ),
          if (!isEditing)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Container(
                width: double.infinity,
                constraints: const BoxConstraints(minHeight: 20),
                child: Text(
                  value.isEmpty ? 'Not specified' : value,
                  style: TextStyle(
                    color: value.isEmpty ? Colors.grey : null,
                  ),
                ),
              ),
            ),
          if (isEditing)
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    constraints: const BoxConstraints(
                        maxHeight: 200, maxWidth: double.infinity),
                    child: editWidget,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: onCancel,
                        child: const Text('Cancel',
                            style: TextStyle(color: Colors.red)),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed:
                            fieldErrors[fieldKey] == null ? onDone : null,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          const Divider(),
        ],
      ),
    );
  }
}
