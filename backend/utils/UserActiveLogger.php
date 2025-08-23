<?php
class UserActiveLogger {
    /**
     * 紀錄使用者行為
     *
     * @param PDO $pdo              PDO 連線
     * @param int $userId           受影響的 user_id
     * @param string $action        動作名稱（例如: register, deactivate, reactivate, profile_update, avatar_upload）
     * @param string|null $field    變更的欄位名稱（例如: status, permission；沒有就傳 null）
     * @param string|null $oldValue 舊值
     * @param string|null $newValue 新值
     * @param string|null $reason   操作原因或描述
     * @param string $actorType     操作者類型：user | admin | system
     * @param int|null $actorId     操作者 ID（對應 users.id 或 admins.id，system 可為 NULL）
     * @param string|null $requestId 可選，用於追蹤請求 id
     * @param string|null $traceId   可選，用於分散式 trace
     * @param array|null $metadata   額外資料，會以 JSON 儲存
     */
    public static function logAction(
        PDO $pdo,
        int $userId,
        string $action,
        ?string $field = null,
        ?string $oldValue = null,
        ?string $newValue = null,
        ?string $reason = null,
        string $actorType = 'user',
        ?int $actorId = null,
        ?string $requestId = null,
        ?string $traceId = null,
        ?array $metadata = null
    ): void {
        $stmt = $pdo->prepare("
            INSERT INTO user_active_log
                (user_id, actor_type, actor_id, action, field, old_value, new_value, reason, ip, user_agent, request_id, trace_id, metadata, created_at)
            VALUES
                (:user_id, :actor_type, :actor_id, :action, :field, :old_value, :new_value, :reason, :request_id, :trace_id, :metadata, NOW())
        ");

        $ip = $_SERVER['REMOTE_ADDR'] ?? null;
        $userAgent = $_SERVER['HTTP_USER_AGENT'] ?? null;

        $stmt->execute([
            ':user_id'    => $userId,
            ':actor_type' => $actorType,
            ':actor_id'   => $actorId,
            ':action'     => $action,
            ':field'      => $field,
            ':old_value'  => $oldValue,
            ':new_value'  => $newValue,
            ':reason'     => $reason,
            ':ip'         => $ip,
            ':user_agent' => $userAgent,
            ':request_id' => $requestId,
            ':trace_id'   => $traceId,
            ':metadata'   => $metadata ? json_encode($metadata) : null,
        ]);
    }
}