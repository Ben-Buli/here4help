import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:here4help/services/terms_service.dart';

class TermsConsentDialog extends StatefulWidget {
  final TermsContent terms;
  final Future<void> Function() onAccept;
  final VoidCallback onViewFullTerms;
  const TermsConsentDialog({
    super.key,
    required this.terms,
    required this.onAccept,
    required this.onViewFullTerms,
  });

  static Future<bool?> show(
    BuildContext context, {
    required TermsContent terms,
    required Future<void> Function() onAccept,
    required VoidCallback onViewFullTerms,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => TermsConsentDialog(
        terms: terms,
        onAccept: onAccept,
        onViewFullTerms: onViewFullTerms,
      ),
    );
  }

  @override
  State<TermsConsentDialog> createState() => _TermsConsentDialogState();
}

class _TermsConsentDialogState extends State<TermsConsentDialog> {
  bool _isSubmitting = false;
  bool _hasAgreed = false;
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mediaQuery = MediaQuery.of(context);
    final dialogTheme = theme.dialogTheme;
    final dialogColor =
        dialogTheme.backgroundColor ?? theme.colorScheme.surface;
    final dialogShape = dialogTheme.shape ??
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

    return Dialog(
      backgroundColor: dialogColor,
      shape: dialogShape,
      insetPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: mediaQuery.size.width - 16,
          maxHeight: mediaQuery.size.height * 0.9,
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.terms.title.isNotEmpty
                              ? widget.terms.title
                              : 'Updated Terms of Use',
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Version ${widget.terms.version}',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: theme.colorScheme.primary),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.all(16),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Html(data: widget.terms.content),
                        const SizedBox(height: 16),
                        TextButton.icon(
                          onPressed:
                              _isSubmitting ? null : widget.onViewFullTerms,
                          icon: const Icon(Icons.open_in_new, size: 18),
                          label: const Text('View Full Terms'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                value: _hasAgreed,
                onChanged: _isSubmitting
                    ? null
                    : (value) {
                        setState(() {
                          _hasAgreed = value ?? false;
                          _errorMessage = null;
                        });
                      },
                title: Wrap(
                  spacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      'I agree to the',
                      style: theme.textTheme.bodyMedium,
                    ),
                    Text(
                      'Terms of Use',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.primary,
                        decoration: TextDecoration.underline,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
              ],
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.pop(context, false),
                    child: const Text('Disagree'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: (_isSubmitting || !_hasAgreed)
                        ? null
                        : () async {
                            setState(() {
                              _isSubmitting = true;
                              _errorMessage = null;
                            });
                            try {
                              await widget.onAccept();
                              if (context.mounted) {
                                Navigator.of(context).pop(true);
                              }
                            } catch (_) {
                              setState(() {
                                _isSubmitting = false;
                                _errorMessage =
                                    'Failed to record acceptance. Please try again.';
                              });
                            }
                          },
                    child: _isSubmitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Agree'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
