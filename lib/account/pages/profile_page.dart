import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/models/user_model.dart';
import 'package:here4help/task/services/university_service.dart';
import 'package:here4help/task/services/language_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/theme_config_manager.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

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
  late UserModel user;

  // 編輯暫存
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController aboutMeController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();

  // 性別選項（與註冊頁面一致）
  final List<String> genderOptions = [
    'Male',
    'Female',
    'Yellow_white_purple',
    'Genderfluid',
    'Agender',
    'Bigender',
    'Genderqueer',
    'Two-spirit',
    'Prefer not to say',
    'Other'
  ];

  // 大學列表
  List<Map<String, dynamic>> universities = [];
  String? selectedSchool;

  // 語言列表
  List<Map<String, dynamic>> languages = [];
  String? selectedPrimaryLanguage;
  List<String> selectedLanguageRequirements = [];

  // 其他選項
  bool isPermanentAddress = false;

  // 頭貼相關
  File? selectedImageFile;
  final ImagePicker _picker = ImagePicker();

  // 原始資料（用於比較是否有變更）
  Map<String, dynamic> originalData = {};

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadUniversities();
    _loadLanguages();
  }

  Future<void> _loadUserData() async {
    final userService = Provider.of<UserService>(context, listen: false);
    user = userService.currentUser!;

    // 初始化控制器
    final nameParts = user.name.split(' ');
    firstNameController.text = nameParts.isNotEmpty ? nameParts.first : '';
    lastNameController.text =
        nameParts.length > 1 ? nameParts.sublist(1).join(' ') : '';
    phoneController.text = user.phone ?? '';
    dateOfBirthController.text = user.date_of_birth ?? '';
    countryController.text = user.country ?? '';
    addressController.text = user.address ?? '';
    aboutMeController.text = user.about_me ?? '';
    nicknameController.text = user.nickname ?? '';
    referralCodeController.text = user.referral_code ?? '';
    selectedSchool = user.school;

    // 確保語言數據已載入後再設置
    selectedPrimaryLanguage = user.primary_language;

    isPermanentAddress = user.is_permanent_address ?? false;

    // 載入語言需求
    if (user.language_requirement != null) {
      selectedLanguageRequirements = user.language_requirement!.split(',');
    }

    // 儲存原始資料
    originalData = {
      'firstName': firstNameController.text,
      'lastName': lastNameController.text,
      'phone': phoneController.text,
      'dateOfBirth': dateOfBirthController.text,
      'gender': user.gender,
      'country': countryController.text,
      'address': addressController.text,
      'aboutMe': aboutMeController.text,
      'school': selectedSchool,
      'nickname': nicknameController.text,
      'referralCode': referralCodeController.text,
      'primaryLanguage': selectedPrimaryLanguage,
      'languageRequirements': selectedLanguageRequirements,
      'isPermanentAddress': isPermanentAddress,
    };
  }

  Future<void> _loadUniversities() async {
    try {
      final unis = await UniversityService.getUniversities();
      setState(() {
        universities = unis;
      });
    } catch (e) {
      // 如果無法載入大學列表，使用預設列表
      setState(() {
        universities = [
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
      final langs = await LanguageService.getLanguages();
      setState(() {
        languages = langs;
      });
    } catch (e) {
      // 如果無法載入語言列表，使用預設列表
      setState(() {
        languages = [
          {'code': 'en', 'name': 'English', 'native': 'English'},
          {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
          {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
          {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
        ];
      });
    }
  }

  void _checkForChanges() {
    final currentData = {
      'firstName': firstNameController.text,
      'lastName': lastNameController.text,
      'phone': phoneController.text,
      'dateOfBirth': dateOfBirthController.text,
      'gender': user.gender,
      'country': countryController.text,
      'address': addressController.text,
      'aboutMe': aboutMeController.text,
      'school': selectedSchool,
      'nickname': nicknameController.text,
      'referralCode': referralCodeController.text,
      'primaryLanguage': selectedPrimaryLanguage,
      'languageRequirements': selectedLanguageRequirements,
      'isPermanentAddress': isPermanentAddress,
    };

    setState(() {
      hasChanges = !mapEquals(originalData, currentData);
    });
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        selectedImageFile = File(image.path);
        hasChanges = true;
      });
    }
  }

  Future<void> _removeAvatar() async {
    setState(() {
      selectedImageFile = null;
      hasChanges = true;
    });
  }

  Future<void> _saveProfile() async {
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes to save')),
      );
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
            '${AppConfig.apiBaseUrl}/backend/api/auth/update-profile.php'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'user_id': user.id,
          'name':
              '${firstNameController.text} ${lastNameController.text}'.trim(),
          'nickname': nicknameController.text,
          'phone': phoneController.text,
          'date_of_birth': dateOfBirthController.text,
          'gender': user.gender,
          'country': countryController.text,
          'address': addressController.text,
          'primary_language': selectedPrimaryLanguage,
          'language_requirement': selectedLanguageRequirements.join(','),
          'school': selectedSchool,
          'is_permanent_address': isPermanentAddress,
        }),
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        // 更新本地用戶資料
        final userService = Provider.of<UserService>(context, listen: false);
        userService.setUser(UserModel.fromJson(data['data']));

        // 更新原始資料
        originalData = {
          'firstName': firstNameController.text,
          'lastName': lastNameController.text,
          'phone': phoneController.text,
          'dateOfBirth': dateOfBirthController.text,
          'gender': user.gender,
          'country': countryController.text,
          'address': addressController.text,
          'aboutMe': aboutMeController.text,
          'school': selectedSchool,
          'nickname': nicknameController.text,
          'referralCode': referralCodeController.text,
          'primaryLanguage': selectedPrimaryLanguage,
          'languageRequirements': selectedLanguageRequirements,
          'isPermanentAddress': isPermanentAddress,
        };

        setState(() {
          hasChanges = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully')),
        );
      } else {
        throw Exception(data['message'] ?? 'Failed to update profile');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating profile: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
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
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 頭貼顯示
          CircleAvatar(
            radius: 48,
            backgroundColor: Theme.of(context).primaryColor,
            backgroundImage: selectedImageFile != null
                ? FileImage(selectedImageFile!)
                : (user.avatar_url.isNotEmpty
                    ? NetworkImage(user.avatar_url) as ImageProvider
                    : null),
            child: selectedImageFile == null && user.avatar_url.isEmpty
                ? Text(
                    user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  )
                : null,
          ),
          // 編輯按鈕
          Positioned(
            bottom: 0,
            right: 0,
            child: PopupMenuButton<String>(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              onSelected: (value) {
                if (value == 'upload') {
                  _pickImage();
                } else if (value == 'remove') {
                  _removeAvatar();
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'upload',
                  child: Row(
                    children: [
                      Icon(Icons.upload),
                      SizedBox(width: 8),
                      Text('Upload Photo'),
                    ],
                  ),
                ),
                if (selectedImageFile != null || user.avatar_url.isNotEmpty)
                  const PopupMenuItem(
                    value: 'remove',
                    child: Row(
                      children: [
                        Icon(Icons.delete),
                        SizedBox(width: 8),
                        Text('Remove Photo'),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    dateOfBirthController.dispose();
    countryController.dispose();
    addressController.dispose();
    aboutMeController.dispose();
    nicknameController.dispose();
    referralCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
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

                // Nickname
                _profileField(
                  label: 'Nickname',
                  value: nicknameController.text,
                  fieldKey: 'nickname',
                  isEditing: editingField == 'nickname',
                  editWidget: TextField(
                    controller: nicknameController,
                    decoration: const InputDecoration(labelText: 'Nickname'),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'nickname';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      nicknameController.text = originalData['nickname'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Name 欄位
                _profileField(
                  label: 'Name',
                  value:
                      '${firstNameController.text} ${lastNameController.text}'
                          .trim(),
                  fieldKey: 'name',
                  isEditing: editingField == 'name',
                  editWidget: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: firstNameController,
                          decoration:
                              const InputDecoration(labelText: 'First Name'),
                          onChanged: (_) => _checkForChanges(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: lastNameController,
                          decoration:
                              const InputDecoration(labelText: 'Last Name'),
                          onChanged: (_) => _checkForChanges(),
                        ),
                      ),
                    ],
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'name';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      firstNameController.text = originalData['firstName'];
                      lastNameController.text = originalData['lastName'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Email (不可編輯)
                _profileField(
                  label: 'Email',
                  value: user.email,
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
                  value: referralCodeController.text,
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
                  value: phoneController.text,
                  fieldKey: 'phone',
                  isEditing: editingField == 'phone',
                  editWidget: TextField(
                    controller: phoneController,
                    decoration: const InputDecoration(labelText: 'Phone'),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'phone';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      phoneController.text = originalData['phone'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Date of Birth
                _profileField(
                  label: 'Date of Birth',
                  value: dateOfBirthController.text,
                  fieldKey: 'dob',
                  isEditing: editingField == 'dob',
                  editWidget: TextField(
                    controller: dateOfBirthController,
                    decoration: const InputDecoration(
                        labelText: 'Date of Birth (YYYY-MM-DD)'),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'dob';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      dateOfBirthController.text = originalData['dateOfBirth'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Gender (下拉選單)
                _profileField(
                  label: 'Gender',
                  value: user.gender ?? 'Not specified',
                  fieldKey: 'gender',
                  isEditing: editingField == 'gender',
                  editWidget: Consumer<ThemeConfigManager>(
                    builder: (context, themeManager, child) {
                      return DropdownButtonFormField<String>(
                        value: user.gender,
                        style: TextStyle(color: themeManager.inputTextColor),
                        decoration: InputDecoration(
                          labelText: 'Gender',
                          labelStyle:
                              TextStyle(color: themeManager.inputTextColor),
                          filled: true,
                          fillColor: themeManager.currentTheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        items: genderOptions.map((gender) {
                          return DropdownMenuItem(
                            value: gender,
                            child: Text(gender,
                                style: TextStyle(
                                    color: themeManager.inputTextColor)),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            user = user.copyWith(gender: value);
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
                      user = user.copyWith(gender: originalData['gender']);
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
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
                    value: selectedSchool,
                    decoration: const InputDecoration(labelText: 'School'),
                    items: universities.map((uni) {
                      return DropdownMenuItem<String>(
                        value: uni['abbr'] as String,
                        child: Text('${uni['abbr']} - ${uni['zh_name']}'),
                      );
                    }).toList(),
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
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Primary Language (下拉選單)
                _profileField(
                  label: 'Primary Language',
                  value: selectedPrimaryLanguage != null
                      ? languages.firstWhere(
                            (lang) => lang['code'] == selectedPrimaryLanguage,
                            orElse: () => <String, dynamic>{},
                          )['native'] ??
                          selectedPrimaryLanguage
                      : 'Not specified',
                  fieldKey: 'primaryLanguage',
                  isEditing: editingField == 'primaryLanguage',
                  editWidget: DropdownButtonFormField<String>(
                    value: languages.any(
                            (lang) => lang['code'] == selectedPrimaryLanguage)
                        ? selectedPrimaryLanguage
                        : null,
                    decoration:
                        const InputDecoration(labelText: 'Primary Language'),
                    items: languages.map((lang) {
                      return DropdownMenuItem<String>(
                        value: lang['code'] as String,
                        child: Text('${lang['native']} (${lang['name']})'),
                      );
                    }).toList(),
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
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Language Requirements (多選下拉選單)
                _profileField(
                  label: 'Language Requirements',
                  value: selectedLanguageRequirements.isNotEmpty
                      ? selectedLanguageRequirements.join(', ')
                      : 'Not specified',
                  fieldKey: 'languageRequirements',
                  isEditing: editingField == 'languageRequirements',
                  editWidget: Column(
                    children: [
                      // 已選擇的語言標籤
                      if (selectedLanguageRequirements.isNotEmpty)
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children:
                              selectedLanguageRequirements.map((langCode) {
                            final lang = languages.firstWhere(
                              (lang) => lang['code'] == langCode,
                              orElse: () => <String, dynamic>{},
                            );
                            return Chip(
                              label: Text(lang['native'] ?? langCode),
                              onDeleted: () {
                                setState(() {
                                  selectedLanguageRequirements.remove(langCode);
                                  _checkForChanges();
                                });
                              },
                              backgroundColor: Theme.of(context).primaryColor,
                              labelStyle: const TextStyle(color: Colors.white),
                              deleteIconColor: Colors.white,
                            );
                          }).toList(),
                        ),
                      const SizedBox(height: 8),
                      // 添加語言按鈕
                      if (selectedLanguageRequirements.length < 5)
                        ElevatedButton.icon(
                          onPressed: _showLanguageSelector,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Language'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).primaryColor,
                            foregroundColor: Colors.white,
                          ),
                        ),
                    ],
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'languageRequirements';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      selectedLanguageRequirements =
                          List.from(originalData['languageRequirements']);
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Country
                _profileField(
                  label: 'Country',
                  value: countryController.text,
                  fieldKey: 'country',
                  isEditing: editingField == 'country',
                  editWidget: TextField(
                    controller: countryController,
                    decoration: const InputDecoration(labelText: 'Country'),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'country';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      countryController.text = originalData['country'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Address with Permanent Address checkbox
                _profileField(
                  label: 'Address',
                  value: addressController.text,
                  fieldKey: 'address',
                  isEditing: editingField == 'address',
                  editWidget: Column(
                    children: [
                      TextField(
                        controller: addressController,
                        maxLines: 3,
                        decoration: const InputDecoration(labelText: 'Address'),
                        onChanged: (_) => _checkForChanges(),
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
                      addressController.text = originalData['address'];
                      isPermanentAddress = originalData['isPermanentAddress'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // About Me
                _profileField(
                  label: 'About Me',
                  value: aboutMeController.text,
                  fieldKey: 'aboutMe',
                  isEditing: editingField == 'aboutMe',
                  editWidget: TextField(
                    controller: aboutMeController,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'About Me'),
                    onChanged: (_) => _checkForChanges(),
                  ),
                  onEdit: () {
                    setState(() {
                      editingField = 'aboutMe';
                    });
                  },
                  onCancel: () {
                    setState(() {
                      editingField = null;
                      aboutMeController.text = originalData['aboutMe'];
                      _checkForChanges();
                    });
                  },
                  onDone: () {
                    setState(() {
                      editingField = null;
                      _checkForChanges();
                    });
                  },
                ),

                // Save 按鈕
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: hasChanges
                          ? Theme.of(context).primaryColor
                          : Colors.grey,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: hasChanges && !isLoading ? _saveProfile : null,
                    child: isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'Save Changes',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Select Languages'),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // 搜尋框
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Search languages',
                        prefixIcon: Icon(Icons.search),
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    // 語言列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: languages.length,
                        itemBuilder: (context, index) {
                          final lang = languages[index];
                          final isSelected = selectedLanguageRequirements
                              .contains(lang['code']);

                          return CheckboxListTile(
                            title: Text(lang['native'] ?? ''),
                            subtitle: Text(lang['name'] ?? ''),
                            value: isSelected,
                            onChanged: (bool? value) {
                              setDialogState(() {
                                if (value == true &&
                                    selectedLanguageRequirements.length < 5) {
                                  selectedLanguageRequirements
                                      .add(lang['code']!);
                                } else if (value == false) {
                                  selectedLanguageRequirements
                                      .remove(lang['code']!);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _checkForChanges();
                    });
                    Navigator.of(context).pop();
                  },
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

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
    return Column(
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
            child: Text(value),
          ),
        if (isEditing)
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                editWidget,
                Row(
                  children: [
                    TextButton(
                      onPressed: onCancel,
                      child: const Text('Cancel',
                          style: TextStyle(color: Colors.red)),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: onDone,
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        const Divider(),
      ],
    );
  }
}
