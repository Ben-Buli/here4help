<?php
/**
 * 後台管理系統儀表板 - 使用統一 Layout 版模
 */

require_once 'includes/config.php';
require_once 'includes/jwt_helper.php';

// 驗證登入狀態
$admin = verify_admin_login();
if (!$admin) {
    header('Location: login.php');
    exit;
}

// 檢查管理員狀態
if ($admin['status'] !== 'active') {
    header('Location: login.php');
    exit;
}

// 設置頁面資訊
$page_title = '儀表板';
$page_icon = 'fas fa-home';

// 頁面自定義樣式
$page_styles = '
    .stats-grid {
        display: grid;
        grid-template-columns: repeat(auto-fit, minmax(250px, 1fr));
        gap: var(--spacing-lg);
        margin-bottom: var(--spacing-lg);
    }
    
    .stat-card {
        display: flex;
        align-items: center;
        gap: var(--spacing-md);
        padding: var(--spacing-lg);
        background: rgba(255, 255, 255, 0.95);
        border-radius: 12px;
        box-shadow: 0 4px 20px rgba(0, 0, 0, 0.08);
        border: 1px solid rgba(255, 255, 255, 0.2);
        backdrop-filter: blur(10px);
        transition: all 0.3s ease;
    }
    
    .stat-card:hover {
        transform: translateY(-2px);
        box-shadow: 0 8px 30px rgba(0, 0, 0, 0.12);
    }
    
    .stat-icon {
        width: 48px;
        height: 48px;
        border-radius: 12px;
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 20px;
        color: white;
        background: linear-gradient(135deg, var(--primary-blue) 0%, var(--primary-blue-hover) 100%);
    }
    
    .stat-content {
        flex: 1;
    }
    
    .stat-number {
        font-size: 24px;
        font-weight: 700;
        color: var(--text-dark);
        margin-bottom: 4px;
    }
    
    .stat-label {
        font-size: 14px;
        color: var(--text-gray);
        font-weight: 500;
    }
    
    .content-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: var(--spacing-lg);
        margin-bottom: var(--spacing-lg);
    }
    
    @media (max-width: 1024px) {
        .content-grid {
            grid-template-columns: 1fr;
        }
    }
    
    .user-list {
        max-height: 400px;
        overflow-y: auto;
    }
    
    .user-item {
        display: flex;
        align-items: center;
        gap: var(--spacing-md);
        padding: var(--spacing-md);
        border-bottom: 1px solid var(--border-light);
        transition: background-color 0.2s ease;
    }
    
    .user-item:last-child {
        border-bottom: none;
    }
    
    .user-item:hover {
        background-color: rgba(0, 0, 0, 0.02);
    }
    
    .user-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        background: linear-gradient(135deg, var(--primary-blue) 0%, var(--primary-blue-hover) 100%);
        display: flex;
        align-items: center;
        justify-content: center;
        color: white;
        font-size: 16px;
    }
    
    .user-info {
        flex: 1;
    }
    
    .user-name {
        font-weight: 600;
        color: var(--text-dark);
        margin-bottom: 2px;
    }
    
    .user-email {
        font-size: 12px;
        color: var(--text-gray);
        margin-bottom: 4px;
    }
    
    .user-meta {
        display: flex;
        gap: var(--spacing-sm);
        align-items: center;
    }
    
    .user-status {
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 11px;
        font-weight: 500;
    }
    
    .status-active {
        background: rgba(102, 187, 106, 0.1);
        color: #66BB6A;
    }
    
    .status-pending_verification {
        background: rgba(255, 152, 0, 0.1);
        color: #FF9800;
    }
    
    .status-verification_rejected {
        background: rgba(244, 67, 54, 0.1);
        color: #F44336;
    }
    
    .status-banned {
        background: rgba(158, 158, 158, 0.1);
        color: #9E9E9E;
    }
    
    .status-inactive {
        background: rgba(158, 158, 158, 0.1);
        color: #9E9E9E;
    }
    
    .user-date {
        font-size: 11px;
        color: var(--text-gray);
    }
    
    .chat-management {
        display: flex;
        flex-direction: column;
        gap: var(--spacing-lg);
    }
    
    .chat-section {
        padding: var(--spacing-md);
        border: 1px solid var(--border-light);
        border-radius: 8px;
        background: rgba(255, 255, 255, 0.5);
    }
    
    .chat-header {
        display: flex;
        justify-content: space-between;
        align-items: center;
        margin-bottom: var(--spacing-md);
    }
    
    .chat-title {
        font-size: 16px;
        font-weight: 600;
        color: var(--text-dark);
        display: flex;
        align-items: center;
        gap: var(--spacing-sm);
    }
    
    .chat-count {
        background: var(--status-rejected);
        color: white;
        padding: 2px 8px;
        border-radius: 12px;
        font-size: 12px;
        font-weight: 600;
    }
    
    .chat-link {
        color: var(--primary-blue);
        text-decoration: none;
        font-size: 14px;
        font-weight: 500;
        transition: color 0.2s ease;
    }
    
    .chat-link:hover {
        color: var(--primary-blue-hover);
    }
