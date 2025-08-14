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

  String selectedGender = 'Male';
  bool isPermanentAddress = false;
  bool isLoading = false;
  bool showPassword = false;
  bool showConfirmPassword = false;
  bool showPaymentPassword = false;
  bool showConfirmPaymentPassword = false;

  // 性別選項
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

  // 語言選項
  List<Map<String, dynamic>> languageOptions = [];

  List<String> selectedLanguages = ['en'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExistingData();
    _loadPrefilledData();
    _loadLanguages();
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
      selectedGender = prefs.getString('signup_gender') ?? 'Male';
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
                labelText: 'Full Name (as shown on ID)',
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
              ),
              keyboardType: TextInputType.phone,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your phone number';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Country
            TextFormField(
              controller: countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your country';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Primary Languages
            const Text('Primary Languages',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.secondary),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                children: [
                  // 已選擇的語言標籤
                  if (selectedLanguages.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: selectedLanguages.map((langCode) {
                          final lang = languageOptions.firstWhere(
                            (lang) => lang['code'] == langCode,
                            orElse: () =>
                                {'code': '', 'name': '', 'native': ''},
                          );
                          return Chip(
                            label: Text(
                                lang['native'] ?? lang['name'] ?? langCode),
                            onDeleted: () {
                              setState(() {
                                selectedLanguages.remove(langCode);
                              });
                            },
                            backgroundColor: AppColors.primary,
                            labelStyle: const TextStyle(color: Colors.white),
                            deleteIconColor: Colors.white,
                          );
                        }).toList(),
                      ),
                    ),

                  // 語言選擇按鈕
                  if (selectedLanguages.length < 4)
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Language'),
                      onTap: _showLanguageSelector,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Address
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
                // Permanent Address Radio Button
                Column(
                  children: [
                    const Text('Permanent', style: TextStyle(fontSize: 12)),
                    Radio<bool>(
                      value: true,
                      groupValue: isPermanentAddress,
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

            // Date of Birth
            TextFormField(
              controller: dateOfBirthController,
              decoration: const InputDecoration(
                labelText: 'Date of Birth',
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

            // Divider
            const Divider(thickness: 2, color: AppColors.secondary),
            const SizedBox(height: 32),

            // Payment Password Section
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
                if (t.length != 6) return 'Payment password must be 6 digits';
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
                if (t.length == 6 && t != paymentPasswordController.text) {
                  // 觸發一次重建以顯示 validator 的錯誤（若有包在 Form 中）
                  if (mounted) setState(() {});
                }
              },
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Please confirm payment password';
                if (t.length != 6) return 'Must be 6 digits';
                if (t != paymentPasswordController.text) {
                  return 'Payment passwords do not match';
                }
                return null;
              },
              helperText: 'Must match the password above',
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.onPrimary,
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
                        itemCount: languageOptions.length,
                        itemBuilder: (context, index) {
                          final lang = languageOptions[index];
                          final isSelected =
                              selectedLanguages.contains(lang['code']);

                          return CheckboxListTile(
                            title: Text(lang['native'] ?? lang['name'] ?? ''),
                            subtitle: Text(lang['name'] ?? ''),
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
                    setState(() {});
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

  void _handleSubmit() async {
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
      final response = await http.post(
        Uri.parse(
            'http://localhost:8888/here4help/backend/api/auth/register.php'),
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
