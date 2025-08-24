<?php
/**
 * 點數交易記錄器
 * 統一管理所有點數變動的記錄到 point_transactions 表
 */

require_once __DIR__ . '/../config/database.php';

class PointTransactionLogger
{
    /**
     * 記錄點數交易
     * 
     * @param int $userId 用戶ID
     * @param string $transactionType 交易類型 (earn, spend, deposit, fee, refund, adjustment)
     * @param int $amount 金額（正數為收入，負數為支出）
     * @param string $description 交易描述
     * @param string|null $relatedTaskId 相關任務ID
     * @param int|null $relatedOrderId 相關訂單ID
     * @param string $status 狀態 (completed, pending, cancelled)
     * @return int 返回插入的記錄ID
     */
    public static function logTransaction(
        int $userId,
        string $transactionType,
        int $amount,
        string $description,
        ?string $relatedTaskId = null,
        ?int $relatedOrderId = null,
        string $status = 'completed'
    ): int {
        $db = Database::getInstance();
        
        // 驗證交易類型
        $validTypes = ['earn', 'spend', 'deposit', 'fee', 'refund', 'adjustment'];
        if (!in_array($transactionType, $validTypes)) {
            throw new InvalidArgumentException("Invalid transaction type: $transactionType");
        }
        
        // 驗證狀態
        $validStatuses = ['completed', 'pending', 'cancelled'];
        if (!in_array($status, $validStatuses)) {
            throw new InvalidArgumentException("Invalid status: $status");
        }
        
        // 獲取用戶當前餘額
        $currentBalance = self::getCurrentUserBalance($userId);
        
        // 計算交易後餘額
        $balanceAfter = $currentBalance + $amount;
        
        // 插入交易記錄
        $insertQuery = "
            INSERT INTO point_transactions (
                user_id, transaction_type, amount, description,
                related_task_id, related_order_id, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?,  ?, NOW(), NOW())
        ";
        
        $db->execute($insertQuery, [
            $userId,
            $transactionType,
            $amount,
            $balanceAfter,
            $description,
            $relatedTaskId,
            $relatedOrderId,
            $status
        ]);
        
        return $db->lastInsertId();
    }
    
    /**
     * 記錄任務收入
     */
    public static function logTaskEarning(
        int $userId,
        int $amount,
        string $taskId,
        string $taskTitle
    ): int {
        return self::logTransaction(
            $userId,
            'earn',
            $amount,
            "Task completed: $taskTitle",
            $taskId
        );
    }
    
    /**
     * 記錄任務支出
     */
    public static function logTaskSpending(
        int $userId,
        int $amount,
        string $taskId,
        string $taskTitle
    ): int {
        return self::logTransaction(
            $userId,
            'spend',
            -abs($amount), // 確保是負數
            "Task payment: $taskTitle",
            $taskId
        );
    }
    
    /**
     * 記錄儲值
     */
    public static function logDeposit(
        int $userId,
        int $amount,
        string $description = 'Points deposit'
    ): int {
        return self::logTransaction(
            $userId,
            'deposit',
            $amount,
            $description
        );
    }
    
    /**
     * 記錄手續費
     */
    public static function logFee(
        int $userId,
        int $amount,
        string $taskId,
        string $description = 'Service fee'
    ): int {
        return self::logTransaction(
            $userId,
            'fee',
            -abs($amount), // 確保是負數
            $description,
            $taskId
        );
    }
    
    /**
     * 記錄退款
     */
    public static function logRefund(
        int $userId,
        int $amount,
        string $taskId,
        string $reason
    ): int {
        return self::logTransaction(
            $userId,
            'refund',
            $amount,
            "Refund: $reason",
            $taskId
        );
    }
    
    /**
     * 記錄系統調整
     */
    public static function logAdjustment(
        int $userId,
        int $amount,
        string $reason,
        ?string $taskId = null
    ): int {
        return self::logTransaction(
            $userId,
            'adjustment',
            $amount,
            "System adjustment: $reason",
            $taskId
        );
    }
    
    /**
     * 獲取用戶當前餘額
     */
    private static function getCurrentUserBalance(int $userId): int
    {
        $db = Database::getInstance();
        
        $balanceQuery = "SELECT points FROM users WHERE id = ?";
        $result = $db->fetch($balanceQuery, [$userId]);
        
        if (!$result) {
            throw new Exception("User not found: $userId");
        }
        
        return (int)$result['points'];
    }
    
    /**
     * 批量記錄交易（用於任務完成時的多筆交易）
     * 
     * @param array $transactions 交易數組，每個元素包含交易參數
     * @return array 返回所有插入的記錄ID
     */
    public static function logBatchTransactions(array $transactions): array
    {
        $db = Database::getInstance();
        $transactionIds = [];
        
        $db->beginTransaction();
        
        try {
            foreach ($transactions as $transaction) {
                $transactionId = self::logTransaction(
                    $transaction['user_id'],
                    $transaction['transaction_type'],
                    $transaction['amount'],
                    $transaction['description'],
                    $transaction['related_task_id'] ?? null,
                    $transaction['related_order_id'] ?? null,
                    $transaction['status'] ?? 'completed'
                );
                
                $transactionIds[] = $transactionId;
            }
            
            $db->commit();
            return $transactionIds;
            
        } catch (Exception $e) {
            $db->rollback();
            throw $e;
        }
    }
    
    /**
     * 獲取用戶交易統計
     */
    public static function getUserTransactionStats(int $userId): array
    {
        $db = Database::getInstance();
        
        $statsQuery = "
            SELECT 
                transaction_type,
                COUNT(*) as count,
                SUM(CASE WHEN amount > 0 THEN amount ELSE 0 END) as total_income,
                SUM(CASE WHEN amount < 0 THEN ABS(amount) ELSE 0 END) as total_expense
            FROM point_transactions 
            WHERE user_id = ? AND status = 'completed'
            GROUP BY transaction_type
        ";
        
        $stats = $db->fetchAll($statsQuery, [$userId]);
        
        $formattedStats = [];
        foreach ($stats as $stat) {
            $formattedStats[$stat['transaction_type']] = [
                'count' => (int)$stat['count'],
                'total_income' => (int)$stat['total_income'],
                'total_expense' => (int)$stat['total_expense']
            ];
        }
        
        return $formattedStats;
    }
}
?>