';

// 獲取統計數據
$stats = [];

// 總用戶數（排除停權用戶）
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM users WHERE status != 'banned'");
$stmt->execute();
$stats['total_users'] = $stmt->fetch()['count'];

// 活躍用戶數
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM users WHERE status = 'active'");
$stmt->execute();
$stats['active_users'] = $stmt->fetch()['count'];

// 待驗證用戶數
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM users WHERE status = 'pending_verification'");
$stmt->execute();
$stats['pending_users'] = $stmt->fetch()['count'];

// 本月新用戶數
$stmt = $pdo->prepare("
    SELECT COUNT(*) as count 
    FROM users 
    WHERE MONTH(created_at) = MONTH(CURRENT_DATE()) 
    AND YEAR(created_at) = YEAR(CURRENT_DATE())
");
$stmt->execute();
$stats['new_users_this_month'] = $stmt->fetch()['count'];

// 活躍任務統計（非 completed 狀態）
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM tasks WHERE status != 'completed'");
$stmt->execute();
$stats['active_tasks'] = $stmt->fetch()['count'];

// 推薦碼總數
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM referral_codes");
$stmt->execute();
$stats['total_referral_codes'] = $stmt->fetch()['count'];

// 已使用推薦碼
$stmt = $pdo->prepare("SELECT COUNT(*) as count FROM referral_codes WHERE is_used = 1");
$stmt->execute();
$stats['used_referral_codes'] = $stmt->fetch()['count'];

// 尚未回應的客服聊天室統計
try {
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM support_chat_rooms 
        WHERE status = 'open'
    ");
    $stmt->execute();
    $stats['unread_support_chats'] = $stmt->fetch()['count'];
} catch (Exception $e) {
    $stats['unread_support_chats'] = 0;
}

// 尚未回應的任務申訴聊天室統計
try {
    $stmt = $pdo->prepare("
        SELECT COUNT(*) as count 
        FROM task_dispute_chat_rooms 
        WHERE status = 'open'
    ");
    $stmt->execute();
    $stats['unread_dispute_chats'] = $stmt->fetch()['count'];
} catch (Exception $e) {
    $stats['unread_dispute_chats'] = 0;
}

// 最近註冊用戶 (前10名)
$stmt = $pdo->prepare("
    SELECT id, name, email, status, created_at 
    FROM users 
    ORDER BY created_at DESC 
    LIMIT 10
");
$stmt->execute();
$recent_users = $stmt->fetchAll();

// 頁面內容
ob_start();
?>

<!-- 統計卡片 -->
<div class="stats-grid">
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-users"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['total_users']); ?></div>
            <div class="stat-label">總用戶數</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-user-check"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['active_users']); ?></div>
            <div class="stat-label">活躍用戶</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-user-clock"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['pending_users']); ?></div>
            <div class="stat-label">待驗證用戶</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-user-plus"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['new_users_this_month']); ?></div>
            <div class="stat-label">本月新用戶</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-tasks"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['active_tasks']); ?></div>
            <div class="stat-label">活躍任務</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-gift"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['total_referral_codes']); ?></div>
            <div class="stat-label">推薦碼總數</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-check-circle"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['used_referral_codes']); ?></div>
            <div class="stat-label">已使用推薦碼</div>
        </div>
    </div>
    
    <div class="stat-card fade-in">
        <div class="stat-icon">
            <i class="fas fa-headset"></i>
        </div>
        <div class="stat-content">
            <div class="stat-number"><?php echo number_format($stats['unread_support_chats']); ?></div>
            <div class="stat-label">未回應客服</div>
        </div>
    </div>
</div>

<!-- 內容區塊網格 -->
<div class="content-grid">
    <!-- 最近註冊用戶 -->
    <div class="card fade-in">
        <div class="card-header">
            <h2 class="card-title">
                <i class="fas fa-user-plus"></i>
                最近註冊用戶
            </h2>
            <a href="users.php" class="btn btn-outline btn-sm">
                <i class="fas fa-external-link-alt"></i>
                查看全部
            </a>
        </div>
        <div class="card-body">
            <?php if (empty($recent_users)): ?>
                <p style="text-align: center; color: var(--text-gray);">暫無註冊用戶</p>
            <?php else: ?>
                <div class="user-list">
                    <?php foreach ($recent_users as $user): ?>
                        <div class="user-item">
                            <div class="user-avatar">
                                <?php echo strtoupper(substr($user['name'], 0, 1)); ?>
                            </div>
                            <div class="user-info">
                                <div class="user-name"><?php echo htmlspecialchars($user['name']); ?></div>
                                <div class="user-email"><?php echo htmlspecialchars($user['email']); ?></div>
                                <div class="user-meta">
                                    <span class="user-status status-<?php echo $user['status']; ?>">
                                        <?php 
                                            echo $user['status'] === 'active' ? '活躍' : 
                                                ($user['status'] === 'pending_verification' ? '審核中' : 
                                                ($user['status'] === 'verification_rejected' ? '已駁回' : 
                                                ($user['status'] === 'banned' ? '停權' : '非活躍')));
                                        ?>
                                    </span>
                                    <span class="user-date">
                                        <?php echo date('m/d H:i', strtotime($user['created_at'])); ?>
                                    </span>
                                </div>
                            </div>
                        </div>
                    <?php endforeach; ?>
                </div>
            <?php endif; ?>
        </div>
    </div>

    <!-- 聊天室管理 -->
    <div class="card fade-in">
        <div class="card-header">
            <h2 class="card-title">
                <i class="fas fa-comments"></i>
                聊天室管理
            </h2>
        </div>
        <div class="card-body">
            <div class="chat-management">
                <div class="chat-section">
                    <div class="chat-header">
                        <div class="chat-title">
                            <i class="fas fa-headset"></i>
                            客服聊天室
                        </div>
                        <span class="chat-count"><?php echo $stats['unread_support_chats']; ?></span>
                    </div>
                    <p style="margin: 0; color: var(--text-gray); font-size: 14px;">
                        尚未回應的客服聊天室
                    </p>
                    <a href="support_chat_rooms.php" class="chat-link">
                        查看聊天室列表 <i class="fas fa-arrow-right"></i>
                    </a>
                </div>
                
                <div class="chat-section">
                    <div class="chat-header">
                        <div class="chat-title">
                            <i class="fas fa-exclamation-triangle"></i>
                            任務申訴聊天室
                        </div>
                        <span class="chat-count"><?php echo $stats['unread_dispute_chats']; ?></span>
                    </div>
                    <p style="margin: 0; color: var(--text-gray); font-size: 14px;">
                        尚未回應的任務申訴聊天室
                    </p>
                    <a href="task_dispute_chat_rooms.php" class="chat-link">
                        查看申訴列表 <i class="fas fa-arrow-right"></i>
                    </a>
                </div>
            </div>
        </div>
    </div>
</div>

<?php
$page_content = ob_get_clean();

// 包含統一的 layout
include 'includes/layout.php';
?> 