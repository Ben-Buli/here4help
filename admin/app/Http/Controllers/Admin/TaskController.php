<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class TaskController extends Controller
{
    /**
     * 獲取任務列表
     */
    public function index(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:100',
            'status_id' => 'integer',
            'creator_id' => 'integer',
            'participant_id' => 'integer',
            'search' => 'string|max:255',
            'date_from' => 'date',
            'date_to' => 'date',
            'sort_by' => 'string|in:id,title,created_at,task_date,reward_point',
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
        $statusId = $request->get('status_id');
        $creatorId = $request->get('creator_id');
        $participantId = $request->get('participant_id');
        $search = $request->get('search');
        $dateFrom = $request->get('date_from');
        $dateTo = $request->get('date_to');
        $sortBy = $request->get('sort_by', 'created_at');
        $sortOrder = $request->get('sort_order', 'desc');

        // 建立查詢
        $query = DB::table('tasks')
            ->leftJoin('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
            ->leftJoin('users as creators', 'tasks.creator_id', '=', 'creators.id')
            ->leftJoin('users as participants', 'tasks.participant_id', '=', 'participants.id')
            ->select([
                'tasks.*',
                'task_statuses.display_name as status_name',
                'task_statuses.code as status_code',
                'creators.name as creator_name',
                'creators.email as creator_email',
                'participants.name as participant_name',
                'participants.email as participant_email'
            ]);

        // 篩選條件
        if ($statusId) {
            $query->where('tasks.status_id', $statusId);
        }

        if ($creatorId) {
            $query->where('tasks.creator_id', $creatorId);
        }

        if ($participantId) {
            $query->where('tasks.participant_id', $participantId);
        }

        if ($search) {
            $query->where(function($q) use ($search) {
                $q->where('tasks.title', 'LIKE', "%{$search}%")
                  ->orWhere('tasks.description', 'LIKE', "%{$search}%")
                  ->orWhere('creators.name', 'LIKE', "%{$search}%")
                  ->orWhere('participants.name', 'LIKE', "%{$search}%");
            });
        }

        if ($dateFrom) {
            $query->where('tasks.task_date', '>=', $dateFrom);
        }

        if ($dateTo) {
            $query->where('tasks.task_date', '<=', $dateTo);
        }

        // 總數
        $total = $query->count();

        // 分頁和排序
        $tasks = $query->orderBy("tasks.{$sortBy}", $sortOrder)
                      ->offset(($page - 1) * $perPage)
                      ->limit($perPage)
                      ->get();

        // 統計資訊
        $stats = [
            'total_tasks' => DB::table('tasks')->count(),
            'by_status' => DB::table('tasks')
                ->join('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
                ->select('task_statuses.display_name', 'task_statuses.id', DB::raw('COUNT(*) as count'))
                ->groupBy('task_statuses.id', 'task_statuses.display_name')
                ->orderBy('task_statuses.id')
                ->get(),
            'total_points' => DB::table('tasks')->sum(DB::raw('CAST(reward_point as UNSIGNED)')),
            'avg_points' => DB::table('tasks')->avg(DB::raw('CAST(reward_point as UNSIGNED)')),
        ];

        return response()->json([
            'success' => true,
            'data' => [
                'tasks' => $tasks,
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
     * 獲取單一任務詳細資訊
     */
    public function show(Request $request, $id)
    {
        $task = DB::table('tasks')
            ->leftJoin('task_statuses', 'tasks.status_id', '=', 'task_statuses.id')
            ->leftJoin('users as creators', 'tasks.creator_id', '=', 'creators.id')
            ->leftJoin('users as participants', 'tasks.participant_id', '=', 'participants.id')
            ->select([
                'tasks.*',
                'task_statuses.display_name as status_name',
                'task_statuses.code as status_code',
                'creators.name as creator_name',
                'creators.email as creator_email',
                'creators.phone as creator_phone',
                'participants.name as participant_name',
                'participants.email as participant_email',
                'participants.phone as participant_phone'
            ])
            ->where('tasks.id', $id)
            ->first();

        if (!$task) {
            return response()->json([
                'success' => false,
                'message' => 'Task not found'
            ], 404);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'task' => $task
            ]
        ]);
    }

    /**
     * 更新任務狀態
     */
    public function updateStatus(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'status_id' => 'required|integer|exists:task_statuses,id',
            'reason' => 'string|max:500'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $task = DB::table('tasks')->where('id', $id)->first();

        if (!$task) {
            return response()->json([
                'success' => false,
                'message' => 'Task not found'
            ], 404);
        }

        $oldStatusId = $task->status_id;
        $newStatusId = $request->status_id;
        $reason = $request->get('reason', '');

        // 獲取狀態名稱
        $oldStatus = DB::table('task_statuses')->where('id', $oldStatusId)->first();
        $newStatus = DB::table('task_statuses')->where('id', $newStatusId)->first();

        // 更新任務狀態
        DB::table('tasks')
            ->where('id', $id)
            ->update([
                'status_id' => $newStatusId,
                'updated_at' => now()
            ]);

        // 記錄狀態變更日誌
        $this->logStatusChange(
            $request->user(), 
            $id, 
            $oldStatus->display_name, 
            $newStatus->display_name, 
            $reason
        );

        return response()->json([
            'success' => true,
            'message' => 'Task status updated successfully',
            'data' => [
                'task_id' => $id,
                'old_status' => $oldStatus->display_name,
                'new_status' => $newStatus->display_name
            ]
        ]);
    }

    /**
     * 記錄狀態變更
     */
    private function logStatusChange($admin, $taskId, $oldStatus, $newStatus, $reason)
    {
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => 'update_task_status',
            'resource_type' => 'tasks',
            'resource_id' => $taskId,
            'old_values' => json_encode(['status' => $oldStatus]),
            'new_values' => json_encode(['status' => $newStatus]),
            'description' => "Changed task status from {$oldStatus} to {$newStatus}. Reason: {$reason}",
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now(),
            'updated_at' => now()
        ]);
    }
}