<?php
require_once __DIR__ . '/../config/database.php';
require_once __DIR__ . '/PointTransactionLogger.php';
require_once __DIR__ . '/UserActiveLogger.php';

/**
 * 處理任務完成後的統一扣款 / 撥款邏輯
 */
class TaskCompletionProcessor
{
    private const CACHE_TTL_SECONDS = 60;
    private static ?float $cachedFeeRate = null;
    private static ?int $cachedFeeRateFetchedAt = null;

    /**
     * 完成任務並執行點數與手續費扣款
     *
     * @param array $task 需包含 id, creator_id, participant_id, reward_point, title, status_id, status_code
     * @param array $options actor_id, context, metadata
     * @return array { amount, fee, net, fee_rate }
     * @throws Exception
     */
    public static function completeTask(array $task, array $options = []): array
    {
        $db = Database::getInstance();
        $pdo = $db->getConnection();

        $taskId = (string)($task['id'] ?? '');
        $creatorId = (int)($task['creator_id'] ?? 0);
        $participantId = (int)($task['participant_id'] ?? 0);
        $rawAmount = isset($task['reward_point']) ? (float)$task['reward_point'] : 0.0;
        $taskTitle = $task['title'] ?? ('Task ' . $taskId);

        if ($taskId === '' || $creatorId <= 0 || $participantId <= 0) {
            throw new Exception('Invalid task data for completion');
        }

        $amount = (int)round($rawAmount);
        if ($amount <= 0) {
            throw new Exception('Task reward must be greater than zero to complete');
        }

        $feeRate = self::getPlatformFeeRate();
        $feeAmount = (int)round($amount * $feeRate);
        $netAmount = max(0, $amount - $feeAmount);

        $completedStatusId = self::getStatusId('completed');

        $manageTransaction = !$pdo->inTransaction();
        if ($manageTransaction) {
            $db->beginTransaction();
        }

        try {
            // 更新任務狀態
            $db->query(
                "UPDATE tasks SET status_id = ?, updated_at = NOW() WHERE id = ?",
                [$completedStatusId, $taskId]
            );

            // 更新應徵者狀態
            $db->query(
                "UPDATE task_applications 
                 SET status = 'completed', updated_at = NOW() 
                 WHERE task_id = ? AND status IN ('pending', 'accepted', 'in_progress')",
                [$taskId]
            );

            // 建立交易記錄
            $rewardTransactionId = PointTransactionLogger::logTaskSpending(
                $creatorId,
                $amount,
                $taskId,
                $taskTitle
            );

            $earningTransactionId = PointTransactionLogger::logTaskEarning(
                $participantId,
                $amount,
                $taskId,
                $taskTitle
            );

            $feeTransactionId = null;
            if ($feeAmount > 0) {
                $feeTransactionId = PointTransactionLogger::logFee(
                    $participantId,
                    $feeAmount,
                    $taskId,
                    "Platform service fee for task: $taskTitle"
                );
            }

            // 更新用戶餘額
            $db->query(
                "UPDATE users SET points = points - ? WHERE id = ?",
                [$amount, $creatorId]
            );
            $db->query(
                "UPDATE users SET points = points + ? WHERE id = ?",
                [$amount, $participantId]
            );
            if ($feeAmount > 0) {
                $db->query(
                    "UPDATE users SET points = points - ? WHERE id = ?",
                    [$feeAmount, $participantId]
                );
            }

            // 記錄手續費收入
            if ($feeAmount > 0) {
                $db->query(
                    "INSERT INTO fee_revenue_ledger (
                        fee_type, src_transaction_id, task_id, payer_user_id, 
                        amount_points, rate, note, created_at
                    ) VALUES (?, ?, ?, ?, ?, ?, ?, NOW())",
                    [
                        'task_completion',
                        $feeTransactionId ?? $earningTransactionId,
                        $taskId,
                        $participantId,
                        $feeAmount,
                        $feeRate,
                        "Task completion fee: $taskTitle"
                    ]
                );
            }

            // 記錄 user_active_log
            $metadata = [
                'task_id' => $taskId,
                'task_title' => $taskTitle,
                'amount' => $amount,
                'fee' => $feeAmount,
                'net' => $netAmount,
                'context' => $options['context'] ?? 'system',
            ];
            $actorId = isset($options['actor_id']) ? (int)$options['actor_id'] : null;

            UserActiveLogger::logAction(
                $pdo,
                $creatorId,
                'task_completion_payment',
                'points',
                null,
                null,
                null,
                $actorId ? 'user' : 'system',
                $actorId,
                null,
                null,
                $metadata
            );

            UserActiveLogger::logAction(
                $pdo,
                $participantId,
                'task_completion_earning',
                'points',
                null,
                null,
                null,
                $actorId ? 'user' : 'system',
                $actorId,
                null,
                null,
                $metadata
            );

            if ($feeAmount > 0) {
                UserActiveLogger::logAction(
                    $pdo,
                    $participantId,
                    'task_completion_fee',
                    'points',
                    null,
                    null,
                    'Platform fee deduction',
                    $actorId ? 'user' : 'system',
                    $actorId,
                    null,
                    null,
                    $metadata
                );
            }

            if ($manageTransaction) {
                $db->commit();
            }
        } catch (Exception $e) {
            if ($manageTransaction && $pdo->inTransaction()) {
                $db->rollback();
            }
            throw $e;
        }

        return [
            'amount' => $amount,
            'fee' => $feeAmount,
            'net' => $netAmount,
            'fee_rate' => $feeRate,
            'reward_transaction_id' => $rewardTransactionId,
            'earning_transaction_id' => $earningTransactionId,
            'fee_transaction_id' => $feeTransactionId
        ];
    }

    /**
     * 取得目前啟用的手續費率
     */
    public static function getPlatformFeeRate(): float
    {
        $now = time();
        if (
            self::$cachedFeeRate !== null &&
            self::$cachedFeeRateFetchedAt !== null &&
            ($now - self::$cachedFeeRateFetchedAt) < self::CACHE_TTL_SECONDS
        ) {
            return self::$cachedFeeRate;
        }

        $db = Database::getInstance();
        $row = $db->fetch("SELECT rate FROM task_completion_points_fee_settings WHERE is_active = 1 ORDER BY id DESC LIMIT 1");

        if (!$row || !isset($row['rate'])) {
            throw new Exception('Active platform fee rate is not configured. Please set the fee in admin > Payments > Fee Settings.');
        }

        $rate = (float)$row['rate'];
        if ($rate <= 0 || $rate >= 1) {
            throw new Exception('Platform fee rate configuration is invalid.');
        }

        self::$cachedFeeRate = $rate;
        self::$cachedFeeRateFetchedAt = $now;
        return $rate;
    }

    private static function getStatusId(string $code): int
    {
        $db = Database::getInstance();
        $row = $db->fetch("SELECT id FROM task_statuses WHERE code = ? LIMIT 1", [$code]);

        if (!$row || !isset($row['id'])) {
            throw new Exception("Status not found: $code");
        }

        return (int)$row['id'];
    }
}
