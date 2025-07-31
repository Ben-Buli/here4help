// signup_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:here4help/constants/app_colors.dart';
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
    'Non-binary',
    'Genderfluid',
    'Agender',
    'Bigender',
    'Genderqueer',
    'Two-spirit',
    'Prefer not to say',
    'Other'
  ];

  // 語言選項
  final List<Map<String, String>> languageOptions = [
    {'code': 'en', 'name': 'English', 'native': 'English'},
    {'code': 'zh', 'name': 'Chinese', 'native': '中文'},
    {'code': 'es', 'name': 'Spanish', 'native': 'Español'},
    {'code': 'fr', 'name': 'French', 'native': 'Français'},
    {'code': 'de', 'name': 'German', 'native': 'Deutsch'},
    {'code': 'ja', 'name': 'Japanese', 'native': '日本語'},
    {'code': 'ko', 'name': 'Korean', 'native': '한국어'},
    {'code': 'pt', 'name': 'Portuguese', 'native': 'Português'},
    {'code': 'ru', 'name': 'Russian', 'native': 'Русский'},
    {'code': 'ar', 'name': 'Arabic', 'native': 'العربية'},
    {'code': 'hi', 'name': 'Hindi', 'native': 'हिन्दी'},
    {'code': 'it', 'name': 'Italian', 'native': 'Italiano'},
    {'code': 'nl', 'name': 'Dutch', 'native': 'Nederlands'},
    {'code': 'sv', 'name': 'Swedish', 'native': 'Svenska'},
    {'code': 'da', 'name': 'Danish', 'native': 'Dansk'},
    {'code': 'no', 'name': 'Norwegian', 'native': 'Norsk'},
    {'code': 'fi', 'name': 'Finnish', 'native': 'Suomi'},
    {'code': 'pl', 'name': 'Polish', 'native': 'Polski'},
    {'code': 'tr', 'name': 'Turkish', 'native': 'Türkçe'},
    {'code': 'th', 'name': 'Thai', 'native': 'ไทย'},
    {'code': 'vi', 'name': 'Vietnamese', 'native': 'Tiếng Việt'},
    {'code': 'id', 'name': 'Indonesian', 'native': 'Bahasa Indonesia'},
    {'code': 'ms', 'name': 'Malay', 'native': 'Bahasa Melayu'},
    {'code': 'he', 'name': 'Hebrew', 'native': 'עברית'},
    {'code': 'el', 'name': 'Greek', 'native': 'Ελληνικά'},
    {'code': 'cs', 'name': 'Czech', 'native': 'Čeština'},
    {'code': 'hu', 'name': 'Hungarian', 'native': 'Magyar'},
    {'code': 'ro', 'name': 'Romanian', 'native': 'Română'},
    {'code': 'sk', 'name': 'Slovak', 'native': 'Slovenčina'},
    {'code': 'hr', 'name': 'Croatian', 'native': 'Hrvatski'},
    {'code': 'sl', 'name': 'Slovenian', 'native': 'Slovenščina'},
    {'code': 'et', 'name': 'Estonian', 'native': 'Eesti'},
    {'code': 'lv', 'name': 'Latvian', 'native': 'Latviešu'},
    {'code': 'lt', 'name': 'Lithuanian', 'native': 'Lietuvių'},
    {'code': 'bg', 'name': 'Bulgarian', 'native': 'Български'},
    {'code': 'mk', 'name': 'Macedonian', 'native': 'Македонски'},
    {'code': 'sr', 'name': 'Serbian', 'native': 'Српски'},
    {'code': 'uk', 'name': 'Ukrainian', 'native': 'Українська'},
    {'code': 'be', 'name': 'Belarusian', 'native': 'Беларуская'},
    {'code': 'ka', 'name': 'Georgian', 'native': 'ქართული'},
    {'code': 'hy', 'name': 'Armenian', 'native': 'Հայերեն'},
    {'code': 'az', 'name': 'Azerbaijani', 'native': 'Azərbaycan'},
    {'code': 'kk', 'name': 'Kazakh', 'native': 'Қазақ'},
    {'code': 'ky', 'name': 'Kyrgyz', 'native': 'Кыргызча'},
    {'code': 'uz', 'name': 'Uzbek', 'native': 'Oʻzbekcha'},
    {'code': 'tg', 'name': 'Tajik', 'native': 'Тоҷикӣ'},
    {'code': 'fa', 'name': 'Persian', 'native': 'فارسی'},
    {'code': 'ur', 'name': 'Urdu', 'native': 'اردو'},
    {'code': 'bn', 'name': 'Bengali', 'native': 'বাংলা'},
    {'code': 'ta', 'name': 'Tamil', 'native': 'தமிழ்'},
    {'code': 'te', 'name': 'Telugu', 'native': 'తెలుగు'},
    {'code': 'kn', 'name': 'Kannada', 'native': 'ಕನ್ನಡ'},
    {'code': 'ml', 'name': 'Malayalam', 'native': 'മലയാളം'},
    {'code': 'gu', 'name': 'Gujarati', 'native': 'ગુજરાતી'},
    {'code': 'pa', 'name': 'Punjabi', 'native': 'ਪੰਜਾਬੀ'},
    {'code': 'mr', 'name': 'Marathi', 'native': 'मराठी'},
    {'code': 'ne', 'name': 'Nepali', 'native': 'नेपाली'},
    {'code': 'si', 'name': 'Sinhala', 'native': 'සිංහල'},
    {'code': 'my', 'name': 'Burmese', 'native': 'မြန်မာ'},
    {'code': 'km', 'name': 'Khmer', 'native': 'ខ្មែរ'},
    {'code': 'lo', 'name': 'Lao', 'native': 'ລາວ'},
    {'code': 'mn', 'name': 'Mongolian', 'native': 'Монгол'},
    {'code': 'bo', 'name': 'Tibetan', 'native': 'བོད་ཡིག'},
    {'code': 'am', 'name': 'Amharic', 'native': 'አማርኛ'},
    {'code': 'sw', 'name': 'Swahili', 'native': 'Kiswahili'},
    {'code': 'zu', 'name': 'Zulu', 'native': 'isiZulu'},
    {'code': 'af', 'name': 'Afrikaans', 'native': 'Afrikaans'},
    {'code': 'is', 'name': 'Icelandic', 'native': 'Íslenska'},
    {'code': 'mt', 'name': 'Maltese', 'native': 'Malti'},
    {'code': 'cy', 'name': 'Welsh', 'native': 'Cymraeg'},
    {'code': 'ga', 'name': 'Irish', 'native': 'Gaeilge'},
    {'code': 'eu', 'name': 'Basque', 'native': 'Euskara'},
    {'code': 'ca', 'name': 'Catalan', 'native': 'Català'},
    {'code': 'gl', 'name': 'Galician', 'native': 'Galego'},
    {'code': 'br', 'name': 'Breton', 'native': 'Brezhoneg'},
    {'code': 'fy', 'name': 'Frisian', 'native': 'Frysk'},
    {'code': 'lb', 'name': 'Luxembourgish', 'native': 'Lëtzebuergesch'},
    {'code': 'rm', 'name': 'Romansh', 'native': 'Rumantsch'},
    {'code': 'sq', 'name': 'Albanian', 'native': 'Shqip'},
    {'code': 'bs', 'name': 'Bosnian', 'native': 'Bosanski'},
    {'code': 'me', 'name': 'Montenegrin', 'native': 'Crnogorski'},
    {'code': 'mk', 'name': 'Macedonian', 'native': 'Македонски'},
    {'code': 'sl', 'name': 'Slovenian', 'native': 'Slovenščina'},
  ];

  List<String> selectedLanguages = ['en'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadExistingData();
    _loadPrefilledData();
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

            // Payment Password
            TextFormField(
              controller: paymentPasswordController,
              decoration: InputDecoration(
                labelText: 'Payment Password',
                hintText: 'Enter 6-digit payment code',
                border: const OutlineInputBorder(),
                helperText: 'This will be used for payment verification',
                suffixIcon: IconButton(
                  icon: Icon(
                    showPaymentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showPaymentPassword = !showPaymentPassword;
                    });
                  },
                ),
              ),
              obscureText: !showPaymentPassword,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter payment password';
                }
                if (value.length != 6) {
                  return 'Payment password must be 6 digits';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Confirm Payment Password
            TextFormField(
              controller: confirmPaymentPasswordController,
              decoration: InputDecoration(
                labelText: 'Confirm Payment Password',
                hintText: 'Enter 6-digit payment code again',
                border: const OutlineInputBorder(),
                helperText: confirmPaymentPasswordController.text.isNotEmpty &&
                        confirmPaymentPasswordController.text !=
                            paymentPasswordController.text
                    ? 'Payment passwords do not match'
                    : null,
                helperMaxLines: 1,
                suffixIcon: IconButton(
                  icon: Icon(
                    showConfirmPaymentPassword
                        ? Icons.visibility
                        : Icons.visibility_off,
                  ),
                  onPressed: () {
                    setState(() {
                      showConfirmPaymentPassword = !showConfirmPaymentPassword;
                    });
                  },
                ),
              ),
              obscureText: !showConfirmPaymentPassword,
              keyboardType: TextInputType.number,
              maxLength: 6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              onChanged: (value) {
                setState(() {});
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm payment password';
                }
                if (value != paymentPasswordController.text) {
                  return 'Payment passwords do not match';
                }
                return null;
              },
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
}
