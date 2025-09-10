<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminActivityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class DisputeController extends Controller
{
    /**
     * 獲取申訴列表（以 tasks.status_id = 4 為爭議來源）
     */
    public function index(Request $request)
    {
        try {
            $page = (int) $request->get('page', 1);
            $perPage = (int) $request->get('per_page', 15);
            $search = $request->get('search');

            // 以 tasks 當作爭議來源：status_id = 4 代表 dispute
            $query = DB::table('tasks as t')
                ->leftJoin('users as creator', 't.creator_id', '=', 'creator.id')
                ->leftJoin('users as participant', 't.participant_id', '=', 'participant.id')
                ->select([
                    't.id as task_id',
                    't.id as id', // 對齊前端預期的 dispute.id
                    't.title',
                    't.description',
                    't.reward_point',
                    't.creator_id',
                    't.participant_id',
                    't.created_at',
                    't.updated_at',
                    'creator.name as creator_name',
                    'creator.email as creator_email',
                    'participant.name as participant_name',
                    'participant.email as participant_email',
                ])
                ->where('t.status_id', 4);

            // 搜尋條件
            if ($search) {
                $query->where(function ($q) use ($search) {
                    $q->where('t.title', 'LIKE', "%{$search}%")
                      ->orWhere('creator.name', 'LIKE', "%{$search}%")
                      ->orWhere('participant.name', 'LIKE', "%{$search}%");
                });
            }

            $total = $query->count();

            $rows = $query->orderBy('t.created_at', 'desc')
                ->offset(($page - 1) * $perPage)
                ->limit($perPage)
                ->get();

            // 將任務映射為前端期望的爭議物件結構
            $items = $rows->map(function ($r) {
                return [
                    'id' => $r->id,
                    'task_id' => $r->task_id,
                    'dispute_title' => $r->title,
                    'description' => $r->description,
                    // 沒有額外的爭議子狀態，預設為 submitted（前端顏色/標籤可用）
                    'status' => 'submitted',
                    'created_at' => $r->created_at,
                    'updated_at' => $r->updated_at,
                    'task' => [
                        'id' => $r->task_id,
                        'title' => $r->title,
                        'reward_point' => $r->reward_point,
                        'creator_id' => $r->creator_id,
                        'participant_id' => $r->participant_id,
                        'creator_name' => $r->creator_name,
                        'participant_name' => $r->participant_name,
                    ],
                    // 以任務建立者視為發起者（無 task_disputes 表時）
                    'submitter' => [
                        'id' => $r->creator_id,
                        'name' => $r->creator_name,
                        'email' => $r->creator_email,
                    ],
                ];
            });

            // 統計資料（基於 tasks.status_id = 4）
            $stats = [
                'total_disputes' => $total,
                'submitted_count' => $total,
                'in_progress_count' => 0,
                'resolved_count' => 0,
            ];

            return response()->json([
                'success' => true,
                'data' => [
                    'items' => $items,
                    'pagination' => [
                        'current_page' => $page,
                        'per_page' => $perPage,
                        'total' => $total,
                        'last_page' => (int) ceil($total / $perPage),
                    ],
                    'stats' => $stats,
                ],
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch disputes: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 獲取申訴詳情（基於 tasks.status_id = 4）
     */
    public function show($id)
    {
        try {
            // 改為直接查詢 tasks 表，$id 為 task_id
            $dispute = DB::table('tasks as t')
                ->leftJoin('users as creator', 't.creator_id', '=', 'creator.id')
                ->leftJoin('users as participant', 't.participant_id', '=', 'participant.id')
                ->leftJoin('task_statuses as ts', 't.status_id', '=', 'ts.id')
                ->select([
                    't.id as task_id',
                    't.title as task_title',
                    't.description as task_description',
                    't.reward_point',
                    't.location',
                    't.task_date',
                    't.created_at as task_created_at',
                    't.updated_at',
                    'ts.display_name as task_status',
                    'creator.name as creator_name',
                    'creator.email as creator_email',
                    'creator.phone as creator_phone',
                    'participant.name as participant_name',
                    'participant.email as participant_email',
                    'participant.phone as participant_phone'
                ])
                ->where('t.id', $id)
                ->where('t.status_id', 4) // 確保是爭議任務
                ->first();

            if (!$dispute) {
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute not found'
                ], 404);
            }

            // 獲取任務相關日誌（如果 task_logs 表存在）
            $taskLogs = [];
            try {
                $taskLogs = DB::table('task_logs')
                    ->where('task_id', $dispute->task_id)
                    ->orderBy('created_at', 'desc')
                    ->get();
            } catch (\Exception $e) {
                // task_logs 表可能不存在，忽略錯誤
            }

            // 獲取管理員活動日誌（替代 dispute_status_logs）
            $disputeLogs = [];
            try {
                $disputeLogs = DB::table('admin_activity_logs as aal')
                    ->where('aal.table_name', 'tasks')
                    ->where('aal.record_id', $id)
                    ->orderBy('aal.created_at', 'desc')
                    ->get();
            } catch (\Exception $e) {
                // 忽略錯誤
            }

            return response()->json([
                'success' => true,
                'data' => [
                    'dispute' => $dispute,
                    'task_logs' => $taskLogs,
                    'dispute_logs' => $disputeLogs
                ]
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch dispute details: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 更新申訴狀態（基於 tasks 表的 status_id）
     */
    public function updateStatus(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|in:resolve,reject,reopen',
            'notes' => 'nullable|string|max:1000',
            'resolution' => 'nullable|string|max:1000'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            // 檢查任務是否存在且為爭議狀態
            $task = DB::table('tasks')->where('id', $id)->where('status_id', 4)->first();
            if (!$task) {
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute task not found'
                ], 404);
            }

            $action = $request->action;
            $adminId = $request->user()->id;
            
            // 根據動作決定新的 status_id（基於實際 task_statuses 表）
            $newStatusId = match($action) {
                'resolve' => 5, // 5 = "Completed" - 爭議解決，任務完成
                'reject' => 7,  // 7 = "Rejected" - 爭議被拒絕
                'reopen' => 4,  // 4 = "Dispute" - 重新開啟爭議
                default => 4
            };

            // 更新任務狀態
            DB::table('tasks')
                ->where('id', $id)
                ->update([
                    'status_id' => $newStatusId,
                    'updated_at' => now()
                ]);

            // 不使用 dispute_status_logs，改用 admin_activity_logs

            // 記錄管理員活動日誌
            DB::table('admin_activity_logs')->insert([
                'admin_id' => $adminId,
                'action' => "dispute_{$action}",
                'table_name' => 'tasks',
                'record_id' => $id,
                'old_data' => json_encode(['status_id' => $task->status_id]),
                'new_data' => json_encode([
                    'status_id' => $newStatusId,
                    'action' => $action,
                    'notes' => $request->notes,
                    'resolution' => $request->resolution
                ]),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now()
            ]);

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => "Dispute {$action} completed successfully",
                'data' => [
                    'task_id' => $id,
                    'old_status_id' => $task->status_id,
                    'new_status_id' => $newStatusId,
                    'action' => $action,
                    'updated_at' => now()->toISOString()
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollback();
            
            return response()->json([
                'success' => false,
                'message' => 'Failed to update dispute status: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 批量操作申訴（基於 tasks 表）
     */
    public function batchAction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|in:resolve,reject,reopen',
            'task_ids' => 'required|array|min:1',
            'task_ids.*' => 'string|exists:tasks,id',
            'notes' => 'nullable|string|max:1000'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            DB::beginTransaction();

            $action = $request->action;
            $taskIds = $request->task_ids;
            $adminId = $request->user()->id;
            
            $statusMap = [
                'resolve' => 5, // 5 = "Completed" - 爭議解決，任務完成
                'reject' => 7,  // 7 = "Rejected" - 爭議被拒絕
                'reopen' => 4   // 4 = "Dispute" - 重新開啟爭議
            ];
            
            $newStatusId = $statusMap[$action];
            $successCount = 0;

            foreach ($taskIds as $taskId) {
                // 獲取當前任務（確保是爭議狀態）
                $task = DB::table('tasks')->where('id', $taskId)->where('status_id', 4)->first();
                if (!$task) continue;

                $oldStatusId = $task->status_id;

                // 更新任務狀態
                DB::table('tasks')
                    ->where('id', $taskId)
                    ->update([
                        'status_id' => $newStatusId,
                        'updated_at' => now()
                    ]);

                // 記錄管理員活動日誌
                DB::table('admin_activity_logs')->insert([
                    'admin_id' => $adminId,
                    'action' => "dispute_batch_{$action}",
                    'table_name' => 'tasks',
                    'record_id' => $taskId,
                    'old_data' => json_encode(['status_id' => $oldStatusId]),
                    'new_data' => json_encode([
                        'status_id' => $newStatusId,
                        'action' => $action,
                        'notes' => $request->notes,
                        'batch_action' => true
                    ]),
                    'ip_address' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                    'created_at' => now()
                ]);

                $successCount++;
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => "Successfully processed {$successCount} disputes",
                'data' => [
                    'processed_count' => $successCount,
                    'total_count' => count($taskIds),
                    'action' => $action,
                    'new_status_id' => $newStatusId
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollback();
            
            return response()->json([
                'success' => false,
                'message' => 'Batch operation failed: ' . $e->getMessage()
            ], 500);
        }
    }
}
