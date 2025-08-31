<?php

require_once __DIR__ . '/../vendor/autoload.php';

use Illuminate\Support\Facades\DB;
use Carbon\Carbon;

// 初始化 Laravel
$app = require_once __DIR__ . '/../bootstrap/app.php';
$app->make('Illuminate\Contracts\Console\Kernel')->bootstrap();

echo "開始添加測試日誌資料...\n";

// 檢查是否有管理員
$admin = DB::table('admins')->first();
if (!$admin) {
    echo "錯誤：沒有找到管理員，請先創建管理員帳號\n";
    exit(1);
}

// 添加登入日誌
echo "添加登入日誌...\n";
$loginLogs = [
    [
        'admin_id' => $admin->id,
        'login_time' => Carbon::now()->subHours(2),
        'logout_time' => Carbon::now()->subHours(1),
        'ip_address' => '192.168.1.100',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'status' => 'success',
    ],
    [
        'admin_id' => $admin->id,
        'login_time' => Carbon::now()->subDays(1),
        'logout_time' => Carbon::now()->subDays(1)->addHours(2),
        'ip_address' => '192.168.1.100',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'status' => 'success',
    ],
    [
        'admin_id' => $admin->id,
        'login_time' => Carbon::now()->subHours(1),
        'logout_time' => null,
        'ip_address' => '192.168.1.101',
        'user_agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'status' => 'failed',
    ],
];

foreach ($loginLogs as $log) {
    DB::table('admin_login_logs')->insert($log);
}

// 添加活動日誌
echo "添加活動日誌...\n";
$activityLogs = [
    [
        'admin_id' => $admin->id,
        'action' => 'view_users',
        'table_name' => 'users',
        'record_id' => null,
        'old_data' => null,
        'new_data' => null,
        'ip_address' => '192.168.1.100',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'created_at' => Carbon::now()->subHours(1),
    ],
    [
        'admin_id' => $admin->id,
        'action' => 'update_user_status',
        'table_name' => 'users',
        'record_id' => 1,
        'old_data' => json_encode(['status' => 'pending']),
        'new_data' => json_encode(['status' => 'active']),
        'ip_address' => '192.168.1.100',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'created_at' => Carbon::now()->subHours(30),
    ],
    [
        'admin_id' => $admin->id,
        'action' => 'view_tasks',
        'table_name' => 'tasks',
        'record_id' => null,
        'old_data' => null,
        'new_data' => null,
        'ip_address' => '192.168.1.100',
        'user_agent' => 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36',
        'created_at' => Carbon::now()->subDays(1),
    ],
];

foreach ($activityLogs as $log) {
    DB::table('admin_activity_logs')->insert($log);
}

echo "測試日誌資料添加完成！\n";
echo "已添加 " . count($loginLogs) . " 條登入日誌\n";
echo "已添加 " . count($activityLogs) . " 條活動日誌\n";
