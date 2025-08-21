<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class UserController extends Controller
{
    /**
     * 獲取用戶列表
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'status' => 'string|in:active,pending_review,rejected,banned,inactive',
            'permission' => 'integer',
            'search' => 'string|max:255',
            'sort_by' => 'string|in:id,name,email,created_at,points,permission',
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
        $status = $request->get('status');
        $permission = $request->get('permission');
        $search = $request->get('search');
        $sortBy = $request->get('sort_by', 'id');
        $sortOrder = $request->get('sort_order', 'desc');

        // 建立查詢
        $query = DB::table('users');

        // 篩選條件
        if ($status) {
            $query->where('status', $status);
        }

        if ($permission !== null) {
            $query->where('permission', $permission);
        }

        if ($search) {
            $query->where(function($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                  ->orWhere('email', 'LIKE', "%{$search}%")
                  ->orWhere('nickname', 'LIKE', "%{$search}%");
            });
        }

        // 總數
        $total = $query->count();

        // 分頁和排序
        $users = $query->orderBy($sortBy, $sortOrder)
                      ->offset(($page - 1) * $perPage)
                      ->limit($perPage)
                      ->get();

        // 統計資訊
        $stats = [
            'total_users' => DB::table('users')->count(),
            'active_users' => DB::table('users')->where('status', 'active')->count(),
            'pending_users' => DB::table('users')->where('status', 'pending_review')->count(),
            'banned_users' => DB::table('users')->where('status', 'banned')->count(),
            'permission_levels' => DB::table('users')
                ->select('permission', DB::raw('COUNT(*) as count'))
                ->groupBy('permission')
                ->orderBy('permission')
                ->get()
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'users' => $users,
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
     * 獲取單一用戶詳細資訊
     */
    public function show(Request $request, $id)
    {
        $user = DB::table('users')->where('id', $id)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        // 獲取用戶相關統計
        $userStats = [
            'total_tasks_created' => DB::table('tasks')->where('creator_id', $id)->count(),
            'total_tasks_applied' => DB::table('task_applications')->where('user_id', $id)->count(),
            'current_points' => $user->points ?? 0,
            'tasks_as_participant' => DB::table('tasks')->where('participant_id', $id)->count(),
        ];

        // 獲取最近活動
        $recentActivities = DB::table('tasks')
            ->leftJoin('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
            ->where('creator_id', $id)
            ->orderBy('tasks.created_at', 'desc')
            ->limit(5)
            ->get(['tasks.id', 'tasks.title', 'task_statuses.display_name as status', 'tasks.created_at']);

        return response()->json([
            'success' => true,
            'data' => [
                'user' => $user,
                'stats' => $userStats,
                'recent_activities' => $recentActivities
            ]
        ]);
    }

    /**
     * 更新用戶狀態
     */
    public function updateStatus(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|string|in:active,pending_review,rejected,banned,inactive',
            'reason' => 'string|max:500'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = DB::table('users')->where('id', $id)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        $oldStatus = $user->status;
        $newStatus = $request->status;
        $reason = $request->get('reason', '');

        // 更新用戶狀態
        DB::table('users')
            ->where('id', $id)
            ->update([
                'status' => $newStatus,
                'updated_at' => now()
            ]);

        // 記錄狀態變更日誌
        $this->logStatusChange($request->user(), $id, $oldStatus, $newStatus, $reason);

        return response()->json([
            'success' => true,
            'message' => 'User status updated successfully',
            'data' => [
                'user_id' => $id,
                'old_status' => $oldStatus,
                'new_status' => $newStatus
            ]
        ]);
    }

    /**
     * 更新用戶權限等級
     */
    public function updatePermission(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'permission' => 'required|integer|in:-4,-3,-2,-1,0,1,99',
            'reason' => 'string|max:500'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $user = DB::table('users')->where('id', $id)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        $oldPermission = $user->permission;
        $newPermission = $request->permission;
        $reason = $request->get('reason', '');

        // 更新用戶權限
        DB::table('users')
            ->where('id', $id)
            ->update([
                'permission' => $newPermission,
                'updated_at' => now()
            ]);

        // 記錄權限變更日誌
        $this->logPermissionChange($request->user(), $id, $oldPermission, $newPermission, $reason);

        return response()->json([
            'success' => true,
            'message' => 'User permission updated successfully',
            'data' => [
                'user_id' => $id,
                'old_permission' => $oldPermission,
                'new_permission' => $newPermission
            ]
        ]);
    }

    /**
     * 批量操作用戶
     */
    public function batchAction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|string|in:activate,deactivate,ban,unban',
            'user_ids' => 'required|array|min:1',
            'user_ids.*' => 'integer|exists:users,id',
            'reason' => 'string|max:500'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $action = $request->action;
        $userIds = $request->user_ids;
        $reason = $request->get('reason', '');

        $statusMap = [
            'activate' => 'active',
            'deactivate' => 'inactive',
            'ban' => 'banned',
            'unban' => 'active'
        ];

        $newStatus = $statusMap[$action];

        // 批量更新
        $affected = DB::table('users')
            ->whereIn('id', $userIds)
            ->update([
                'status' => $newStatus,
                'updated_at' => now()
            ]);

        // 記錄批量操作日誌
        $this->logBatchAction($request->user(), $action, $userIds, $reason);

        return response()->json([
            'success' => true,
            'message' => "Batch {$action} completed successfully",
            'data' => [
                'action' => $action,
                'affected_users' => $affected,
                'user_ids' => $userIds
            ]
        ]);
    }

    /**
     * 記錄狀態變更
     */
    private function logStatusChange($admin, $userId, $oldStatus, $newStatus, $reason)
    {
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => 'update_user_status',
            'resource_type' => 'users',
            'resource_id' => $userId,
            'old_values' => json_encode(['status' => $oldStatus]),
            'new_values' => json_encode(['status' => $newStatus]),
            'description' => "Changed user status from {$oldStatus} to {$newStatus}. Reason: {$reason}",
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now(),
            'updated_at' => now()
        ]);
    }

    /**
     * 記錄權限變更
     */
    private function logPermissionChange($admin, $userId, $oldPermission, $newPermission, $reason)
    {
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => 'update_user_permission',
            'resource_type' => 'users',
            'resource_id' => $userId,
            'old_values' => json_encode(['permission' => $oldPermission]),
            'new_values' => json_encode(['permission' => $newPermission]),
            'description' => "Changed user permission from {$oldPermission} to {$newPermission}. Reason: {$reason}",
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now(),
            'updated_at' => now()
        ]);
    }

    /**
     * 記錄批量操作
     */
    private function logBatchAction($admin, $action, $userIds, $reason)
    {
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => 'batch_user_action',
            'resource_type' => 'users',
            'description' => "Batch {$action} on " . count($userIds) . " users. IDs: " . implode(',', $userIds) . ". Reason: {$reason}",
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now(),
            'updated_at' => now()
        ]);
    }
}
