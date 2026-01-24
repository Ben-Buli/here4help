class AuthException implements Exception {
  final String code;
  final String message;
  final Map<String, dynamic>? data;

  const AuthException({
    required this.code,
    required this.message,
    this.data,
  });

  bool get isAccountDeleted => code == 'E2009';

  bool get isAccountSuspended => code == 'E2008';

  bool get isDeletedOrDisabled =>
      isAccountDeleted || isAccountSuspended || _messageHintsDeleted(message);

  @override
  String toString() => message;

  static bool _messageHintsDeleted(String value) {
    final normalized = value.toLowerCase();
    return normalized.contains('account_deleted') ||
        normalized.contains('account_disabled') ||
        normalized.contains('has been deleted and cannot be used') ||
        normalized.contains('account has been deleted and cannot be used') ||
        normalized.contains('account deleted');
  }
}
