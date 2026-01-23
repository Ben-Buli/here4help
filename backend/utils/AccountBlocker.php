<?php
/**
 * Account blocking helpers for re-registration control.
 */

class AccountBlocker
{
    private static function tableExists(PDO $pdo, string $table): bool
    {
        $stmt = $pdo->prepare(
            "SELECT COUNT(*) AS c
             FROM INFORMATION_SCHEMA.TABLES
             WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = ?"
        );
        $stmt->execute([$table]);
        $row = $stmt->fetch(PDO::FETCH_ASSOC);
        return (int)($row['c'] ?? 0) > 0;
    }

    public static function isEmailBlocked(PDO $pdo, string $email): bool
    {
        $email = trim($email);
        if ($email === '' || !self::tableExists($pdo, 'blocked_emails')) {
            return false;
        }

        $stmt = $pdo->prepare("SELECT 1 FROM blocked_emails WHERE email = ? LIMIT 1");
        $stmt->execute([$email]);
        return (bool)$stmt->fetchColumn();
    }

    public static function isIdentityBlocked(PDO $pdo, string $provider, string $providerUserId): bool
    {
        $provider = trim($provider);
        $providerUserId = trim($providerUserId);
        if ($provider === '' || $providerUserId === '' || !self::tableExists($pdo, 'blocked_identities')) {
            return false;
        }

        $stmt = $pdo->prepare(
            "SELECT 1 FROM blocked_identities WHERE provider = ? AND provider_user_id = ? LIMIT 1"
        );
        $stmt->execute([$provider, $providerUserId]);
        return (bool)$stmt->fetchColumn();
    }

    public static function blockEmail(
        PDO $pdo,
        string $email,
        string $reason,
        ?int $blockedBy,
        string $source
    ): void {
        $email = trim($email);
        if ($email === '' || !self::tableExists($pdo, 'blocked_emails')) {
            return;
        }

        $stmt = $pdo->prepare(
            "INSERT INTO blocked_emails (email, reason, blocked_by, blocked_at, source, created_at, updated_at)
             VALUES (?, ?, ?, NOW(), ?, NOW(), NOW())
             ON DUPLICATE KEY UPDATE
               reason = VALUES(reason),
               blocked_by = VALUES(blocked_by),
               blocked_at = VALUES(blocked_at),
               source = VALUES(source),
               updated_at = NOW()"
        );
        $stmt->execute([$email, $reason, $blockedBy, $source]);
    }

    public static function blockIdentity(
        PDO $pdo,
        string $provider,
        string $providerUserId,
        string $reason,
        ?int $blockedBy,
        string $source
    ): void {
        $provider = trim($provider);
        $providerUserId = trim($providerUserId);
        if ($provider === '' || $providerUserId === '' || !self::tableExists($pdo, 'blocked_identities')) {
            return;
        }

        $stmt = $pdo->prepare(
            "INSERT INTO blocked_identities (provider, provider_user_id, reason, blocked_by, blocked_at, source, created_at, updated_at)
             VALUES (?, ?, ?, ?, NOW(), ?, NOW(), NOW())
             ON DUPLICATE KEY UPDATE
               reason = VALUES(reason),
               blocked_by = VALUES(blocked_by),
               blocked_at = VALUES(blocked_at),
               source = VALUES(source),
               updated_at = NOW()"
        );
        $stmt->execute([$provider, $providerUserId, $reason, $blockedBy, $source]);
    }
}
