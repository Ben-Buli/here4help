<?php

require_once __DIR__ . '/../config/database.php';

class TermsManager
{
    /**
     * 取得目前生效中的條款版本；若沒有 active 版本則回退至最新建立的版本
     */
    public static function getActiveTerms(bool $fallbackToLatest = true): ?array
    {
        $db = Database::getInstance();

        $active = $db->fetch("
            SELECT id, slug, title, summary, content, is_active, requires_ack, created_by, created_at, updated_at, published_at
            FROM app_terms
            WHERE type = 'terms' AND is_active = 1
            ORDER BY COALESCE(published_at, created_at) DESC, id DESC
            LIMIT 1
        ");

        if ($active || !$fallbackToLatest) {
            return self::normalizeTermRow($active);
        }

        $latest = $db->fetch("
            SELECT id, slug, title, summary, content, is_active, requires_ack, created_by, created_at, updated_at, published_at
            FROM app_terms
            WHERE type = 'terms'
            ORDER BY COALESCE(published_at, created_at) DESC, id DESC
            LIMIT 1
        ");

        return self::normalizeTermRow($latest);
    }

    /**
     * 以 ID 取得條款版本
     */
    public static function getTermsById(int $id): ?array
    {
        $db = Database::getInstance();
        $term = $db->fetch("
            SELECT id, slug, title, summary, content, is_active, requires_ack, created_by, created_at, updated_at, published_at
            FROM app_terms
            WHERE id = ?
            LIMIT 1
        ", [$id]);

        return self::normalizeTermRow($term);
    }

    /**
     * 取得使用者最新同意紀錄
     */
    public static function getLatestAcceptance(int $userId): ?array
    {
        $db = Database::getInstance();
        return $db->fetch("
            SELECT tua.id, tua.user_id, tua.accepted_version_id, tua.accepted_at,
                   tua.ip_address, tua.device_info, tua.user_agent, tua.platform,
                   at.slug as version, at.title
            FROM terms_user_acceptance tua
            INNER JOIN app_terms at ON at.id = tua.accepted_version_id
            WHERE tua.user_id = ?
            ORDER BY tua.accepted_at DESC, tua.id DESC
            LIMIT 1
        ", [$userId]);
    }

    /**
     * 檢查使用者是否已同意指定版本
     */
    public static function findAcceptance(int $userId, int $versionId): ?array
    {
        $db = Database::getInstance();
        return $db->fetch("
            SELECT id, user_id, accepted_version_id, accepted_at,
                   ip_address, device_info, user_agent, platform
            FROM terms_user_acceptance
            WHERE user_id = ? AND accepted_version_id = ?
            LIMIT 1
        ", [$userId, $versionId]);
    }

    /**
     * 記錄使用者同意條款
     */
    public static function recordAcceptance(
        int $userId,
        int $versionId,
        array $meta = []
    ): array {
        $db = Database::getInstance();

        $ip = $meta['ip_address'] ?? null;
        $deviceInfo = $meta['device_info'] ?? null;
        $userAgent = $meta['user_agent'] ?? null;
        $platform = $meta['platform'] ?? null;

        $existing = self::findAcceptance($userId, $versionId);
        if ($existing) {
            $db->query("
                UPDATE terms_user_acceptance
                SET accepted_at = NOW(),
                    ip_address = ?,
                    device_info = ?,
                    user_agent = ?,
                    platform = ?
                WHERE id = ?
            ", [
                $ip,
                $deviceInfo,
                $userAgent,
                $platform,
                $existing['id'],
            ]);

            return self::findAcceptance($userId, $versionId);
        }

        $db->query("
            INSERT INTO terms_user_acceptance (
                user_id, accepted_version_id, accepted_at,
                ip_address, device_info, user_agent, platform
            ) VALUES (?, ?, NOW(), ?, ?, ?, ?)
        ", [
            $userId,
            $versionId,
            $ip,
            $deviceInfo,
            $userAgent,
            $platform,
        ]);

        $newId = $db->lastInsertId();

        return $db->fetch("
            SELECT id, user_id, accepted_version_id, accepted_at,
                   ip_address, device_info, user_agent, platform
            FROM terms_user_acceptance
            WHERE id = ?
        ", [$newId]);
    }

    private static function normalizeTermRow(?array $row): ?array
    {
        if (!$row) {
            return null;
        }

        $row['version'] = $row['slug'] ?? null;
        return $row;
    }
}

