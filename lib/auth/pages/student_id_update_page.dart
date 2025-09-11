import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:here4help/constants/app_colors.dart';
import 'package:here4help/config/app_config.dart';
import 'package:here4help/services/media/cross_platform_image_service.dart';
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/auth/services/auth_service.dart';

class StudentIdUpdatePage extends StatefulWidget {
  final Map<String, dynamic>? rejectedData;

  const StudentIdUpdatePage({
    super.key,
    this.rejectedData,
  });

  @override
  State<StudentIdUpdatePage> createState() => _StudentIdUpdatePageState();
}

class _StudentIdUpdatePageState extends State<StudentIdUpdatePage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController schoolNameController = TextEditingController();
  final TextEditingController studentNameController = TextEditingController();
  final TextEditingController studentIdController = TextEditingController();

  ImageResult? _selectedImage;
  final _imageService = CrossPlatformImageService();
  bool isLoading = false;
  String? _rejectionReason;

  @override
  void initState() {
    super.initState();
    _initializeFormData();
  }

  Future<void> _initializeFormData() async {
    if (widget.rejectedData != null) {
      try {
        setState(() {
          _rejectionReason =
              widget.rejectedData!['verification_notes'] as String?;
          schoolNameController.text = widget.rejectedData!['school_name'] ?? '';
          studentNameController.text =
              widget.rejectedData!['student_name'] ?? '';
          studentIdController.text = widget.rejectedData!['student_id'] ?? '';
        });

        debugPrint('✅ 學生證更新頁面載入被拒絕資料: $_rejectionReason');
      } catch (e) {
        debugPrint('⚠️ 載入被拒絕資料時發生錯誤: $e');
        // 即使載入失敗，也允許用戶繼續使用頁面
      }
    } else {
      debugPrint('ℹ️ 沒有被拒絕的資料，用戶可以重新上傳學生證');
    }
  }

  @override
  void dispose() {
    schoolNameController.dispose();
    studentNameController.dispose();
    studentIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 頁面標題和說明
                const Text(
                  'Update Your Student ID Card',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Please update your student ID information and re-upload your student ID card.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onBackground,
                  ),
                ),
                const SizedBox(height: 24),

                // 顯示拒絕原因（如果有）
                if (_rejectionReason != null) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.error_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Previous Rejection Reason',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[800],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _rejectionReason!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.red[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

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
                          child: Image(
                            image: _imageService
                                .createImageProvider(_selectedImage!),
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
                              onPressed: _showImageSourceDialog,
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
                          'Upload Updated Student ID Card',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.onBackground,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Please upload a clear photo of your student ID card',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.onBackground,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _showImageSourceDialog,
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
                        : const Text('Update Student ID',
                            style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showImageSourceDialog() async {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt),
                title: const Text('Take Photo'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromCamera();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Choose from Gallery'),
                onTap: () {
                  Navigator.pop(context);
                  _pickFromGallery();
                },
              ),
              ListTile(
                leading: const Icon(Icons.cancel),
                title: const Text('Cancel'),
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _pickFromCamera() async {
    try {
      final image = await _imageService.pickFromCamera(
        config: ImageValidationConfig.studentId,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇相機圖片失敗: $e')),
      );
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final image = await _imageService.pickFromGallery(
        config: ImageValidationConfig.studentId,
      );

      if (image != null) {
        setState(() {
          _selectedImage = image;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('選擇相簿圖片失敗: $e')),
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

    setState(() {
      isLoading = true;
    });

    try {
      final userService = context.read<UserService>();
      final user = userService.currentUser;

      if (user?.id == null) {
        throw Exception('User not found. Please login again.');
      }

      // 🔧 新增：驗證用戶資料的完整性
      debugPrint(
          '🔍 驗證當前用戶: ID=${user!.id}, Name=${user.name}, Email=${user.email}');

      // Get student ID data for update
      final studentIdData = {
        'user_id': user.id.toString(),
        'school_name': schoolNameController.text,
        'student_name': studentNameController.text,
        'student_id': studentIdController.text,
        'is_update': 'true', // 標識這是更新操作
        'update_reason': 'rejected_verification', // 更新原因
      };

      debugPrint('📤 準備更新學生證資料 - User ID: ${user.id}');

      // Upload updated student ID image
      final success = await _uploadUpdatedStudentIdImage(studentIdData);

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Student ID updated successfully! Please wait for re-verification.'),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back to home page
        context.go('/home');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Update failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<bool> _uploadUpdatedStudentIdImage(
      Map<String, dynamic> studentIdData) async {
    try {
      if (_selectedImage == null) {
        throw Exception('No image selected');
      }

      // 使用跨平台圖片服務上傳，API 會自動檢測是更新還是新建
      final result = await _imageService.uploadImage(
        image: _selectedImage!,
        uploadUrl: AppConfig.uploadStudentIdUrl, // 同一個端點處理新建和更新
        token: await AuthService.getToken() ?? '',
        fieldName: 'student_id_image',
        additionalFields:
            studentIdData.map((key, value) => MapEntry(key, value.toString())),
      );

      return result['success'] == true;
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
