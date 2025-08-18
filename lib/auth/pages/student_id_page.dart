import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/config/app_config.dart';

class StudentIdPage extends StatefulWidget {
  const StudentIdPage({super.key});

  @override
  State<StudentIdPage> createState() => _StudentIdPageState();
}

class _StudentIdPageState extends State<StudentIdPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController studentNameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();

  File? _selectedImage;
  final ImagePicker _picker = ImagePicker();
  bool isLoading = false;
  bool hasAllData = false;

  @override
  void initState() {
    super.initState();
    _checkRegistrationData();
  }

  Future<void> _checkRegistrationData() async {
    final prefs = await SharedPreferences.getInstance();

    // 檢查是否有完整的註冊資料
    final hasBasicInfo = prefs.getString('signup_full_name') != null &&
        prefs.getString('signup_email') != null &&
        prefs.getString('signup_password') != null;

    final hasPaymentCode = prefs.getString('signup_payment_code') != null;

    setState(() {
      hasAllData = hasBasicInfo && hasPaymentCode;
    });

    if (!hasAllData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please complete the registration form first'),
          backgroundColor: Colors.orange,
        ),
      );
      context.go('/signup');
    }
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
            const Text(
              'Please upload your student ID card',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.onBackground,
              ),
            ),
            const SizedBox(height: 24),

            // School Name
            TextFormField(
              controller: schoolNameController,
              decoration: const InputDecoration(
                labelText: 'School Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.school),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your school name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Student Name
            TextFormField(
              controller: studentNameController,
              decoration: const InputDecoration(
                labelText: 'Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Student ID
            TextFormField(
              controller: studentIdController,
              decoration: const InputDecoration(
                labelText: 'Student ID',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.badge),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your student ID';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Image Upload Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _selectedImage != null
                      ? AppColors.primary
                      : AppColors.secondary,
                  width: 2,
                ),
              ),
              child: Column(
                children: [
                  if (_selectedImage != null) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        _selectedImage!,
                        height: 200,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _pickImage,
                          icon: const Icon(Icons.edit),
                          label: const Text('Change'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.secondary,
                            foregroundColor: AppColors.onSecondary,
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _removeImage,
                          icon: const Icon(Icons.delete),
                          label: const Text('Remove'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.error,
                            foregroundColor: AppColors.onError,
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    const Icon(
                      Icons.add_photo_alternate,
                      size: 80,
                      color: AppColors.secondary,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Upload Student ID Card',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tap to select an image from your gallery',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.onBackground,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload),
                      label: const Text('Select Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.onPrimary,
                      ),
                    ),
                  ],
                ],
              ),
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
                    : const Text('Submit', style: TextStyle(fontSize: 18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 80,
      );

      if (image != null) {
        setState(() {
          _selectedImage = File(image.path);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }

  void _removeImage() {
    setState(() {
      _selectedImage = null;
    });
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please upload your student ID card'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // 檢查是否有付款碼
    final prefs = await SharedPreferences.getInstance();
    final paymentCode = prefs.getString('signup_payment_code');
    if (paymentCode == null || paymentCode.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please set your payment code first'),
          backgroundColor: AppColors.error,
        ),
      );
      context.go('/signup/payment-code');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Get student ID data
      final studentIdData = {
        'email': prefs.getString('signup_email') ?? '',
        'school_name': schoolNameController.text,
        'student_name': studentNameController.text,
        'student_id': studentIdController.text,
      };

      // Upload student ID image
      final success = await _uploadStudentIdImage(studentIdData);

      if (success) {
        // Clear signup data from SharedPreferences
        await _clearSignupData();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Registration successful! Please wait for verification.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate to login page
        context.go('/login');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Registration failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _uploadStudentIdImage(Map<String, dynamic> studentIdData) async {
    try {
      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConfig.uploadStudentIdUrl),
      );

      // Add text fields
      studentIdData.forEach((key, value) {
        request.fields[key] = value.toString();
      });

      // Add image file
      if (_selectedImage != null) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'student_id_image',
            _selectedImage!.path,
          ),
        );
      }

      // Send request
      final response = await request.send();
      final responseData = await response.stream.bytesToString();
      final jsonResponse = jsonDecode(responseData);

      if (response.statusCode == 200 && jsonResponse['success']) {
        return true;
      } else {
        throw Exception(jsonResponse['message'] ?? 'Upload failed');
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  Future<void> _clearSignupData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('signup_full_name');
    await prefs.remove('signup_nickname');
    await prefs.remove('signup_gender');
    await prefs.remove('signup_email');
    await prefs.remove('signup_phone');
    await prefs.remove('signup_country');
    await prefs.remove('signup_address');
    await prefs.remove('signup_password');
    await prefs.remove('signup_date_of_birth');
    await prefs.remove('signup_payment_code');
    await prefs.remove('signup_is_permanent_address');
    await prefs.remove('signup_languages');
  }
}
