// signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/task/services/language_service.dart';
import 'package:pinput/pinput.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:here4help/config/app_config.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with WidgetsBindingObserver {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController nicknameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController countryController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController =
      TextEditingController();
  final TextEditingController dateOfBirthController = TextEditingController();
  final TextEditingController paymentPasswordController =
      TextEditingController();
  final TextEditingController confirmPaymentPasswordController =
      TextEditingController();
  final TextEditingController schoolController = TextEditingController();
  final TextEditingController referralCodeController = TextEditingController();

  final genderParams = {
    'Male': 'Male',
    'Female': 'Female',
    'Non-binary': 'Non-binary',
    'Genderfluid': 'Genderfluid',
    'Agender': 'Agender',
    'Bigender': 'Bigender',
    'Genderqueer': 'Genderqueer',
    'Two-spirit': 'Two-spirit',
    'Other': 'Other',
    'Prefer not to disclose': 'Prefer not to disclose',
  };
  // 性別選項
  late final List<String> genderOptions = genderParams.keys.toList();

  // 以下為表單狀態
  late String selectedGender;
  bool isPermanentAddress = false;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    selectedGender =
        genderParams['Prefer not to disclose'] ?? 'Prefer not to disclose';
    WidgetsBinding.instance.addObserver(this);
    _loadExistingData();
    _loadPrefilledData();
    _loadLanguages();
    _loadUniversities();
    _loadThirdPartyData(); // 新增：載入第三方登入資料
  }

  bool showPaymentPassword = false;
  bool showConfirmPaymentPassword = false;
  bool isVerifyingReferralCode = false;
  String? referralCodeStatus; // 'valid', 'invalid', 'not_found'

  // 語言選項
  List<Map<String, dynamic>> languageOptions = [];
  List<String> selectedLanguages = ['en'];

  // 大學選項
  List<Map<String, dynamic>> universityOptions = [];
  String? selectedUniversityId;



  // 新增：載入第三方登入資料
  Future<void> _loadThirdPartyData() async {
    final prefs = await SharedPreferences.getInstance();
    final provider = prefs.getString('signup_provider');

    if (provider != null && provider.isNotEmpty) {
      setState(() {
        // 預填第三方登入提供的資料
        fullNameController.text = prefs.getString('signup_full_name') ?? '';
        nicknameController.text = prefs.getString('signup_nickname') ?? '';
        emailController.text = prefs.getString('signup_email') ?? '';

        // 如果有頭像 URL，可以顯示
        final avatarUrl = prefs.getString('signup_avatar_url');
        if (avatarUrl != null && avatarUrl.isNotEmpty) {
          // 這裡可以設定頭像顯示
        }
      });

      // 清除第三方登入暫存資料
      await prefs.remove('signup_provider');
      await prefs.remove('signup_provider_user_id');
      await prefs.remove('signup_avatar_url');
    }
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await LanguageService.getLanguages();
      setState(() {
        languageOptions = langs;
      });
    } catch (e) {
      // 如果無法載入語言列表，使用預設列表
      setState(() {
        languageOptions = [
          {'code': 'en', 'name': 'English', 'native': 'English'},
          {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
          {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
          {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
        ];
      });
    }
  }

  // 新增：載入大學列表
  Future<void> _loadUniversities() async {
    try {
      final response = await http.get(
        Uri.parse(AppConfig.universitiesListUrl),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] && data['data'] != null) {
          final universities = List<Map<String, dynamic>>.from(data['data']);
          // 過濾掉無效的大學資料
          final validUniversities = universities
              .where((university) =>
                  university['id'] != null &&
                  university['abbr'] != null &&
                  university['en_name'] != null)
              .toList();

          setState(() {
            universityOptions = validUniversities;
          });

          if (validUniversities.isEmpty) {
            print('警告：沒有找到有效的大學資料');
          }
        } else {
          print('載入大學列表失敗：API 回應格式錯誤');
        }
      } else {
        print('載入大學列表失敗：HTTP ${response.statusCode}');
      }
    } catch (e) {
      print('載入大學列表失敗: $e');
      // 設置預設的大學選項作為 fallback
      setState(() {
        universityOptions = [];
      });
    }
  }

  // 新增：驗證推薦碼
  Future<void> _verifyReferralCode() async {
    final referralCode = referralCodeController.text.trim();
    if (referralCode.isEmpty) {
      setState(() {
        referralCodeStatus = 'invalid';
      });
      return;
    }

    setState(() {
      isVerifyingReferralCode = true;
      referralCodeStatus = null;
    });

    try {
      final response = await http.post(
        Uri.parse(AppConfig.verifyReferralCodeUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'referral_code': referralCode}),
      );

      final data = jsonDecode(response.body);

      setState(() {
        if (data['success']) {
          referralCodeStatus = 'valid';
        } else {
          referralCodeStatus = 'invalid';
        }
      });
    } catch (e) {
      setState(() {
        referralCodeStatus = 'not_found';
      });
    } finally {
      setState(() {
        isVerifyingReferralCode = false;
      });
    }
  }

  // 新增：獲取推薦碼狀態的顏色
  Color _getReferralCodeStatusColor() {
    switch (referralCodeStatus) {
      case 'valid':
        return Theme.of(context).colorScheme.secondary; // 通過時用系統色
      case 'invalid':
      case 'not_found':
        return Theme.of(context).colorScheme.error; // 錯誤用系統錯誤色
      default:
        return Theme.of(context).disabledColor; // 其他用系統預設 disabled 色
    }
  }

  // 新增：獲取推薦碼狀態的文字
  String _getReferralCodeStatusText() {
    switch (referralCodeStatus) {
      case 'valid':
        return 'Referral code is valid';
      case 'invalid':
        return 'Referral code is invalid or does not exist';
      case 'not_found':
        return 'Referral code is invalid or does not exist';
      default:
        return 'Referral code is invalid or does not exist';
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _showLeaveWarning();
    }
  }

  Future<void> _loadExistingData() async {
    final prefs = await SharedPreferences.getInstance();

    // 載入已存在的資料
    setState(() {
      fullNameController.text = prefs.getString('signup_full_name') ?? '';
      nicknameController.text = prefs.getString('signup_nickname') ?? '';
      selectedGender =
          prefs.getString('signup_gender') ?? 'Prefer not to disclose';
      emailController.text = prefs.getString('signup_email') ?? '';
      phoneController.text = prefs.getString('signup_phone') ?? '';
      countryController.text = prefs.getString('signup_country') ?? '';
      addressController.text = prefs.getString('signup_address') ?? '';
      passwordController.text = prefs.getString('signup_password') ?? '';
      confirmPasswordController.text = prefs.getString('signup_password') ?? '';
      dateOfBirthController.text =
          prefs.getString('signup_date_of_birth') ?? '';
      paymentPasswordController.text =
          prefs.getString('signup_payment_code') ?? '';
      confirmPaymentPasswordController.text =
          prefs.getString('signup_payment_code') ?? '';
      isPermanentAddress =
          prefs.getBool('signup_is_permanent_address') ?? false;

      // 載入語言選擇
      final savedLanguages = prefs.getStringList('signup_languages') ?? ['en'];
      selectedLanguages = savedLanguages;
    });
  }

  void _loadPrefilledData() {
    // 預填測試資料
    setState(() {
      fullNameController.text = 'John Doe';
      nicknameController.text = 'Johnny';
      emailController.text = 'john.doe@example.com';
      phoneController.text = '+886912345678';
      countryController.text = 'Taiwan';
      addressController.text = '123 Main Street, Taipei';
      passwordController.text = 'password123';
      confirmPasswordController.text = 'password123';
      dateOfBirthController.text = '1995/01/15';
      paymentPasswordController.text = '123456';
      confirmPaymentPasswordController.text = '123456';
      selectedLanguages = ['en', 'zh'];
    });
  }

  void _showLeaveWarning() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Warning'),
          content: const Text(
              'Your data will not be saved if you leave this page. Are you sure you want to continue?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/login');
              },
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Full Name
            TextFormField(
              controller: fullNameController,
              decoration: const InputDecoration(
                labelText: 'Your Name',
                border: OutlineInputBorder(),
                helperText:
                    'Enter your complete name as it appears on your official documents',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your full name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Nickname
            TextFormField(
              controller: nicknameController,
              decoration: const InputDecoration(
                labelText: 'Nickname (preferred name)',
                border: OutlineInputBorder(),
                helperText: 'Enter the name you prefer to be called (optional)',
              ),
              validator: (value) {
                // Nickname is optional
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Gender Selection
            const Text('Gender',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedGender,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
              items: genderOptions.map((String gender) {
                return DropdownMenuItem<String>(
                  value: gender,
                  child: Text(gender),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedGender = newValue!;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your gender';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email
            TextFormField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                    .hasMatch(value)) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Phone Number
            TextFormField(
              controller: phoneController,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                border: OutlineInputBorder(),
                helperText: 'Taiwan format: 09xxxxxxxx or +8869xxxxxxxx',
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                if (!RegExp(r'^(09\d{8}|\+8869\d{8})$').hasMatch(value)) {
                  return 'Invalid Taiwan mobile format';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date of Birth (moved here, renamed to Birthday)
            TextFormField(
              controller: dateOfBirthController,
              decoration: const InputDecoration(
                labelText: 'Birthday',
                hintText: 'YYYY/MM/DD',
                border: OutlineInputBorder(),
              ),
              readOnly: true,
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now()
                      .subtract(const Duration(days: 6570)), // 18 years ago
                  firstDate: DateTime.now()
                      .subtract(const Duration(days: 36500)), // 100 years ago
                  lastDate: DateTime.now(),
                );
                if (date != null) {
                  setState(() {
                    dateOfBirthController.text =
                        '${date.year}/${date.month.toString().padLeft(2, '0')}/${date.day.toString().padLeft(2, '0')}';
                  });
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your date of birth';
                }
                return null;
              },
            ),
            const SizedBox(height: 32),

            // Address (moved here)
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: addressController,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your address';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 8),
                // Permanent Address Checkbox
                Column(
                  children: [
                    const Text('Permanent Address?',
                        style: TextStyle(fontSize: 8)),
                    Checkbox(
                      value: isPermanentAddress,
                      onChanged: (value) {
                        setState(() {
                          isPermanentAddress = value!;
                        });
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // School Selection - 新增
            // const Text('School',
            //     style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: selectedUniversityId,
              decoration: InputDecoration(
                labelText: 'School *',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12.0, vertical: 12.0),
              ),
              hint: Text(
                'Select your school',
                style: TextStyle(
                  color:
                      Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                  fontSize: 16.0,
                ),
              ),
              isExpanded: true,
              menuMaxHeight: 300.0,
              dropdownColor: Theme.of(context).colorScheme.surface,
              icon: Icon(
                Icons.arrow_drop_down,
                color: Theme.of(context).colorScheme.primary,
              ),
              style: TextStyle(
                fontSize: 13.0,
                color: Theme.of(context).colorScheme.onSurface,
              ),
              selectedItemBuilder: (context) {
                final widgets = <Widget>[
                  ...universityOptions
                      .where((u) =>
                          u['id'] != null &&
                          u['abbr'] != null &&
                          u['en_name'] != null)
                      .map((u) {
                    final abbr = u['abbr'] ?? '';
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        abbr,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 12.0,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    );
                  }).toList(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Text(
                      'Other School',
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                ];
                return widgets;
              },
              items: [
                // 大學選項（無 placeholder 項，改由 hint 顯示）
                ...universityOptions
                    .where((university) =>
                        university['id'] != null &&
                        university['abbr'] != null &&
                        university['en_name'] != null)
                    .map((university) {
                  final displayName = university['abbr'] ?? '';
                  final enName = university['en_name'] ?? '';
                  return DropdownMenuItem<String>(
                    value: university['id'].toString(),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          vertical: 6.0, horizontal: 12.0),
                      margin: const EdgeInsets.only(bottom: 3.0),
                      decoration: BoxDecoration(
                        border: Border(
                          left: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Text(
                            displayName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14.0,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Text(
                            '/',
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 8.0),
                          Expanded(
                            child: Text(
                              enName,
                              style: TextStyle(
                                fontSize: 12.0,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withOpacity(0.6),
                                fontStyle: FontStyle.italic,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
                // Other School 選項
                DropdownMenuItem<String>(
                  value: 'other',
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        vertical: 8.0, horizontal: 12.0),
                    margin: const EdgeInsets.only(bottom: 5.0),
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                          width: 2.0,
                        ),
                      ),
                    ),
                    child: Text(
                      'Other School',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  selectedUniversityId = value;
                  if (value != 'other') {
                    schoolController.clear();
                  }
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please select your school';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // 如果選擇 Other School，顯示輸入欄位
            if (selectedUniversityId == 'other') ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: schoolController,
                decoration: InputDecoration(
                  labelText: 'School Name *',
                  hintText: 'Enter your school name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16.0, vertical: 12.0),
                  prefixIcon: Icon(
                    Icons.school,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                style: TextStyle(
                  fontSize: 16.0,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter your school name';
                  }
                  return null;
                },
              ),
            ],

            // Referral Code - 新增
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: TextFormField(
                    controller: referralCodeController,
                    decoration: InputDecoration(
                      labelText: 'Referral Code',
                      hintText: 'Enter referral code (optional)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      prefixIcon: Icon(
                        Icons.card_giftcard,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      suffixIcon: referralCodeStatus != null
                          ? Icon(
                              referralCodeStatus == 'valid'
                                  ? Icons.check_circle
                                  : Icons.error,
                              color: _getReferralCodeStatusColor(),
                            )
                          : null,
                    ),
                    style: TextStyle(
                      fontSize: 16.0,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    onChanged: (value) {
                      final upper = value.toUpperCase();
                      if (referralCodeController.text != upper) {
                        referralCodeController.value =
                            referralCodeController.value.copyWith(
                          text: upper,
                          selection:
                              TextSelection.collapsed(offset: upper.length),
                        );
                      }
                      if (value.isEmpty) {
                        setState(() {
                          referralCodeStatus = null;
                        });
                      }
                    },
                    validator: (value) {
                      // Referral code is optional
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  height: 56.0, // 與輸入欄位高度一致
                  child: ElevatedButton(
                    onPressed:
                        isVerifyingReferralCode ? null : _verifyReferralCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Theme.of(context).colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                    ),
                    child: isVerifyingReferralCode
                        ? SizedBox(
                            width: 20.0,
                            height: 20.0,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.0,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Theme.of(context).colorScheme.onPrimary,
                              ),
                            ),
                          )
                        : const Text('Verify'),
                  ),
                ),
              ],
            ),
            // 推薦碼狀態提示
            if (referralCodeStatus != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    referralCodeStatus == 'valid'
                        ? Icons.check_circle
                        : Icons.error,
                    size: 16.0,
                    color: _getReferralCodeStatusColor(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getReferralCodeStatusText(),
                      style: TextStyle(
                        fontSize: 14.0,
                        color: _getReferralCodeStatusColor(),
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 16),

            // Primary Languages
            Text(
              'Primary Languages *',
              style: TextStyle(
                fontSize: 16.0,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(0.4),
                  width: 1.0,
                ),
                borderRadius: BorderRadius.circular(12.0),
                color: Colors.transparent,
              ),
              child: Column(
                children: [
                  // 已選擇的語言標籤
                  if (selectedLanguages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Wrap(
                        spacing: 8.0,
                        runSpacing: 8.0,
                        children: selectedLanguages.map((langCode) {
                          final lang = languageOptions.firstWhere(
                            (lang) => lang['code'] == langCode,
                            orElse: () =>
                                {'code': '', 'name': '', 'native': ''},
                          );
                          return Container(
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.primary,
                              borderRadius: BorderRadius.circular(20.0),
                              border: Border.all(
                                color: Theme.of(context).colorScheme.primary,
                                width: 1.0,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20.0),
                                onTap: () {
                                  setState(() {
                                    selectedLanguages.remove(langCode);
                                  });
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12.0,
                                    vertical: 8.0,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        lang['native'] ??
                                            lang['name'] ??
                                            langCode,
                                        style: TextStyle(
                                          color: Theme.of(context)
                                              .colorScheme
                                              .onPrimary,
                                          fontSize: 14.0,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(width: 6.0),
                                      Icon(
                                        Icons.close,
                                        size: 16.0,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .onPrimary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),

                  // 語言選擇按鈕
                  if (selectedLanguages.length < 4)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: GestureDetector(
                        onTap: _showLanguageSelector,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.add_circle_outline,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24.0,
                              ),
                              const SizedBox(width: 8.0),
                              Text(
                                'Add Language',
                                style: TextStyle(
                                  color: Theme.of(context).colorScheme.primary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 16.0,
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                Icons.chevron_right,
                                color: Theme.of(context).colorScheme.primary,
                                size: 24.0,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Password
            TextFormField(
              controller: passwordController,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                helperText: 'At least 6 characters, letters and numbers only',
                suffixIcon: IconButton(
                  icon: Icon(
                    showPassword ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showPassword = !showPassword;
                    });
                  },
                ),
              ),
              obscureText: !showPassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              onChanged: (value) {
                // 即時檢查確認密碼
                if (confirmPasswordController.text.isNotEmpty) {
                  setState(() {});
                }
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(value)) {
                  return 'Password can only contain letters and numbers';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Password
            TextFormField(
              controller: confirmPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Password',
                border: const OutlineInputBorder(),
                helperText: confirmPasswordController.text.isNotEmpty &&
                        confirmPasswordController.text !=
                            passwordController.text
                    ? 'Passwords do not match'
                    : null,
                helperMaxLines: 1,
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showConfirmPassword = !showConfirmPassword;
                    });
                  },
                ),
              ),
              obscureText: !showConfirmPassword,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
              ],
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Divider
            const Divider(thickness: 2, color: AppColors.secondary),
            const SizedBox(height: 24),

            // Payment Security Section (wrapped in Container)
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Theme.of(context).colorScheme.surface,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(12.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Payment Security',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  // Payment Password (6 boxes)
                  const Text('Payment Password'),
                  const SizedBox(height: 8),
                  _buildPinputField(
                    controller: paymentPasswordController,
                    helperText: 'This will be used for payment verification',
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Please enter payment password';
                      if (t.length != 6)
                        return 'Payment password must be 6 digits';
                      if (!RegExp(r'^\d{6}$').hasMatch(t)) return 'Digits only';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  // Confirm Payment Password (6 boxes)
                  const Text('Confirm Payment Password'),
                  const SizedBox(height: 8),
                  _buildPinputField(
                    controller: confirmPaymentPasswordController,
                    onChanged: (t) {
                      // 及時驗證與第一次是否一致（6 碼時才比對）
                      if (t.length == 6 &&
                          t != paymentPasswordController.text) {
                        // 觸發一次重建以顯示 validator 的錯誤（若有包在 Form 中）
                        if (mounted) setState(() {});
                      }
                    },
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return 'Must be 6 digits';
                      if (t != paymentPasswordController.text) {
                        return 'Payment passwords do not match';
                      }
                      return null;
                    },
                    helperText: 'Must match the password above',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Complete Registration',
                        style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 6 位數輸入元件（圓角方格/底線樣式）
  // 使用六個單格 TextField，自動前進與退格回上一格
  // 外部以 controller 讀取最終字串

  void _showLanguageSelector() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              surfaceTintColor: Theme.of(context).colorScheme.surfaceTint,
              title: Text(
                'Select Languages',
                style: TextStyle(
                  fontSize: 18.0,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: Column(
                  children: [
                    // 搜尋框
                    TextField(
                      decoration: InputDecoration(
                        labelText: 'Search languages',
                        hintText: 'Type to search...',
                        prefixIcon: Icon(
                          Icons.search,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context)
                                .colorScheme
                                .outline
                                .withOpacity(0.3),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8.0),
                          borderSide: BorderSide(
                            color: Theme.of(context).colorScheme.primary,
                            width: 2.0,
                          ),
                        ),
                        filled: true,
                        fillColor: Theme.of(context).colorScheme.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 12.0,
                        ),
                      ),
                      style: TextStyle(
                        fontSize: 16.0,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                      onChanged: (value) {
                        setDialogState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    // 已選擇的語言提示
                    if (selectedLanguages.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          color: Theme.of(context)
                              .colorScheme
                              .primaryContainer
                              .withOpacity(0.3),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withOpacity(0.2),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.info_outline,
                              color: Theme.of(context).colorScheme.primary,
                              size: 20.0,
                            ),
                            const SizedBox(width: 8.0),
                            Expanded(
                              child: Text(
                                'Selected: ${selectedLanguages.length}/4 languages',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 16),
                    // 語言列表
                    Expanded(
                      child: ListView.builder(
                        itemCount: languageOptions.length,
                        itemBuilder: (context, index) {
                          final lang = languageOptions[index];
                          final isSelected =
                              selectedLanguages.contains(lang['code']);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 4.0),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Theme.of(context)
                                      .colorScheme
                                      .primaryContainer
                                      .withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(
                                color: isSelected
                                    ? Theme.of(context)
                                        .colorScheme
                                        .primary
                                        .withOpacity(0.3)
                                    : Colors.transparent,
                                width: 1.0,
                              ),
                            ),
                            child: CheckboxListTile(
                              title: Text(
                                lang['native'] ?? lang['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 16.0,
                                  fontWeight: FontWeight.w500,
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
                                ),
                              ),
                              subtitle: Text(
                                lang['name'] ?? '',
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withOpacity(0.7),
                                ),
                              ),
                              value: isSelected,
                              onChanged: (bool? value) {
                                setDialogState(() {
                                  if (value == true &&
                                      selectedLanguages.length < 4) {
                                    selectedLanguages.add(lang['code']!);
                                  } else if (value == false) {
                                    selectedLanguages.remove(lang['code']!);
                                  }
                                });
                              },
                              activeColor:
                                  Theme.of(context).colorScheme.primary,
                              checkColor:
                                  Theme.of(context).colorScheme.onPrimary,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 8.0,
                              ),
                            ),
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
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.6),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {});
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('OK'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _handleSubmit() async {
    // Ensure at least one language is selected
    if (selectedLanguages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select at least one language')),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 先創建用戶帳號
      final success = await _createUserAccount();

      if (success) {
        // 儲存表單資料到 SharedPreferences 以便傳遞到下一個頁面
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('signup_full_name', fullNameController.text);
        await prefs.setString('signup_nickname', nicknameController.text);
        await prefs.setString('signup_gender', selectedGender);
        await prefs.setString('signup_email', emailController.text);
        await prefs.setString('signup_phone', phoneController.text);
        await prefs.setString('signup_country', countryController.text);
        await prefs.setString('signup_address', addressController.text);
        await prefs.setString('signup_password', passwordController.text);
        await prefs.setString(
            'signup_date_of_birth', dateOfBirthController.text);
        await prefs.setString(
            'signup_payment_code', paymentPasswordController.text);
        await prefs.setBool('signup_is_permanent_address', isPermanentAddress);
        await prefs.setStringList('signup_languages', selectedLanguages);

        // 導向學生證上傳頁面
        context.go('/signup/student-id');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _createUserAccount() async {
    try {
      // 準備學校資訊
      String? schoolName;
      if (selectedUniversityId == 'other') {
        schoolName = schoolController.text;
      } else if (selectedUniversityId != null) {
        final university = universityOptions.firstWhere(
          (u) => u['id'].toString() == selectedUniversityId,
          orElse: () => {},
        );
        if (university.isNotEmpty) {
          '${university['abbr']} - ${university['en_name']} - ${university['zh_name']}';
        }
      }

      final response = await http.post(
        Uri.parse(AppConfig.registerUrl),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'full_name': fullNameController.text,
          'nickname': nicknameController.text,
          'gender': selectedGender,
          'email': emailController.text,
          'phone': phoneController.text,
          'country': countryController.text,
          'address': addressController.text,
          'password': passwordController.text,
          'date_of_birth': dateOfBirthController.text,
          'payment_password': paymentPasswordController.text,
          'is_permanent_address': isPermanentAddress,
          'primary_language': selectedLanguages.join(','),
          'school': schoolName,
          'referral_code': referralCodeController.text.trim(),
        }),
      );

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Account created successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        return true;
      } else {
        throw Exception(responseData['message'] ?? 'Failed to create account');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create account: $e'),
          backgroundColor: Colors.red,
        ),
      );
      return false;
    }
  }

  /// 建立 6 位數字密碼輸入欄位（使用 Pinput）
  Widget _buildPinputField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? helperText,
  }) {
    final defaultPinTheme = PinTheme(
      width: 45,
      height: 50,
      textStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400),
        borderRadius: BorderRadius.circular(8),
      ),
    );

    final focusedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border: Border.all(color: Theme.of(context).primaryColor, width: 2),
      ),
    );

    final submittedPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade400),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Pinput(
          controller: controller,
          length: 6,
          defaultPinTheme: defaultPinTheme,
          focusedPinTheme: focusedPinTheme,
          submittedPinTheme: submittedPinTheme,
          validator: validator,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          obscureText: true,
          autofocus: false,
          pinputAutovalidateMode: PinputAutovalidateMode.onSubmit,
        ),
        if (helperText != null) ...[
          const SizedBox(height: 4),
          Text(
            helperText,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
        ],
      ],
    );
  }
}
