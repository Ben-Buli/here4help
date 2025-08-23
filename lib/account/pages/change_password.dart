import 'package:flutter/material.dart';
import 'package:here4help/services/api/password_api.dart';

class ChangePassword extends StatefulWidget {
  const ChangePassword({
    super.key,
    required this.onCancel,
    required this.onDone,
  });

  final VoidCallback onCancel;
  final VoidCallback onDone;

  @override
  State<ChangePassword> createState() => _ChangePasswordState();
}

class _ChangePasswordState extends State<ChangePassword> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;
  bool _submitting = false;

  String? _matchError; // new vs confirm 即時錯誤
  String? _apiError; // API 錯誤訊息

  @override
  void initState() {
    super.initState();
    _newCtrl.addListener(_validateMatch);
    _confirmCtrl.addListener(_validateMatch);
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _validateMatch() {
    final newPwd = _newCtrl.text;
    final confirm = _confirmCtrl.text;
    String? err;
    if (confirm.isNotEmpty && newPwd != confirm) {
      err = 'Passwords do not match';
    }
    setState(() => _matchError = err);
  }

  String? _validateCurrent(String? v) {
    if ((v ?? '').isEmpty) return 'Please enter your current password';
    return null;
  }

  String? _validateNew(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Please enter a new password';
    if (s.length < 8) return 'At least 8 characters';

    // 檢查密碼強度（與後端一致）
    if (!RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(s)) {
      return 'Password must contain at least one uppercase letter, one lowercase letter, and one number';
    }

    return null;
  }

  String? _validateConfirm(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Please re-enter the new password';
    if (s != _newCtrl.text) return 'Passwords do not match';
    return null;
  }

  bool get _canSubmit {
    return !_submitting &&
        _currentCtrl.text.isNotEmpty &&
        _newCtrl.text.isNotEmpty &&
        _confirmCtrl.text.isNotEmpty &&
        _matchError == null &&
        _newCtrl.text.length >= 8 &&
        RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)').hasMatch(_newCtrl.text);
  }

  Future<void> _handleSubmit() async {
    setState(() => _apiError = null);
    final formOk = _formKey.currentState?.validate() ?? false;
    if (!formOk || _matchError != null) return;

    setState(() => _submitting = true);
    try {
      await PasswordApi.changePassword(
        currentPassword: _currentCtrl.text,
        newPassword: _newCtrl.text,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Password updated successfully',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
            ),
          ),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
      );

      widget.onDone();
    } catch (e) {
      setState(() => _apiError = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 原始密碼
          TextFormField(
            controller: _currentCtrl,
            obscureText: _hideCurrent,
            decoration: InputDecoration(
              labelText: 'Current password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hideCurrent = !_hideCurrent),
                icon: Icon(
                    _hideCurrent ? Icons.visibility : Icons.visibility_off),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: _validateCurrent,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // 新密碼
          TextFormField(
            controller: _newCtrl,
            obscureText: _hideNew,
            decoration: InputDecoration(
              labelText: 'New password',
              helperText:
                  'Use 8+ characters with uppercase, lowercase, and number.',
              prefixIcon: const Icon(Icons.lock_reset),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hideNew = !_hideNew),
                icon: Icon(_hideNew ? Icons.visibility : Icons.visibility_off),
              ),
              border: const OutlineInputBorder(),
            ),
            validator: _validateNew,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 12),

          // 確認新密碼
          TextFormField(
            controller: _confirmCtrl,
            obscureText: _hideConfirm,
            decoration: InputDecoration(
              labelText: 'Confirm new password',
              prefixIcon: const Icon(Icons.lock),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _hideConfirm = !_hideConfirm),
                icon: Icon(
                    _hideConfirm ? Icons.visibility : Icons.visibility_off),
              ),
              border: const OutlineInputBorder(),
              errorText: _matchError,
            ),
            validator: _validateConfirm,
            onChanged: (_) => setState(() {}),
          ),

          if (_apiError != null) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: scheme.errorContainer,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: scheme.error),
              ),
              child: Text(
                _apiError!,
                style: TextStyle(color: scheme.onErrorContainer),
              ),
            ),
          ],

          const SizedBox(height: 16),
          Row(
            children: [
              OutlinedButton(
                onPressed: _submitting ? null : widget.onCancel,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _canSubmit ? _handleSubmit : null,
                icon: _submitting
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(scheme.onPrimary),
                        ),
                      )
                    : const Icon(Icons.check),
                label: const Text('Update password'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
