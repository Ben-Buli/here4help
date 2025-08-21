<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class LogController extends Controller
{
    /**
     * 獲取管理員活動日誌
     */
    public function activityLogs(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'admin_id' => 'integer',
            'action' => 'string',
            'resource_type' => 'string',
            'date_from' => 'date',
            'date_to' => 'date',
            'sort_order' => 'string|in:asc,desc'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $page = $request->get('page', 1);
        $perPage = $request->get('per_page', 20);
        $adminId = $request->get('admin_id');
        $action = $request->get('action');
        $resourceType = $request->get('resource_type');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $sortOrder = $request->get('sort_order', 'desc');

        // 建立查詢
        $query = DB::table('admin_activity_logs')
            ->leftJoin('admins', 'admin_activity_logs.admin_id', '=', 'admins.id')
            ->select([
                'admin_activity_logs.*',
                'admins.username as admin_username',
                'admins.full_name as admin_name'
            ]);

        // 篩選條件
        if ($adminId) {
            $query->where('admin_activity_logs.admin_id', $adminId);
        }

        if ($action) {
            $query->where('admin_activity_logs.action', 'LIKE', "%{$action}%");
        }

        if ($resourceType) {
            $query->where('admin_activity_logs.resource_type', $resourceType);
        }

        if ($dateFrom) {
            $query->where('admin_activity_logs.created_at', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->where('admin_activity_logs.created_at', '<=', $dateTo . ' 23:59:59');
        }

        // 總數
        $total = $query->count();

        // 分頁和排序
        $logs = $query->orderBy('admin_activity_logs.created_at', $sortOrder)
                     ->offset(($page - 1) * $perPage)
                     ->limit($perPage)
                     ->get();

        // 統計資訊
        $stats = [
            'total_logs' => DB::table('admin_activity_logs')->count(),
            'by_action' => DB::table('admin_activity_logs')
                ->select('action', DB::raw('COUNT(*) as count'))
                ->groupBy('action')
                ->orderBy('count', 'desc')
                ->limit(10)
                ->get(),
            'by_admin' => DB::table('admin_activity_logs')
                ->join('admins', 'admin_activity_logs.admin_id', '=', 'admins.id')
                ->select('admins.full_name', 'admins.username', DB::raw('COUNT(*) as count'))
                ->groupBy('admins.id', 'admins.full_name', 'admins.username')
                ->orderBy('count', 'desc')
                ->limit(10)
                ->get(),
            'by_resource' => DB::table('admin_activity_logs')
                ->select('resource_type', DB::raw('COUNT(*) as count'))
                ->whereNotNull('resource_type')
                ->groupBy('resource_type')
                ->orderBy('count', 'desc')
                ->get()
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'logs' => $logs,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ],
                'stats' => $stats
            ]
        ]);
    }

    /**
     * 獲取管理員登入日誌
     */
    public function loginLogs(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'admin_id' => 'integer',
            'status' => 'string|in:success,failed,locked',
            'ip_address' => 'string',
            'date_from' => 'date',
            'date_to' => 'date',
            'sort_order' => 'string|in:asc,desc'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $page = $request->get('page', 1);
        $perPage = $request->get('per_page', 20);
        $adminId = $request->get('admin_id');
        $status = $request->get('status');
        $ipAddress = $request->get('ip_address');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $sortOrder = $request->get('sort_order', 'desc');

        // 建立查詢
        $query = DB::table('admin_login_logs')
            ->leftJoin('admins', 'admin_login_logs.admin_id', '=', 'admins.id')
            ->select([
                'admin_login_logs.*',
                'admins.username as admin_username',
                'admins.full_name as admin_name'
            ]);

        // 篩選條件
        if ($adminId) {
            $query->where('admin_login_logs.admin_id', $adminId);
        }

        if ($status) {
            $query->where('admin_login_logs.status', $status);
        }

        if ($ipAddress) {
            $query->where('admin_login_logs.ip_address', 'LIKE', "%{$ipAddress}%");
        }

        if ($dateFrom) {
            $query->where('admin_login_logs.login_time', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->where('admin_login_logs.login_time', '<=', $dateTo . ' 23:59:59');
        }

        // 總數
        $total = $query->count();

        // 分頁和排序
        $logs = $query->orderBy('admin_login_logs.login_time', $sortOrder)
                     ->offset(($page - 1) * $perPage)
                     ->limit($perPage)
                     ->get();

        // 統計資訊
        $stats = [
            'total_logins' => DB::table('admin_login_logs')->count(),
            'successful_logins' => DB::table('admin_login_logs')->where('status', 'success')->count(),
            'failed_logins' => DB::table('admin_login_logs')->where('status', 'failed')->count(),
            'by_status' => DB::table('admin_login_logs')
                ->select('status', DB::raw('COUNT(*) as count'))
                ->groupBy('status')
                ->get(),
            'by_ip' => DB::table('admin_login_logs')
                ->select('ip_address', DB::raw('COUNT(*) as count'))
                ->groupBy('ip_address')
                ->orderBy('count', 'desc')
                ->limit(10)
                ->get(),
            'recent_activity' => DB::table('admin_login_logs')
                ->join('admins', 'admin_login_logs.admin_id', '=', 'admins.id')
                ->select([
                    'admins.full_name',
                    'admin_login_logs.status',
                    'admin_login_logs.ip_address',
                    'admin_login_logs.login_time'
                ])
                ->orderBy('admin_login_logs.login_time', 'desc')
                ->limit(10)
                ->get()
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'logs' => $logs,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage)
                ],
                'stats' => $stats
            ]
        ]);
    }

    /**
     * 獲取系統統計資訊
     */
    public function systemStats(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'period' => 'string|in:today,week,month,year'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $period = $request->get('period', 'week');
        
        // 根據期間設定日期範圍
        switch ($period) {
            case 'today':
                $dateFrom = now()->startOfDay();
                break;
            case 'week':
                $dateFrom = now()->startOfWeek();
                break;
            case 'month':
                $dateFrom = now()->startOfMonth();
                break;
            case 'year':
                $dateFrom = now()->startOfYear();
                break;
            default:
                $dateFrom = now()->startOfWeek();
        }

        // 管理員活動統計
        $adminStats = [
            'total_actions' => DB::table('admin_activity_logs')
                ->where('created_at', '>=', $dateFrom)
                ->count(),
            'unique_admins' => DB::table('admin_activity_logs')
                ->where('created_at', '>=', $dateFrom)
                ->distinct('admin_id')
                ->count('admin_id'),
            'top_actions' => DB::table('admin_activity_logs')
                ->select('action', DB::raw('COUNT(*) as count'))
                ->where('created_at', '>=', $dateFrom)
                ->groupBy('action')
                ->orderBy('count', 'desc')
                ->limit(5)
                ->get()
        ];

        // 用戶統計
        $userStats = [
            'total_users' => DB::table('users')->count(),
            'new_users' => DB::table('users')
                ->where('created_at', '>=', $dateFrom)
                ->count(),
            'active_users' => DB::table('users')
                ->where('status', 'active')
                ->count(),
            'banned_users' => DB::table('users')
                ->where('status', 'banned')
                ->count()
        ];

        // 任務統計
        $taskStats = [
            'total_tasks' => DB::table('tasks')->count(),
            'new_tasks' => DB::table('tasks')
                ->where('created_at', '>=', $dateFrom)
                ->count(),
            'completed_tasks' => DB::table('tasks')
                ->join('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
                ->where('task_statuses.code', 'completed')
                ->count(),
            'active_tasks' => DB::table('tasks')
                ->join('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
                ->whereIn('task_statuses.code', ['open', 'in_progress'])
                ->count()
        ];

        // 登入統計
        $loginStats = [
            'total_logins' => DB::table('admin_login_logs')
                ->where('login_time', '>=', $dateFrom)
                ->count(),
            'successful_logins' => DB::table('admin_login_logs')
                ->where('login_time', '>=', $dateFrom)
                ->where('status', 'success')
                ->count(),
            'failed_logins' => DB::table('admin_login_logs')
                ->where('login_time', '>=', $dateFrom)
                ->where('status', 'failed')
                ->count()
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'period' => $period,
                'date_from' => $dateFrom->toDateString(),
                'admin_stats' => $adminStats,
                'user_stats' => $userStats,
                'task_stats' => $taskStats,
                'login_stats' => $loginStats
            ]
        ]);
    }
}