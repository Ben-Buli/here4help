import 'package:flutter/material.dart';
import '../../services/api/notification_api.dart';
import '../../constants/app_colors.dart';

class NotificationPreferencesPage extends StatefulWidget {
  const NotificationPreferencesPage({Key? key}) : super(key: key);

  @override
  State<NotificationPreferencesPage> createState() =>
      _NotificationPreferencesPageState();
}

class _NotificationPreferencesPageState
    extends State<NotificationPreferencesPage> {
  final NotificationApi _notificationApi = NotificationApi();

  bool _isLoading = true;
  bool _isSaving = false;

  // 全域設定
  bool _pushEnabled = true;
  bool _inAppEnabled = true;
  bool _emailEnabled = true;
  bool _smsEnabled = false;

  // 靜音時段
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  Set<int> _quietDays = {};

  // 分類偏好
  Map<String, Map<String, Map<String, bool>>> _categoryPreferences = {};
  Map<String, List<Map<String, dynamic>>> _availableTemplates = {};

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      setState(() => _isLoading = true);

      final result = await _notificationApi.getPreferences();

      if (result['success']) {
        final preferences = result['data']['preferences'];
        final templates = result['data']['available_templates'];

        setState(() {
          _pushEnabled = preferences['push_enabled'] ?? true;
          _inAppEnabled = preferences['in_app_enabled'] ?? true;
          _emailEnabled = preferences['email_enabled'] ?? true;
          _smsEnabled = preferences['sms_enabled'] ?? false;

          // 解析靜音時段
          if (preferences['quiet_hours_start'] != null) {
            final parts = preferences['quiet_hours_start'].split(':');
            _quietStart = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }

          if (preferences['quiet_hours_end'] != null) {
            final parts = preferences['quiet_hours_end'].split(':');
            _quietEnd = TimeOfDay(
              hour: int.parse(parts[0]),
              minute: int.parse(parts[1]),
            );
          }

          _quietDays = Set<int>.from(preferences['quiet_days'] ?? []);

          // 解析分類偏好
          _categoryPreferences = {
            'task': Map<String, Map<String, bool>>.from(
                (preferences['task_preferences'] ?? {}).map((key, value) =>
                    MapEntry(key, Map<String, bool>.from(value)))),
            'chat': Map<String, Map<String, bool>>.from(
                (preferences['chat_preferences'] ?? {}).map((key, value) =>
                    MapEntry(key, Map<String, bool>.from(value)))),
            'support': Map<String, Map<String, bool>>.from(
                (preferences['support_preferences'] ?? {}).map((key, value) =>
                    MapEntry(key, Map<String, bool>.from(value)))),
            'admin': Map<String, Map<String, bool>>.from(
                (preferences['admin_preferences'] ?? {}).map((key, value) =>
                    MapEntry(key, Map<String, bool>.from(value)))),
          };

          _availableTemplates =
              Map<String, List<Map<String, dynamic>>>.from(templates);
        });
      } else {
        _showError('載入通知偏好失敗: ${result['message']}');
      }
    } catch (e) {
      _showError('載入通知偏好失敗: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _savePreferences() async {
    try {
      setState(() => _isSaving = true);

      final data = {
        'push_enabled': _pushEnabled,
        'in_app_enabled': _inAppEnabled,
        'email_enabled': _emailEnabled,
        'sms_enabled': _smsEnabled,
        'quiet_hours_start': _quietStart != null
            ? '${_quietStart!.hour.toString().padLeft(2, '0')}:${_quietStart!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'quiet_hours_end': _quietEnd != null
            ? '${_quietEnd!.hour.toString().padLeft(2, '0')}:${_quietEnd!.minute.toString().padLeft(2, '0')}:00'
            : null,
        'quiet_days': _quietDays.toList(),
        'task_preferences': _categoryPreferences['task'],
        'chat_preferences': _categoryPreferences['chat'],
        'support_preferences': _categoryPreferences['support'],
        'admin_preferences': _categoryPreferences['admin'],
      };

      final result = await _notificationApi.updatePreferences(data);

      if (result['success']) {
        _showSuccess('通知偏好已儲存');
      } else {
        _showError('儲存失敗: ${result['message']}');
      }
    } catch (e) {
      _showError('儲存失敗: $e');
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.error,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('通知設定'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (!_isLoading)
            TextButton(
              onPressed: _isSaving ? null : _savePreferences,
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      '儲存',
                      style: TextStyle(color: Colors.white),
                    ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildGlobalSettings(),
                  const SizedBox(height: 24),
                  _buildQuietHours(),
                  const SizedBox(height: 24),
                  _buildCategoryPreferences(),
                ],
              ),
            ),
    );
  }

  Widget _buildGlobalSettings() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '全域設定',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              title: const Text('推播通知'),
              subtitle: const Text('接收手機推播通知'),
              value: _pushEnabled,
              onChanged: (value) => setState(() => _pushEnabled = value),
              activeColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('站內通知'),
              subtitle: const Text('在應用程式內顯示通知'),
              value: _inAppEnabled,
              onChanged: (value) => setState(() => _inAppEnabled = value),
              activeColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('Email 通知'),
              subtitle: const Text('接收電子郵件通知'),
              value: _emailEnabled,
              onChanged: (value) => setState(() => _emailEnabled = value),
              activeColor: AppColors.primary,
            ),
            SwitchListTile(
              title: const Text('簡訊通知'),
              subtitle: const Text('接收簡訊通知（需額外設定）'),
              value: _smsEnabled,
              onChanged: (value) => setState(() => _smsEnabled = value),
              activeColor: AppColors.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuietHours() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '靜音時段',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    title: const Text('開始時間'),
                    subtitle: Text(_quietStart?.format(context) ?? '未設定'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    title: const Text('結束時間'),
                    subtitle: Text(_quietEnd?.format(context) ?? '未設定'),
                    trailing: const Icon(Icons.access_time),
                    onTap: () => _selectTime(false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('靜音日期'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (int i = 1; i <= 7; i++)
                  FilterChip(
                    label: Text(_getDayName(i)),
                    selected: _quietDays.contains(i),
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _quietDays.add(i);
                        } else {
                          _quietDays.remove(i);
                        }
                      });
                    },
                    selectedColor: AppColors.primary.withValues(alpha: 0.3),
                  ),
              ],
            ),
            if (_quietStart != null ||
                _quietEnd != null ||
                _quietDays.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    setState(() {
                      _quietStart = null;
                      _quietEnd = null;
                      _quietDays.clear();
                    });
                  },
                  child: const Text('清除靜音設定'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryPreferences() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '分類偏好',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 16),
        for (final category in ['task', 'chat', 'support', 'admin'])
          if (_availableTemplates[category]?.isNotEmpty == true)
            _buildCategoryCard(category),
      ],
    );
  }

  Widget _buildCategoryCard(String category) {
    final categoryName = {
          'task': '任務通知',
          'chat': '聊天通知',
          'support': '客服通知',
          'admin': '管理通知',
        }[category] ??
        category;

    final templates = _availableTemplates[category] ?? [];

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              categoryName,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 16),
            for (final template in templates)
              _buildTemplatePreferences(category, template),
          ],
        ),
      ),
    );
  }

  Widget _buildTemplatePreferences(
      String category, Map<String, dynamic> template) {
    final templateKey = template['template_key'] as String;
    final templateName = template['name'] as String;
    final description = template['description'] as String?;

    // 從 template_key 中提取事件動作
    final eventAction = templateKey.replaceFirst('${category}_', '');

    final preferences = _categoryPreferences[category]?[eventAction] ?? {};

    return ExpansionTile(
      title: Text(templateName),
      subtitle: description != null ? Text(description) : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              if (template['supports_push'] == true)
                SwitchListTile(
                  title: const Text('推播'),
                  value: preferences['push'] ?? true,
                  onChanged: (value) => _updateCategoryPreference(
                      category, eventAction, 'push', value),
                  dense: true,
                ),
              if (template['supports_in_app'] == true)
                SwitchListTile(
                  title: const Text('站內'),
                  value: preferences['in_app'] ?? true,
                  onChanged: (value) => _updateCategoryPreference(
                      category, eventAction, 'in_app', value),
                  dense: true,
                ),
              if (template['supports_email'] == true)
                SwitchListTile(
                  title: const Text('Email'),
                  value: preferences['email'] ?? false,
                  onChanged: (value) => _updateCategoryPreference(
                      category, eventAction, 'email', value),
                  dense: true,
                ),
              if (template['supports_sms'] == true)
                SwitchListTile(
                  title: const Text('簡訊'),
                  value: preferences['sms'] ?? false,
                  onChanged: (value) => _updateCategoryPreference(
                      category, eventAction, 'sms', value),
                  dense: true,
                ),
            ],
          ),
        ),
      ],
    );
  }

  void _updateCategoryPreference(
      String category, String eventAction, String type, bool value) {
    setState(() {
      _categoryPreferences[category] ??= {};
      _categoryPreferences[category]![eventAction] ??= {};
      _categoryPreferences[category]![eventAction]![type] = value;
    });
  }

  Future<void> _selectTime(bool isStart) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: (isStart ? _quietStart : _quietEnd) ?? TimeOfDay.now(),
    );

    if (picked != null) {
      setState(() {
        if (isStart) {
          _quietStart = picked;
        } else {
          _quietEnd = picked;
        }
      });
    }
  }

  String _getDayName(int day) {
    const dayNames = ['一', '二', '三', '四', '五', '六', '日'];
    return dayNames[day - 1];
  }
}
