<?php

require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/UserActiveLogger.php';

class TermsManager
{
    /**
     * 取得目前生效中的條款版本
     * 檢查最新一筆 app_terms，最新、並且 is_active=1 的唯一一筆
     * 
     * @param bool $fallbackToLatest 是否在沒有 active 版本時回退至最新建立的版本（預設為 true，保持向後兼容）
     * @return array|null
     */
    public static function getActiveTerms(bool $fallbackToLatest = true): ?array
    {
        $db = Database::getInstance();

        // 優先取得 is_active=1 的最新一筆條款（唯一一筆）
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

        // Fallback：如果沒有 active 版本，回退至最新建立的版本（保持向後兼容）
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
        // 使用 LEFT JOIN 以避免當條款版本不存在時查詢失敗
        $result = $db->fetch("
            SELECT tua.id, tua.user_id, tua.accepted_version_id, tua.accepted_at,
                   tua.ip_address, tua.device_info, tua.user_agent, tua.platform,
                   at.slug as version, at.title
            FROM terms_user_acceptance tua
            LEFT JOIN app_terms at ON at.id = tua.accepted_version_id
            WHERE tua.user_id = ?
            ORDER BY tua.accepted_at DESC, tua.id DESC
            LIMIT 1
        ", [$userId]);
        
        // 如果查詢結果存在但條款版本不存在，仍然返回記錄（但 version 和 title 為 null）
        return $result ?: null;
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
        ", [$userId, $versionId]) ?: null;
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
        $pdo = $db->getConnection();

        $ip = $meta['ip_address'] ?? null;
        $deviceInfo = $meta['device_info'] ?? null;
        $userAgent = $meta['user_agent'] ?? null;
        $platform = $meta['platform'] ?? null;

        // 獲取條款版本資訊用於日誌
        $terms = self::getTermsById($versionId);
        $versionSlug = $terms['version'] ?? $terms['slug'] ?? "v{$versionId}";
        $termsTitle = $terms['title'] ?? "Terms Version {$versionId}";

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

            $result = self::findAcceptance($userId, $versionId);
        } else {
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

            $result = $db->fetch("
                SELECT id, user_id, accepted_version_id, accepted_at,
                       ip_address, device_info, user_agent, platform
                FROM terms_user_acceptance
                WHERE id = ?
            ", [$newId]);
        }

        // 記錄使用者同意條款的行為日誌
        try {
            UserActiveLogger::logAction(
                $pdo,
                $userId,
                'terms_accepted',
                'terms_version',
                null,
                $versionSlug,
                "User agreed to terms: {$termsTitle} (Version: {$versionSlug}, ID: {$versionId})",
                'user',
                $userId,
                null,
                null,
                [
                    'terms_version_id' => $versionId,
                    'terms_version' => $versionSlug,
                    'terms_title' => $termsTitle,
                    'device_info' => $deviceInfo,
                    'platform' => $platform,
                ]
            );
        } catch (Exception $e) {
            // 日誌記錄失敗不應該影響主要流程
            error_log("Failed to log terms acceptance: " . $e->getMessage());
        }

        return $result;
    }

    /**
     * 記錄使用者拒絕條款
     */
    public static function recordRejection(
        int $userId,
        int $versionId,
        array $meta = []
    ): void {
        $db = Database::getInstance();
        $pdo = $db->getConnection();

        // 獲取條款版本資訊用於日誌
        $terms = self::getTermsById($versionId);
        $versionSlug = $terms['version'] ?? $terms['slug'] ?? "v{$versionId}";
        $termsTitle = $terms['title'] ?? "Terms Version {$versionId}";

        $deviceInfo = $meta['device_info'] ?? null;
        $platform = $meta['platform'] ?? null;

        // 記錄使用者拒絕條款的行為日誌
        try {
            UserActiveLogger::logAction(
                $pdo,
                $userId,
                'terms_rejected',
                'terms_version',
                null,
                $versionSlug,
                "User rejected terms: {$termsTitle} (Version: {$versionSlug}, ID: {$versionId})",
                'user',
                $userId,
                null,
                null,
                [
                    'terms_version_id' => $versionId,
                    'terms_version' => $versionSlug,
                    'terms_title' => $termsTitle,
                    'device_info' => $deviceInfo,
                    'platform' => $platform,
                ]
            );
        } catch (Exception $e) {
            // 日誌記錄失敗不應該影響主要流程
            error_log("Failed to log terms rejection: " . $e->getMessage());
        }
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
