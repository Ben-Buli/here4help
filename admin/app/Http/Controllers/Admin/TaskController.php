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

        /**
         * Search 欄位支援以下查詢：
         * - 任務標題 (Task title)
         * - 任務描述 (Task description)
         * - 任務 ID (Task ID) - UUID 格式
         * - 創建者 ID (Creator ID) - 數字
         * - 參與者 ID (Participant ID) - 數字
         * - 創建者名稱 (Creator name)
         * - 參與者名稱 (Participant name)
         */
        if ($search) {
            $query->where(function($q) use ($search) {
                $q->where('tasks.title', 'LIKE', "%{$search}%")
                  ->orWhere('tasks.description', 'LIKE', "%{$search}%")
                  ->orWhere('tasks.id', 'LIKE', "%{$search}%")
                  ->orWhere('creators.name', 'LIKE', "%{$search}%")
                  ->orWhere('participants.name', 'LIKE', "%{$search}%");
                
                // 如果是純數字，也搜尋 creator_id 和 participant_id
                if (is_numeric($search)) {
                    $q->orWhere('tasks.creator_id', '=', (int)$search)
                      ->orWhere('tasks.participant_id', '=', (int)$search);
                }
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
                      ->get()
                      ->map(function ($t) {
                          // 加入 pending 倒數資訊（若狀態碼為 pending_confirmation 且有 deadline 欄位）
                          if (isset($t->status_code) && $t->status_code === 'pending_confirmation' && isset($t->deadline)) {
                              $remaining = strtotime($t->deadline) - time();
                              $t->countdown_seconds = $remaining > 0 ? $remaining : 0;
                          } else {
                              $t->countdown_seconds = null;
                          }
                          return $t;
                      });

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

        $applicationQuestions = DB::table('application_questions')
            ->select([
                'id',
                'application_question',
                DB::raw("'text' as question_type"),
                'sort_order'
            ])
            ->where('task_id', $id)
            ->orderBy('sort_order')
            ->get();

        $task->application_questions = $applicationQuestions;
        $task->has_pending_reports = DB::table('task_reports')
            ->where('task_id', $id)
            ->where('status', 'pending')
            ->exists();

        return response()->json([
            'success' => true,
            'data' => [
                'task' => (function($task){
                    // 單筆詳情也加入倒數資訊
                    if (isset($task->status_code) && $task->status_code === 'pending_confirmation' && isset($task->deadline)) {
                        $remaining = strtotime($task->deadline) - time();
                        $task->countdown_seconds = $remaining > 0 ? $remaining : 0;
                    } else {
                        $task->countdown_seconds = null;
                    }
                    return $task;
                })($task)
            ]
        ]);
    }

    /**
     * 任務狀態列表（支援 ?active=1/0）
     */
    public function statuses(Request $request)
    {
        $onlyActive = (int) $request->get('active', 1);

        $query = DB::table('task_statuses')
            ->select([
                'id',
                'code',
                'display_name',
                'progress_ratio',
                'sort_order',
                'include_in_unread',
                'is_active',
            ])
            ->orderBy('sort_order')
            ->orderBy('id');

        if ($onlyActive) {
            $query->where('is_active', 1);
        }

        $rows = $query->get();

        return response()->json([
            'success' => true,
            'message' => 'Task statuses retrieved successfully',
            'data' => $rows,
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
            'table_name' => 'tasks',
            'record_id' => $taskId,
            'old_data' => json_encode(['status' => $oldStatus]),
            'new_data' => json_encode(['status' => $newStatus]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now()
        ]);
    }
}
