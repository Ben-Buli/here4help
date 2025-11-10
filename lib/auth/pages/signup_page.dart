// signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/task/services/language_service.dart';
import 'package:here4help/services/country_service.dart';
import 'package:pinput/pinput.dart';
import 'package:http/http.dart' as http;
import 'package:here4help/services/api/oauth_api.dart';
import 'dart:convert';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/auth/services/signup_draft_service.dart';

class SignupPage extends StatefulWidget {
  final Map<String, dynamic>? oauthData;

  const SignupPage({super.key, this.oauthData});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> with WidgetsBindingObserver {
  final _signupEmailKey = GlobalKey<FormFieldState<String>>();

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

  // 推薦碼狀態
  final referralCodeMap = {
    'empty': 'empty',
    'valid': 'valid',
    'invalid': 'invalid',
    'not_found': 'not_found',
  };

  // 性別選項
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
  // 性別選項列表
  late final List<String> genderOptions = genderParams.keys.toList();

  // 以下為表單狀態
  late String selectedGender;
  String? oauthAvatarUrl; // 新增：OAuth 頭像 URL
  bool isPermanentAddress = false;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool showPaymentPins = false;
  bool _shouldConfirmLeave = true;

  @override
  void initState() {
    super.initState();
    selectedGender =
        genderParams['Prefer not to disclose'] ?? 'Prefer not to disclose';
    WidgetsBinding.instance.addObserver(this);
    _loadLanguages();
    _loadUniversities();
    _loadCountries(); // 新增：載入國家列表
    // 延遲載入第三方登入資料，確保其他資料先載入完成
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeDraftStateAndLoadOAuth();
    });
  }

  bool showPaymentPassword = false;
  bool showConfirmPaymentPassword = false;
  bool isVerifyingReferralCode = false;
  String? referralCodeStatus; // 'valid', 'invalid', 'not_found'

  // 語言選項
  List<Map<String, dynamic>> languageOptions = [];
  List<String> selectedLanguages = ['en'];
  bool languagesError = false;

  // 大學選項
  List<Map<String, dynamic>> universityOptions = [];
  String? selectedUniversityId;

  // 國家選項
  List<Country> countryOptions = [];
  Country? selectedCountry;
  bool isLoadingCountries = false;

  Future<void> _initializeDraftStateAndLoadOAuth() async {
    await _initializeDraftState();
    await _loadThirdPartyData();
  }

  Future<void> _initializeDraftState() async {
    final prefs = await SharedPreferences.getInstance();
    if (_hasOAuthIntent(prefs)) {
      await _loadExistingData(prefs);
    } else {
      await SignupDraftService.clearWithPrefs(prefs, includeOAuth: true);
      _resetFormFields();
    }
  }

  bool _hasOAuthIntent(SharedPreferences prefs) {
    final uri = Uri.base;
    final token = uri.queryParameters['token'];
    final oauthToken = uri.queryParameters['oauth_token'];
    final hasQueryToken = (token != null && token.isNotEmpty) ||
        (oauthToken != null && oauthToken.isNotEmpty);
    final hasWidgetData =
        widget.oauthData != null && widget.oauthData!.isNotEmpty;
    final storedProvider = prefs.getString('signup_provider');
    final storedToken = prefs.getString('signup_oauth_token');
    return hasQueryToken ||
        hasWidgetData ||
        (storedProvider != null && storedProvider.isNotEmpty) ||
        (storedToken != null && storedToken.isNotEmpty);
  }

  void _resetFormFields({bool useSetState = true}) {
    fullNameController.clear();
    nicknameController.clear();
    emailController.clear();
    phoneController.clear();
    countryController.clear();
    addressController.clear();
    passwordController.clear();
    confirmPasswordController.clear();
    dateOfBirthController.clear();
    paymentPasswordController.clear();
    confirmPaymentPasswordController.clear();
    schoolController.clear();
    referralCodeController.clear();

    void updater() {
      selectedGender =
          genderParams['Prefer not to disclose'] ?? 'Prefer not to disclose';
      selectedLanguages = ['en'];
      selectedUniversityId = null;
      selectedCountry = null;
      isPermanentAddress = false;
      oauthAvatarUrl = null;
      referralCodeStatus = null;
      isVerifyingReferralCode = false;
      showPassword = false;
      showConfirmPassword = false;
      showPaymentPassword = false;
      showConfirmPaymentPassword = false;
      showPaymentPins = false;
    }

    if (useSetState && mounted) {
      setState(updater);
    } else {
      updater();
    }
  }

  // 新增：載入第三方登入資料
  Future<void> _loadThirdPartyData() async {
    debugPrint('🚀 [SignupPage] 開始載入第三方登入資料...');

    // 支援 token 預填：/signup?token=...
    final uri = Uri.base;
    debugPrint('🔍 [SignupPage] 當前 URL: ${uri.toString()}');
    debugPrint('🔍 [SignupPage] URL 參數: ${uri.queryParameters}');

    // 在 Flutter Web 中，優先從 Uri.base 獲取參數
    String? tokenParam = uri.queryParameters['token'];
    debugPrint('🔍 [SignupPage] 從 Uri.base 獲取 Token 參數: $tokenParam');

    // 如果 Uri.base 沒有參數，嘗試從 GoRouter 獲取（在 didChangeDependencies 中）
    if (tokenParam == null || tokenParam.isEmpty) {
      try {
        // 嘗試從 GoRouter 獲取當前路由的 query 參數
        final routerState = GoRouterState.of(context);
        tokenParam = routerState.uri.queryParameters['token'];
        debugPrint('🔍 [SignupPage] GoRouter Token 參數: $tokenParam');
      } catch (e) {
        debugPrint('⚠️ [SignupPage] 無法從 GoRouter 獲取參數: $e');
      }
    }

    debugPrint('🔍 [SignupPage] 最終 Token 參數: $tokenParam');

    final prefs = await SharedPreferences.getInstance();
    var hasPrefilled = false;

    if (tokenParam != null && tokenParam.isNotEmpty) {
      try {
        debugPrint('🔍 開始獲取 OAuth 暫存資料，token: $tokenParam');
        final temp = await OAuthApi.fetchTempUser(tokenParam);
        if (temp != null) {
          debugPrint('✅ 成功獲取 OAuth 暫存資料: $temp');
          _prefillOAuthData(temp);
          hasPrefilled = true;
        } else {
          debugPrint('⚠️ OAuth 暫存資料為空');
        }
      } catch (e) {
        debugPrint('❌ OAuth token 預填失敗: $e');
      }
    } else {
      debugPrint('⚠️ 沒有找到 OAuth token 參數');
    }

    // 優先使用傳入的 oauthData
    if (!hasPrefilled &&
        widget.oauthData != null &&
        widget.oauthData!.isNotEmpty) {
      print('🔐 載入第三方登入資料: ${widget.oauthData}');
      _prefillOAuthData(widget.oauthData!);
      hasPrefilled = true;
    }

    // 備用：從 SharedPreferences 載入
    if (!hasPrefilled) {
      final provider = prefs.getString('signup_provider');
      if (provider != null && provider.isNotEmpty) {
        final storedLanguages = prefs.getStringList('signup_languages');
        final storedData = <String, dynamic>{
          'name': prefs.getString('signup_full_name') ?? '',
          'nickname': prefs.getString('signup_nickname') ?? '',
          'email': prefs.getString('signup_email') ?? '',
          'avatar_url': prefs.getString('signup_avatar_url') ?? '',
          'phone': prefs.getString('signup_phone') ?? '',
          'country': prefs.getString('signup_country') ?? '',
          'address': prefs.getString('signup_address') ?? '',
          'birthday': prefs.getString('signup_date_of_birth') ?? '',
          'gender': prefs.getString('signup_gender') ?? '',
          'languages': storedLanguages,
        };
        _prefillOAuthData(storedData);
        hasPrefilled = true;
      }
    }

    if (!hasPrefilled) {
      debugPrint('ℹ️ 沒有可用的第三方登入資料，保持空白表單');
    }

    await prefs.remove('signup_provider');
    await prefs.remove('signup_provider_user_id');
    await prefs.remove('signup_avatar_url');
  }

  // 預填第三方登入資料
  void _prefillOAuthData(Map<String, dynamic> oauthData) {
    try {
      debugPrint('🔍 開始預填 OAuth 資料: $oauthData');
      _resetFormFields();

      final defaultGender =
          genderParams['Prefer not to disclose'] ?? 'Prefer not to disclose';
      var resolvedGender = defaultGender;
      List<String> resolvedLanguages = ['en'];
      String? resolvedAvatarUrl;

      String? stringValue(dynamic value) {
        if (value is String) {
          final trimmed = value.trim();
          return trimmed.isNotEmpty ? trimmed : null;
        }
        return null;
      }

      void assignController(TextEditingController controller, dynamic value) {
        final text = stringValue(value);
        if (text != null) {
          controller.text = text;
        }
      }

      assignController(fullNameController, oauthData['name']);
      assignController(emailController, oauthData['email']);
      assignController(phoneController, oauthData['phone']);
      assignController(countryController, oauthData['country']);
      assignController(addressController, oauthData['address']);
      assignController(dateOfBirthController, oauthData['date_of_birth']);
      if (dateOfBirthController.text.isEmpty) {
        assignController(dateOfBirthController, oauthData['birthday']);
      }

      final nickname =
          stringValue(oauthData['nickname']) ?? stringValue(oauthData['name']);
      if (nickname != null) {
        nicknameController.text = nickname;
      }

      final avatarUrl = stringValue(oauthData['avatar_url']);
      if (avatarUrl != null) {
        resolvedAvatarUrl = avatarUrl;
        debugPrint('🖼️ 第三方登入頭像: $avatarUrl');
      }

      final gender = stringValue(oauthData['gender']);
      if (gender != null && genderParams.containsKey(gender)) {
        resolvedGender = gender;
        debugPrint('✅ 預填性別: $gender');
      }

      final dynamic languagesValue = oauthData['languages'];
      if (languagesValue is List) {
        final cleaned = languagesValue
            .whereType<String>()
            .map((lang) => lang.trim())
            .where((lang) => lang.isNotEmpty)
            .toList();
        if (cleaned.isNotEmpty) {
          resolvedLanguages = cleaned;
          debugPrint('✅ 預填語言列表: $resolvedLanguages');
        }
      }

      if (resolvedLanguages.length == 1 &&
          resolvedLanguages.first == 'en' &&
          oauthData['language'] != null) {
        final singleLanguage = stringValue(oauthData['language']);
        if (singleLanguage != null) {
          resolvedLanguages = [singleLanguage];
          debugPrint('✅ 預填語言: $singleLanguage');
        }
      }

      if (resolvedLanguages.length == 1 &&
          resolvedLanguages.first == 'en' &&
          oauthData['primary_language'] != null) {
        final primaryLanguage = stringValue(oauthData['primary_language']);
        if (primaryLanguage != null) {
          resolvedLanguages = [primaryLanguage];
          debugPrint('✅ 預填主要語言: $primaryLanguage');
        }
      }

      if (mounted) {
        setState(() {
          selectedGender = resolvedGender;
          selectedLanguages = resolvedLanguages;
          oauthAvatarUrl = resolvedAvatarUrl;
        });
      }

      debugPrint('✅ 第三方登入資料預填完成');
    } catch (e) {
      debugPrint('❌ 預填第三方登入資料失敗: $e');
    }
  }

  // 處理國家選擇變更
  // void _onCountryChanged(Country? country) {
  //   if (country != null) {
  //     setState(() {
  //       selectedCountry = country;
  //     });

  //     // 自動填充主要語言
  //     _autoFillPrimaryLanguage(country);

  //     print('🌍 選擇國家: ${country.name}');
  //     print('🗣️ 主要語言: ${country.languages.join(', ')}');
  //   }
  // }

  // 自動填充主要語言
  // void _autoFillPrimaryLanguage(Country country) {
  //   if (country.languages.isNotEmpty) {
  //     final primaryLanguage = country.languages.first;

  //     // 更新 selectedLanguages
  //     setState(() {
  //       selectedLanguages = [primaryLanguage];
  //       languagesError = false;
  //     });

  //     print('✅ 自動填充主要語言: $primaryLanguage');
  //   }
  // }

  // 處理 OAuth 註冊
  Future<void> _handleOAuthRegistration(String oauthToken) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final referral = referralCodeController.text.trim();
      await prefs.setBool('signup_is_oauth', true);
      await prefs.setString('signup_oauth_token', oauthToken);
      await prefs.setString('signup_full_name', fullNameController.text.trim());
      await prefs.setString('signup_nickname', nicknameController.text.trim());
      await prefs.setString('signup_gender', selectedGender);
      await prefs.setString('signup_email', emailController.text.trim());
      await prefs.setString('signup_phone', phoneController.text.trim());
      await prefs.setString('signup_country', countryController.text);
      await prefs.setString('signup_address', addressController.text.trim());
      await prefs.setString(
          'signup_date_of_birth', dateOfBirthController.text.trim());
      await prefs.setBool('signup_is_permanent_address', isPermanentAddress);
      await prefs.setStringList('signup_languages', selectedLanguages);
      await prefs.setString('signup_referral_code', referral);
      await prefs.setString('signup_avatar_url', oauthAvatarUrl ?? '');
      await prefs.setString('signup_oauth_provider',
          widget.oauthData?['provider']?.toString() ?? '');
      await prefs.remove('signup_password');
      await prefs.remove('signup_payment_code');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Basic information saved. Please upload your student ID to finish registration.'),
        ),
      );
      _shouldConfirmLeave = false;
      context.go('/signup/student-id');
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Failed to save registration draft: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // 顯示錯誤提示
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  // 獲取學校值
  String _getSchoolValue() {
    if (selectedUniversityId == 'other') {
      return schoolController.text.trim();
    } else if (selectedUniversityId != null) {
      final university = universityOptions.firstWhere(
        (u) => u['id'].toString() == selectedUniversityId,
        orElse: () => {},
      );
      if (university.isNotEmpty) {
        return university['abbr']; // 寫入使用者資料只返回學校名稱縮寫
      }
    }
    return '';
  }

  Future<void> _loadLanguages() async {
    try {
      final langs = await LanguageService.getLanguages();
      setState(() {
        languageOptions = langs;
        // Optionally clear language error if languages loaded and selectedLanguages is not empty
        if (selectedLanguages.isNotEmpty) languagesError = false;
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
        if (selectedLanguages.isNotEmpty) languagesError = false;
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

  // 新增：載入國家列表
  Future<void> _loadCountries() async {
    try {
      setState(() {
        isLoadingCountries = true;
      });

      print('🌍 開始載入國家列表...');
      final countries = await CountryService.getAllCountries();

      setState(() {
        countryOptions = countries;
        isLoadingCountries = false;
      });

      print('✅ 成功載入 ${countries.length} 個國家');
    } catch (e) {
      print('❌ 載入國家列表失敗: $e');
      setState(() {
        isLoadingCountries = false;
        // 使用預設國家列表
        countryOptions = CountryService.getDefaultCountries();
      });
    }
  }

  // 新增：驗證推薦碼
  Future<void> _verifyReferralCode() async {
    final referralCode = referralCodeController.text.trim();
    if (referralCode.isEmpty || referralCode == '') {
      setState(() {
        referralCodeStatus = referralCodeMap['empty'];
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
        if (data['data'] == '' || data['data'].isEmpty) {
          referralCodeStatus = referralCodeMap['empty'];
        } else if (data['success'] && data['data'] != null) {
          referralCodeStatus = referralCodeMap['valid'];
        } else if (data['success'] && data['data'] == null) {
          referralCodeStatus = referralCodeMap['not_found'];
        } else {
          referralCodeStatus = referralCodeMap['invalid'];
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
      case 'empty':
        return Theme.of(context).colorScheme.error;
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
      case 'empty':
        return 'Please enter a referral code';
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

  Future<void> _loadExistingData([SharedPreferences? existingPrefs]) async {
    final prefs = existingPrefs ?? await SharedPreferences.getInstance();

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
    _showLeaveConfirmationDialog();
  }

  Future<bool> _showLeaveConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Leave registration?'),
          content: const Text(
              'Your registration is not complete yet. Are you sure you want to leave this page?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
        onWillPop: () async {
          if (!_shouldConfirmLeave) {
            return true;
          }
          return await _showLeaveConfirmationDialog();
        },
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // OAuth Avatar Preview (if available)
                if (oauthAvatarUrl != null) ...[
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.network(
                              oauthAvatarUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(
                                  Icons.person,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                );
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Full Name
                TextFormField(
                  controller: fullNameController,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.person,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    labelText: 'Your Name *',
                    border: const OutlineInputBorder(),
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
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.alternate_email,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    labelText: 'Nickname',
                    border: const OutlineInputBorder(),
                    helperText:
                        'Enter the name you prefer to be called (optional)',
                  ),
                  validator: (value) {
                    // Nickname is optional
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Gender Selection
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender *',
                    prefixIcon: Icon(
                      Icons.star,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: const OutlineInputBorder(),
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                FocusScope(
                  onFocusChange: (hasFocus) {
                    if (!hasFocus) {
                      _signupEmailKey.currentState?.validate();
                    }
                  },
                  child: TextFormField(
                    key: _signupEmailKey,
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      prefixIcon: Icon(
                        Icons.alternate_email,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      labelText: 'Email *',
                      border: const OutlineInputBorder(),
                      hintText: 'name@example.com',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(value.trim())) {
                        return 'Please enter a valid email format (e.g. name@example.com)';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // Phone Number
                TextFormField(
                  controller: phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.phone,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    labelText: 'Phone number *',
                    border: const OutlineInputBorder(),
                    hintText: 'Taiwan format: 09xxxxxxxx or +8869xxxxxxxx',
                  ),
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
                  keyboardType: TextInputType.datetime,
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.calendar_month,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    labelText: 'Birthday *',
                    hintText: 'YYYY/MM/DD',
                    border: const OutlineInputBorder(),
                  ),
                  readOnly: true,
                  onTap: () async {
                    final date = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now()
                          .subtract(const Duration(days: 6570)), // 18 years ago
                      firstDate: DateTime.now().subtract(
                          const Duration(days: 36500)), // 100 years ago
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
                TextFormField(
                  controller: addressController,
                  keyboardType: TextInputType.multiline,
                  minLines: 1,
                  maxLines: 3, // 自動換行且最多三行，不影響實際值
                  decoration: InputDecoration(
                    prefixIcon: Icon(
                      Icons.location_on,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    labelText: 'Address *',
                    border: const OutlineInputBorder(),
                    // 將 Permanent 自訂 Switch 放到輸入欄位右邊
                    suffixIcon: Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: GestureDetector(
                        onTap: () => setState(
                            () => isPermanentAddress = !isPermanentAddress),
                        child: _PermanentPillSwitch(
                          value: isPermanentAddress,
                          label: 'Permanent',
                        ),
                      ),
                    ),
                    suffixIconConstraints:
                        const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your address';
                    }
                    return null;
                  },
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
                    prefixIcon: Icon(
                      Icons.school,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12.0, vertical: 12.0),
                  ),
                  hint: Text(
                    'Select your school',
                    style: TextStyle(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
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
                                  color:
                                      Theme.of(context).colorScheme.onSurface,
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
                    maxLength: 20,
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
                      if (value.trim().length > 20) {
                        return 'School name cannot exceed 20 characters';
                      }
                      return null;
                    },
                  ),
                ],

                // Referral Code - 新增（整合 Verify 按鈕至欄位）
                const SizedBox(height: 16),
                TextFormField(
                  controller: referralCodeController,
                  decoration: InputDecoration(
                    labelText: 'Referral Code',
                    hintText: 'Enter referral code (optional)',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                    contentPadding: const EdgeInsets.only(
                        left: 16.0, top: 12.0, bottom: 12.0, right: 0.0),
                    prefixIcon: Icon(
                      Icons.card_giftcard,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    suffixIcon: SizedBox(
                      width: 80,
                      height: 46,
                      child: _ReferralInlineButton(
                        fieldRadius: 8.0,
                        label: 'Verify',
                        isLoading: isVerifyingReferralCode,
                        status: referralCodeStatus,
                        onPressed: _verifyReferralCode,
                        icon: referralCodeStatus == 'valid'
                            ? Icons.check_circle
                            : referralCodeStatus == 'invalid'
                                ? Icons.error
                                : null,
                      ),
                    ),
                    suffixIconConstraints: const BoxConstraints(
                      minWidth: 80,
                      maxWidth: 80,
                      minHeight: 40,
                      maxHeight: 48,
                    ),
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
                    // 任何變更都重置狀態（按鈕回到預設樣式）
                    setState(() {
                      referralCodeStatus = null;
                    });
                  },
                  validator: (value) {
                    // Referral code is optional
                    return null;
                  },
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
                    fontSize: 14.0,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: languagesError
                          ? Theme.of(context).colorScheme.error
                          : Theme.of(context)
                              .colorScheme
                              .outline
                              .withOpacity(0.4),
                      width: 1.0,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
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
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                                        languagesError = false;
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
                              padding:
                                  const EdgeInsets.symmetric(vertical: 8.0),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.add_circle_outline,
                                    color:
                                        Theme.of(context).colorScheme.primary,
                                    size: 24.0,
                                  ),
                                  const SizedBox(width: 8.0),
                                  Text(
                                    'Add Language',
                                    style: TextStyle(
                                      color:
                                          Theme.of(context).colorScheme.primary,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16.0,
                                    ),
                                  ),
                                  const Spacer(),
                                  Icon(
                                    Icons.chevron_right,
                                    color:
                                        Theme.of(context).colorScheme.primary,
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
                if (languagesError) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Please select at least one language',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                const SizedBox(height: 16),

                // 分隔線
                Divider(
                  thickness: 2,
                  color: Theme.of(context).colorScheme.secondary,
                ),
                const SizedBox(height: 24),
                // Account Password Section (wrapped like Payment Security)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: 0.5,
                        ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Account Password *',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          IconButton(
                            tooltip: (showPassword || showConfirmPassword)
                                ? 'Hide passwords'
                                : 'Show passwords',
                            icon: Icon(
                              (showPassword || showConfirmPassword)
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () {
                              setState(() {
                                final next =
                                    !(showPassword || showConfirmPassword);
                                showPassword = next;
                                showConfirmPassword = next;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        decoration: InputDecoration(
                          labelText: 'Password *',
                          prefixIcon: Icon(
                            Icons.lock_outline,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(
                                  alpha: 0.5,
                                ),
                          ),
                          border: const OutlineInputBorder(),
                          hintText: 'At least 6 characters, a-z, A-Z, 0-9',
                        ),
                        obscureText: !showPassword,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')),
                        ],
                        onChanged: (value) {
                          if (confirmPasswordController.text.isNotEmpty) {
                            setState(() {});
                          }
                        },
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
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
                      TextFormField(
                        controller: confirmPasswordController,
                        decoration: InputDecoration(
                          labelText: 'Confirm Password again *',
                          prefixIcon: Icon(
                            Icons.lock,
                            color: Theme.of(context)
                                .colorScheme
                                .primary
                                .withValues(
                                  alpha: 0.5,
                                ),
                          ),
                          border: const OutlineInputBorder(),
                          hintText: 'Confirm your password again',
                          helperText: confirmPasswordController.text !=
                                  passwordController.text
                              ? 'Passwords do not match'
                              : null,
                          helperMaxLines: 1,
                        ),
                        obscureText: !showConfirmPassword,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                              RegExp(r'[a-zA-Z0-9]')),
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Payment Security Section (wrapped in Container)
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface.withValues(
                          alpha: 0.5,
                        ),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Payment Security',
                            style: TextStyle(
                                fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          IconButton(
                            tooltip: showPaymentPins
                                ? 'Hide payment code'
                                : 'Show payment code',
                            icon: Icon(
                              showPaymentPins
                                  ? Icons.visibility
                                  : Icons.visibility_off,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            onPressed: () => setState(() {
                              showPaymentPins = !showPaymentPins;
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Payment Password (6 boxes)
                      const Text('Password *'),
                      const SizedBox(height: 8),
                      _buildPinputField(
                        controller: paymentPasswordController,
                        // helperText: 'This will be used for payment verification',
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Please enter payment password';
                          if (t.length != 6) {
                            return 'Payment password must be 6 digits';
                          }
                          if (!RegExp(r'^\d{6}$').hasMatch(t)) {
                            return 'Digits only';
                          }
                          return null;
                        },
                        obscure: !showPaymentPins,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                      ),
                      const SizedBox(height: 16),
                      // Confirm Payment Password (6 boxes)
                      const Text('Confirm Password *'),
                      const SizedBox(height: 8),
                      _buildPinputField(
                        controller: confirmPaymentPasswordController,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
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
                        // helperText: 'Must match the password above',
                        obscure: !showPaymentPins,
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
        ));
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
                width: 400,
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
                                setState(() {
                                  languagesError = false;
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
                    setState(() {
                      languagesError = false;
                    });
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
      setState(() {
        languagesError = true;
      });
      return;
    } else {
      setState(() {
        languagesError = false;
      });
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // 送出前：若推薦碼非空且尚未驗證為 valid，阻擋送出
      final referral = referralCodeController.text.trim();
      if (referral.isNotEmpty && referralCodeStatus != 'valid') {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Referral code is invalid or not verified'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        return;
      }
      // 檢查是否有 OAuth token，決定使用哪種註冊方式
      final uri = Uri.base;
      final oauthToken = uri.queryParameters['token'] ??
          uri.queryParameters['oauth_token'] ??
          widget.oauthData?['oauth_token'] ??
          widget.oauthData?['token'];

      if (oauthToken != null && oauthToken.isNotEmpty) {
        // 使用 OAuth 註冊草稿，待學生證上傳後送出
        await _handleOAuthRegistration(oauthToken);
      } else {
        // 使用傳統註冊：先將資料暫存，待學生證上傳時一次送出
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
        await prefs.setString(
            'signup_referral_code', referralCodeController.text.trim());
        await prefs.setBool('signup_is_oauth', false);
        await prefs.remove('signup_oauth_token');
        await prefs.remove('signup_oauth_provider');
        await prefs.remove('signup_avatar_url');

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Account details saved. Please upload your student ID to complete registration.'),
          ),
        );

        // 導向學生證上傳頁面
        _shouldConfirmLeave = false;
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

  /// 建立 6 位數字密碼輸入欄位（使用 Pinput）
  Widget _buildPinputField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    String? helperText,
    bool obscure = true,
    required List<TextInputFormatter> inputFormatters,
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

    final errorPinTheme = defaultPinTheme.copyWith(
      decoration: defaultPinTheme.decoration!.copyWith(
        border:
            Border.all(color: Theme.of(context).colorScheme.error, width: 2),
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
          errorPinTheme: errorPinTheme,
          validator: validator,
          onChanged: onChanged,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          obscureText: obscure,
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

/// 自訂膠囊開關，放在 TextFormField 的 suffix 位置使用
class _PermanentPillSwitch extends StatelessWidget {
  final bool value;
  final String label;
  const _PermanentPillSwitch({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final on = value;
    final cs = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: on
            ? cs.primary.withOpacity(0.12)
            : cs.surfaceContainerHighest.withOpacity(0.6),
        border: Border.all(
          color: on ? cs.primary : cs.outline.withOpacity(0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            on ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 18,
            color: on ? Colors.green : cs.onSurface.withOpacity(0.65),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: on ? cs.onSurface : cs.onSurface.withOpacity(0.75),
            ),
          ),
        ],
      ),
    );
  }
}

/// 內嵌在輸入欄位右側的驗證按鈕：loading > success/fail > onChange 重置
class _ReferralInlineButton extends StatelessWidget {
  final bool isLoading;

  /// 'valid' | 'invalid' | 'not_found' | null
  final String? status;
  final VoidCallback? onPressed;
  final double fieldRadius;
  final String label;
  final IconData? icon;
  const _ReferralInlineButton({
    required this.isLoading,
    required this.status,
    required this.onPressed,
    this.fieldRadius = 8.0,
    this.label = 'Verify',
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isSuccess = status == 'valid';
    final bool isFail = status == 'invalid' || status == 'not_found';
    final Color bg = isSuccess
        ? Theme.of(context).colorScheme.surfaceBright
        : isFail
            ? Theme.of(context).colorScheme.error
            : theme.colorScheme.primary;
    const Color fg = Colors.white;

    return ConstrainedBox(
      constraints:
          const BoxConstraints(minHeight: 44, maxHeight: 48, minWidth: 80),
      child: ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(fieldRadius),
          bottomRight: Radius.circular(fieldRadius),
        ),
        child: Material(
          color: bg,
          child: InkWell(
            onTap: isLoading
                ? null
                : () {
                    // Guard clause: check if referral code is empty before proceeding
                    final signupPageState =
                        context.findAncestorStateOfType<_SignupPageState>();
                    if (signupPageState != null &&
                        signupPageState.referralCodeController.text
                            .trim()
                            .isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please enter a referral code'),
                          backgroundColor: Theme.of(context).colorScheme.error,
                        ),
                      );
                      return;
                    }
                    if (onPressed != null) {
                      onPressed!();
                    }
                  },
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white)),
                    )
                  : Text(
                      label,
                      style: const TextStyle(
                          color: fg, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
