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
import 'package:here4help/auth/services/user_service.dart';
import 'package:here4help/task/services/university_service.dart'; // 使用 UniversityService
import 'package:here4help/task/services/language_service.dart'; // 使用 LanguageService
import 'package:here4help/services/theme_service.dart';
import 'package:here4help/widgets/theme_aware_components.dart';
import 'package:here4help/constants/app_colors.dart';

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

  final String _taskDescription = '';

  LatLng? _selectedLocation = const LatLng(25.0208, 121.5418);
  String _locationLabel = 'NCCU';

  /// 搜尋地點的控制器
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

    /// 初始化表單欄位
    _titleController.text = 'Opening Bank Account (Demo)';
    // _taskDescription =
    //     'Help me to open a bank account in Taiwan. I am a foreigner and need assistance with the process.';
    // _taskDescriptionController = TextEditingController();
    // _taskDescriptionController.text = _taskDescription;
    final formatter = NumberFormat('#,##0', 'en_US'); // 格式化三位數數字
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
      }
    });

    // 載入大學列表
    _loadUniversities();
    // 載入語言列表
    _loadLanguages();
  }

  Future<void> _loadUniversities() async {
    try {
      final universities = await UniversityService.getUniversities();
      setState(() {
        _universities = universities;
      });
    } catch (e) {
      // 如果無法載入大學列表，使用預設列表
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
      // 如果無法載入語言列表，使用預設列表
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
    setState(() {
      _applicationQuestions.removeAt(index);
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // 點擊空白處收鍵盤
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Personal Data (readonly)
            _buildLabel('Personal Data', required: false),
            const SizedBox(height: 4),
            Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.black)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
              child: Text(
                Provider.of<UserService>(context, listen: false)
                        .currentUser
                        ?.name ??
                    'Unknow Poster',
                style: const TextStyle(fontSize: 16),
              ),
            ),
            const SizedBox(height: 12),

            // Task Title
            _buildLabel('Task Title',
                required: true,
                isError: _errorFields.contains(kTaskTitleField)),
            const SizedBox(height: 4),
            TextFormField(
              controller: _titleController,
              decoration: InputDecoration(
                hintText: 'Enter task title',
                hintStyle: const TextStyle(color: Colors.grey),
                border: const UnderlineInputBorder(),
                filled: _errorFields.contains(kTaskTitleField),
                fillColor: _errorFields.contains(kTaskTitleField)
                    ? Colors.pink.shade50
                    : null,
              ),
              onChanged: (_) {
                if (_errorFields.contains(kTaskTitleField)) {
                  setState(() => _errorFields.remove(kTaskTitleField));
                }
              },
            ),
            const SizedBox(height: 12),

            // Task Description
            // _buildLabel('Task Description',
            //     required: true,
            //     isError: _errorFields.contains('Task Description')),
            // const SizedBox(height: 4),
            // TextFormField(
            //   controller: _taskDescriptionController,
            //   maxLength: 100,
            //   maxLines: 3,
            //   decoration: InputDecoration(
            //     hintText: 'Please describe the task in detail.',
            //     hintStyle: const TextStyle(color: Colors.grey),
            //     border: const UnderlineInputBorder(),
            //     filled: _errorFields.contains('Task Description'),
            //     fillColor: _errorFields.contains('Task Description')
            //         ? Colors.pink.shade50
            //         : null,
            //   ),
            // ),
            // const SizedBox(height: 12),

            // Salary
            _buildLabel('Reward',
                required: true, isError: _errorFields.contains('Salary')),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: const BoxDecoration(
                      border: Border(bottom: BorderSide(color: Colors.black)),
                    ),
                    child: Row(
                      children: [
                        const Text(
                          '💰 | ',
                          style: TextStyle(
                            fontSize: 20,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            controller: _salaryController,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly
                            ],
                            decoration: InputDecoration(
                              hintText: '0',
                              hintStyle: const TextStyle(
                                  color: Color.fromARGB(255, 0, 0, 0)),
                              border: InputBorder.none,
                              filled: _errorFields.contains(kSalaryField),
                              fillColor: _errorFields.contains(kSalaryField)
                                  ? Colors.pink.shade50
                                  : null,
                            ),
                            onChanged: (value) {
                              final formatter = NumberFormat('#,##0', 'en_US');
                              // 移除非數字
                              final digits =
                                  value.replaceAll(RegExp(r'[^\d]'), '');
                              final number = int.tryParse(digits) ?? 0;
                              final formatted = formatter.format(number);
                              _salaryController.value = TextEditingValue(
                                text: formatted,
                                selection: TextSelection.collapsed(
                                    offset: formatted.length),
                              );
                              if (_errorFields.contains(kSalaryField)) {
                                setState(
                                    () => _errorFields.remove(kSalaryField));
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Location (popup map)
            _buildLabel('Location', required: false),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _showLocationPicker(context),
                    child: Container(
                      decoration: const BoxDecoration(
                        border: Border(bottom: BorderSide(color: Colors.black)),
                      ),
                      padding: const EdgeInsets.symmetric(
                          vertical: 14, horizontal: 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              // ↓↓↓ 新增：如果地點名稱在大學清單中，顯示縮寫
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
                                    : Colors.grey,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const Icon(Icons.chevron_right),
                        ],
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.my_location),
                  tooltip: 'Use current location',
                  onPressed: _useCurrentLocation,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Time (date picker)
            _buildLabel('Time',
                required: true, isError: _errorFields.contains('Time')),
            const SizedBox(height: 4),
            TextFormField(
              readOnly: true,
              controller: TextEditingController(
                text: _taskDate != null
                    ? _taskDate!.toLocal().toString().split(' ')[0]
                    : '',
              ),
              decoration: InputDecoration(
                hintText: 'Select date',
                hintStyle: const TextStyle(color: Colors.grey),
                border: const UnderlineInputBorder(),
                filled: _errorFields.contains('Time'),
                fillColor:
                    _errorFields.contains('Time') ? Colors.pink.shade50 : null,
                suffixIcon: const Icon(Icons.calendar_today),
              ),
              onTap: () async {
                _errorFields.remove('Time');
                _selectDate(context, (picked) {
                  setState(() => _taskDate = picked);
                });
              },
            ),
            const SizedBox(height: 12),

            // Posting period (two date pickers)
            _buildLabel('Posting period',
                required: true,
                isError: _errorFields.contains('Posting period')),
            const SizedBox(height: 4),
            Row(
              children: [
                // Start date
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _periodStart != null
                          ? _periodStart!.toLocal().toString().substring(0, 16)
                          : '',
                    ),
                    decoration: InputDecoration(
                      hintText: 'Start date (yyyy-mm-dd hh:mm)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: const UnderlineInputBorder(),
                      filled: _errorFields.contains('Posting period'),
                      fillColor: _errorFields.contains('Posting period')
                          ? Colors.pink.shade50
                          : null,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      _errorFields.remove('Posting period');
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
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 6),
                  child: Text('-',
                      style: TextStyle(fontSize: 16, color: Colors.black54)),
                ),
                // End date
                Expanded(
                  child: TextFormField(
                    readOnly: true,
                    controller: TextEditingController(
                      text: _periodEnd != null
                          ? _periodEnd!.toLocal().toString().substring(0, 16)
                          : '',
                    ),
                    decoration: InputDecoration(
                      hintText: 'End date (yyyy-mm-dd hh:mm)',
                      hintStyle: const TextStyle(color: Colors.grey),
                      border: const UnderlineInputBorder(),
                      filled: _errorFields.contains('Posting period'),
                      fillColor: _errorFields.contains('Posting period')
                          ? Colors.pink.shade50
                          : null,
                      suffixIcon: const Icon(Icons.calendar_today),
                    ),
                    onTap: () async {
                      _errorFields.remove('Posting period');
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
            const SizedBox(height: 12),

            // Application Question (optional)
            Column(
              children: List.generate(_applicationQuestions.length, (index) {
                // Format the index as two digits (01, 02, ...)
                final labelNumber = (index + 1).toString().padLeft(2, '0');
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Application Question - $labelNumber',
                          required: true),
                      const SizedBox(height: 4),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: _applicationQuestions[index],
                              decoration: InputDecoration(
                                hintText: 'Enter custom question',
                                hintStyle: const TextStyle(color: Colors.grey),
                                border: const UnderlineInputBorder(),
                                filled: _errorFields
                                    .contains('ApplicationQuestion$index'),
                                fillColor: _errorFields
                                        .contains('ApplicationQuestion$index')
                                    ? Colors.pink.shade50
                                    : null,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _applicationQuestions[index] = value;
                                });
                              },
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.grey),
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
                        ],
                      ),
                    ],
                  ),
                );
              }),
            ),
            if (_applicationQuestions.length < 3)
              Align(
                alignment: Alignment.centerLeft,
                child: ElevatedButton(
                  onPressed: _addApplicationQuestion,
                  child: const Text('Add an Application Question'),
                ),
              ),

            const SizedBox(height: 24),

            // Required Languages (optional)
            _buildLabel('Language Requirement',
                required: true,
                isError: _errorFields.contains('Language Requirement')),
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () async {
                final result = await showModalBottomSheet<List<String>>(
                  context: context,
                  isScrollControlled: true,
                  builder: (context) {
                    List<String> tempSelected = List.from(_selectedLanguages);
                    TextEditingController searchController =
                        TextEditingController();
                    return StatefulBuilder(
                      builder: (context, setState) {
                        return Padding(
                          padding: MediaQuery.of(context).viewInsets,
                          child: SizedBox(
                            height: 400,
                            child: Column(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: TextField(
                                    controller: searchController,
                                    decoration: const InputDecoration(
                                      hintText: 'Search language',
                                      prefixIcon: Icon(Icons.search),
                                    ),
                                    onChanged: (_) => setState(() {}),
                                  ),
                                ),
                                Expanded(
                                  child: StatefulBuilder(
                                    builder: (context, setState) {
                                      List<Map<String, dynamic>> filteredList =
                                          _languages
                                              .where((lang) =>
                                                  (lang['native'] ?? '')
                                                      .toLowerCase()
                                                      .contains(searchController
                                                          .text
                                                          .toLowerCase()))
                                              .toList();

                                      // 將已選擇的語言優先排序。
                                      filteredList.sort((a, b) {
                                        bool aSelected =
                                            tempSelected.contains(a['code']);
                                        bool bSelected =
                                            tempSelected.contains(b['code']);
                                        if (aSelected && !bSelected) return -1;
                                        if (!aSelected && bSelected) return 1;
                                        return (a['native'] ?? '')
                                            .compareTo(b['native'] ?? '');
                                      });

                                      return ListView(
                                        children: filteredList.map((lang) {
                                          final isSelected = tempSelected
                                              .contains(lang['code']);
                                          return CheckboxListTile(
                                            value: isSelected,
                                            title: Text(lang['native'] ??
                                                lang['name'] ??
                                                ''),
                                            onChanged: (checked) {
                                              setState(() {
                                                if (checked == true) {
                                                  tempSelected
                                                      .add(lang['code']);
                                                } else {
                                                  tempSelected
                                                      .remove(lang['code']);
                                                }
                                              });
                                            },
                                          );
                                        }).toList(),
                                      );
                                    },
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    OutlinedButton(
                                      style: TextButton.styleFrom(
                                        foregroundColor: Colors.redAccent,
                                        side: const BorderSide(
                                            color: Colors.redAccent),
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, null),
                                      child: const Text('Cancel'),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton(
                                      style: TextButton.styleFrom(
                                        backgroundColor:
                                            const Color(0xFF3A85FF),
                                        foregroundColor: Colors.white,
                                      ),
                                      onPressed: () =>
                                          Navigator.pop(context, tempSelected),
                                      child: const Text('Confirm'),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                              ],
                            ),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: _selectedLanguages.isEmpty
                    ? const Text(
                        'Preferred language(s) for the task taker',
                        style: TextStyle(color: Colors.grey),
                      )
                    : Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: _selectedLanguages.map((code) {
                          final language = _languages.firstWhere(
                            (lang) => lang['code'] == code,
                            orElse: () => {'native': code},
                          );
                          return Chip(
                            label: Text(language['native'] ?? code),
                          );
                        }).toList(),
                      ),
              ),
            ),

            const SizedBox(height: 24),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning, color: Colors.red, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: RichText(
                    text: const TextSpan(
                      style: TextStyle(fontSize: 12, color: Colors.black87),
                      children: [
                        TextSpan(text: 'Please abide by '),
                        TextSpan(
                          text: 'The platform regulations',
                          style: TextStyle(
                              color: AppColors.primary,
                              decoration: TextDecoration.underline),
                        ),
                        TextSpan(
                          text:
                              ' and do not post false fraudulent information. Violators will be held legally responsible.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            LayoutBuilder(
              builder: (context, constraints) {
                double maxWidth = 500;
                bool isMobile = constraints.maxWidth < 600;
                return Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: isMobile ? double.infinity : maxWidth,
                      ),
                      child: SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            final user =
                                Provider.of<UserService>(context, listen: false)
                                    .currentUser;
                            final userName = user?.name ?? 'Unknown Poster';
                            final data = {
                              'title': _titleController.text.trim(),
                              'salary': _salaryController.text.trim(),
                              'location': _locationLabel.isNotEmpty
                                  ? _locationLabel
                                  : 'N/A',
                              'task_date': _taskDate != null
                                  ? _taskDate!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                              'periodStart': _periodStart != null
                                  ? _periodStart!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                              'periodEnd': _periodEnd != null
                                  ? _periodEnd!
                                      .toLocal()
                                      .toString()
                                      .split(' ')[0]
                                  : 'N/A',
                              'application_question':
                                  _applicationQuestions.join(' | '),
                              'creator_name': userName,
                              'avatar_url': user?.avatar_url ?? '',
                              'language_requirement':
                                  _selectedLanguages.join(','),
                              'creator_id': user?.id ?? 'Unknown',
                              // 'description': _taskDescriptionController.text
                              //     .trim(), // 添加 description 值
                            };

                            // 檢查必填欄位
                            final requiredFields = {
                              kTaskTitleField: data['title'],
                              // 'Task Description':
                              //     _taskDescriptionController.text.trim(),
                              kSalaryField: data['salary'],
                              kTimeField: data['task_date'],
                              kPostingPeriodField:
                                  data['periodStart'] != 'N/A' &&
                                      data['periodEnd'] != 'N/A'
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

                            // 檢查每個 Application Question 是否為空
                            for (int i = 0;
                                i < _applicationQuestions.length;
                                i++) {
                              if (_applicationQuestions[i].trim().isEmpty) {
                                _errorFields.add('ApplicationQuestion$i');
                              }
                            }

                            if (_errorFields.isNotEmpty) {
                              setState(() {});
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please fill in all required fields.'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }

                            // 傳遞資料到預覽頁面
                            context.push('/task/create/preview', extra: data);
                          },
                          child: const Text(
                            'Preview and save',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String title,
      {bool required = false, bool isError = false}) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 12,
          color: isError ? Colors.red : Colors.grey,
        ),
        children: [
          TextSpan(text: title),
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Colors.red),
            ),
        ],
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

  void _showLocationPicker(BuildContext context) {
    LatLng center = _selectedLocation ?? const LatLng(25.0173, 121.5415);

    showDialog(
      context: context,
      builder: (context) {
        bool hasSearched = false;
        bool dialogActive = true; // 新增 flag
        return StatefulBuilder(
          builder: (context, setState) {
            // 只在第一次 build 時自動查詢
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
                    dialogActive = false; // 關閉 Dialog 時設為 false
                    Navigator.pop(context);
                  },
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    dialogActive = false;
                    // 關閉 Dialog 並回傳資料
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
}

String _extractLandmarkName(String displayName) {
  return displayName.split(',').first.trim();
}

Future<String> _reverseGeocode(LatLng point) async {
  // 使用 Nominatim API 反向地理編碼, 預設英語地圖
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

// 新增搜尋功能
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
