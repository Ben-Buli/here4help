<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\AdminActivityLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;
use Illuminate\Support\Facades\Log;

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
            // 注意：因為 task_id 是 UUID 字串，而 record_id 是整數，
            // 所以需要透過 new_data JSON 欄位來查詢
            $disputeLogs = [];
            try {
                $disputeLogs = DB::table('admin_activity_logs as aal')
                    ->where('aal.table_name', 'tasks')
                    ->where(function($query) use ($id) {
                        $query->where('aal.new_data', 'LIKE', '%"task_id":"' . $id . '"%')
                              ->orWhere('aal.old_data', 'LIKE', '%"task_id":"' . $id . '"%');
                    })
                    ->orderBy('aal.created_at', 'desc')
                    ->get();
            } catch (\Exception $e) {
                // 忽略錯誤
                Log::warning("Failed to fetch dispute logs for task {$id}: " . $e->getMessage());
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
                    'task_id' => $id,
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
                        'task_id' => $taskId,
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

    /**
     * 獲取任務爭議聊天室
     * GET /api/admin/task-disputes/{taskId}/chat-room
     */
    public function chatRoom(Request $request, $taskId)
    {
        try {
            // 步驟 1: 驗證管理員權限
            Log::info("Step 1: Checking admin authentication for task {$taskId}");
            $admin = $request->user();
            if (!$admin) {
                Log::warning("Admin authentication failed for task {$taskId}");
                return response()->json([
                    'success' => false,
                    'message' => 'Unauthorized - Admin authentication required'
                ], 401);
            }
            Log::info("Admin authenticated: {$admin->id}");

            // 步驟 2: 獲取任務基本資訊
            Log::info("Step 2: Fetching task {$taskId}");
            $task = DB::table('tasks')->where('id', $taskId)->first();
            if (!$task) {
                Log::warning("Task not found: {$taskId}");
                return response()->json([
                    'success' => false,
                    'message' => 'Task not found'
                ], 404);
            }
            Log::info("Task found: {$taskId}, creator: {$task->creator_id}, participant: " . ($task->participant_id ?? 'null'));

            // 步驟 3: 獲取爭議事件資訊
            Log::info("Step 3: Fetching dispute event for task {$taskId}");
            $dispute = DB::table('task_dispute_events as tde')
                ->where('task_id', $taskId)
                ->orderBy('created_at', 'desc')
                ->first();
            Log::info("Dispute found: " . ($dispute ? "ID {$dispute->id}" : "none"));

            // 步驟 4: 獲取聊天室資訊（優先匹配 participant_id）
            Log::info("Step 4: Fetching chat room for task {$taskId}");
            
            // 如果任務有 participant_id，優先查找對應的聊天室
            $chatRoomQuery = DB::table('chat_rooms as cr')
                ->leftJoin('users as creator', function($join) {
                    $join->on('cr.creator_id', '=', 'creator.id');
                })
                ->leftJoin('users as participant', function($join) {
                    $join->on('cr.participant_id', '=', 'participant.id');
                })
                ->select([
                    'cr.id', 'cr.type', 'cr.task_id', 'cr.creator_id', 'cr.participant_id', 'cr.created_at',
                    'creator.name as creator_name', 'creator.avatar_url as creator_avatar',
                    'participant.name as participant_name', 'participant.avatar_url as participant_avatar'
                ])
                ->where('cr.task_id', $taskId);
            
            // 如果任務有 participant_id，則匹配對應的聊天室
            if ($task->participant_id) {
                $chatRoomQuery->where('cr.participant_id', $task->participant_id);
                Log::info("Filtering chat room by participant_id: {$task->participant_id}");
            }
            
            $chatRoom = $chatRoomQuery->orderBy('cr.created_at', 'desc')->first();

            if (!$chatRoom) {
                Log::warning("Chat room not found for task {$taskId}");
                return response()->json([
                    'success' => false,
                    'message' => 'Chat room not found'
                ], 404);
            }
            Log::info("Chat room found: ID {$chatRoom->id}");

            // 步驟 5: 獲取聊天訊息
            Log::info("Step 5: Fetching messages for chat room {$chatRoom->id}");
            $messages = DB::table('chat_messages as cm')
                ->leftJoin('users as u', 'cm.from_user_id', '=', 'u.id')
                ->select([
                    'cm.id', 'cm.room_id', 'cm.from_user_id', 'cm.content', 'cm.kind',
                    'cm.media_url', 'cm.mime_type', 'cm.created_at',
                    'u.name as user_name', 'u.avatar_url as user_avatar'
                ])
                ->where('cm.room_id', $chatRoom->id)
                ->orderBy('cm.created_at', 'asc')
                ->get();
            Log::info("Messages fetched: " . count($messages));

            // 步驟 6: 獲取用戶資訊
            Log::info("Step 6: Fetching user info");
            $userIds = array_unique(array_filter([$task->creator_id, $task->participant_id]));
            $users = [];
            if (!empty($userIds)) {
                $userResults = DB::table('users')
                    ->select(['id', 'name', 'email', 'avatar_url'])
                    ->whereIn('id', $userIds)
                    ->get();
                
                foreach ($userResults as $user) {
                    $users[$user->id] = [
                        'id' => (int)$user->id,
                        'name' => $user->name,
                        'email' => $user->email,
                        'avatar_url' => $user->avatar_url
                    ];
                }
            }
            Log::info("Users fetched: " . count($users));

            // 步驟 7: 記錄管理員查看操作（修正 record_id 問題）
            Log::info("Step 7: Logging admin activity");
            try {
                AdminActivityLog::create([
                    'admin_id' => $admin->id,
                    'action' => 'view',
                    'table_name' => 'task_disputes',
                    'record_id' => $dispute ? $dispute->id : null, // 使用 dispute_id（整數）或 NULL，而非 task_id（UUID）
                    'description' => "Admin viewed dispute chat room for task ID: {$taskId}",
                    'new_data' => json_encode([
                        'task_id' => $taskId,
                        'chat_room_id' => $chatRoom->id,
                        'dispute_id' => $dispute ? $dispute->id : null
                    ]),
                    'ip_address' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]);
                Log::info("Admin activity logged successfully");
            } catch (\Exception $logException) {
                Log::error("Failed to log admin activity: " . $logException->getMessage());
                // 繼續執行，不因為日誌失敗而中斷
            }

            // 步驟 8: 返回響應
            Log::info("Step 8: Returning response");
            return response()->json([
                'success' => true,
                'data' => [
                    'chat_room' => [
                        'id' => $chatRoom->id,
                        'type' => $chatRoom->type,
                        'task_id' => $chatRoom->task_id,
                        'creator_id' => (int)$chatRoom->creator_id,
                        'participant_id' => (int)$chatRoom->participant_id,
                        'created_at' => $chatRoom->created_at
                    ],
                    'task' => [
                        'id' => $task->id,
                        'title' => $task->title,
                        'creator_id' => (int)$task->creator_id,
                        'participant_id' => $task->participant_id ? (int)$task->participant_id : null,
                        'reward_point' => (int)$task->reward_point,
                    ],
                    'messages' => array_map(function($message) {
                        return [
                            'id' => (int)$message->id,
                            'room_id' => $message->room_id,
                            'from_user_id' => $message->from_user_id ? (int)$message->from_user_id : null,
                            'content' => $message->content,
                            'kind' => $message->kind,
                            'created_at' => $message->created_at,
                            'user_name' => $message->user_name ?? 'System',
                            'user_avatar' => $message->user_avatar,
                            'media_url' => $message->media_url,
                            'mime_type' => $message->mime_type,
                        ];
                    }, $messages->toArray()),
                    'users' => $users,
                    'dispute_info' => $dispute ? [
                        'id' => (int)$dispute->id,
                        'title' => $dispute->title,
                        'description' => $dispute->description,
                        'status' => $dispute->status,
                        'created_at' => $dispute->created_at,
                        'updated_at' => $dispute->updated_at
                    ] : null,
                    'meta' => [
                        'total_messages' => count($messages),
                        'viewed_by_admin' => $admin->username ?? $admin->full_name,
                        'admin_id' => (int)$admin->id,
                        'viewed_at' => now()->toDateTimeString()
                    ]
                ]
            ]);

        } catch (\Exception $e) {
            Log::error('Error in dispute chat room view', [
                'task_id' => $taskId,
                'error_message' => $e->getMessage(),
                'error_file' => $e->getFile(),
                'error_line' => $e->getLine(),
                'stack_trace' => $e->getTraceAsString()
            ]);
            
            return response()->json([
                'success' => false,
                'message' => 'Server error occurred',
                'debug' => config('app.debug') ? [
                    'error' => $e->getMessage(),
                    'file' => $e->getFile(),
                    'line' => $e->getLine()
                ] : null
            ], 500);
        }
    }

    /**
     * 解決任務爭議（提供給 Vue Admin 使用）
     * 注意：Flutter App 仍使用 legacy PHP API (backend/api/admin/task-disputes/resolve.php)
     * POST /api/admin/task-disputes/resolve
     */
    public function resolveDispute(Request $request)
    {
        try {
            $validator = Validator::make($request->all(), [
                'dispute_id' => 'required|string',
                'decision' => 'required|in:completed,back_to_progress,reset',
                'note' => 'required|string|max:1000'
            ]);

            if ($validator->fails()) {
                return response()->json([
                    'success' => false,
                    'message' => 'Validation failed',
                    'errors' => $validator->errors()
                ], 422);
            }

            $disputeId = $request->dispute_id;
            $decision = $request->decision;
            $note = $request->note;
            $admin = $request->user();
            $now = now();

            DB::beginTransaction();

            $dispute = DB::table('task_dispute_events as tde')
                ->join('tasks as t', 'tde.task_id', '=', 't.id')
                ->leftJoin('task_statuses as ts', 't.status_id', '=', 'ts.id')
                ->select([
                    'tde.id as dispute_id',
                    'tde.status as dispute_status',
                    'tde.decision_result',
                    'tde.user_id as dispute_user_id',
                    'tde.task_id',
                    'tde.title',
                    'tde.description',
                    'tde.created_at',
                    'tde.updated_at',
                    't.reward_point',
                    't.creator_id',
                    't.participant_id',
                    't.title as task_title',
                    't.status_id as current_task_status_id',
                    'ts.code as current_task_status_code',
                ])
                ->where('tde.id', $disputeId)
                ->lockForUpdate()
                ->first();

            if (!$dispute) {
                DB::rollBack();
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute not found'
                ], 404);
            }

            if ($dispute->dispute_status === 'resolved') {
                DB::rollBack();
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute has already been resolved'
                ], 409);
            }

            $statusMap = DB::table('task_statuses')
                ->whereIn('code', ['open', 'in_progress', 'completed'])
                ->pluck('id', 'code')
                ->map(fn($id) => (int)$id)
                ->toArray();

            foreach (['open', 'in_progress', 'completed'] as $code) {
                if (!isset($statusMap[$code])) {
                    DB::rollBack();
                    return response()->json([
                        'success' => false,
                        'message' => "Task status '{$code}' is not configured in task_statuses table"
                    ], 500);
                }
            }

            $taskId = $dispute->task_id;
            $creatorId = (int)$dispute->creator_id;
            $participantId = $dispute->participant_id ? (int)$dispute->participant_id : null;
            $taskTitle = $dispute->task_title ?? 'Task dispute';
            $payoutMeta = null;
            $newTaskStatusId = (int)$dispute->current_task_status_id;
            $newTaskStatusCode = $dispute->current_task_status_code;

            switch ($decision) {
                case 'completed':
                    if (!$participantId) {
                        throw new \RuntimeException('Task has no participant to reward');
                    }
                    $amount = (int)round($dispute->reward_point ?? 0);
                    if ($amount <= 0) {
                        throw new \RuntimeException('Task reward must be greater than zero to complete');
                    }

                    DB::table('tasks')->where('id', $taskId)->update([
                        'status_id' => $statusMap['completed'],
                        'updated_at' => $now
                    ]);

                    DB::table('task_applications')
                        ->where('task_id', $taskId)
                        ->where('user_id', $participantId)
                        ->update([
                            'status' => 'completed',
                            'updated_at' => $now
                        ]);

                    DB::table('users')->where('id', $creatorId)->decrement('points', $amount);
                    DB::table('users')->where('id', $participantId)->increment('points', $amount);

                    DB::table('point_transactions')->insert([
                        [
                            'user_id' => $creatorId,
                            'transaction_type' => 'spend',
                            'amount' => -abs($amount),
                            'description' => "Task payment: {$taskTitle}",
                            'related_task_id' => $taskId,
                            'status' => 'completed',
                            'created_at' => $now,
                        ],
                        [
                            'user_id' => $participantId,
                            'transaction_type' => 'earn',
                            'amount' => abs($amount),
                            'description' => "Task completed: {$taskTitle}",
                            'related_task_id' => $taskId,
                            'status' => 'completed',
                            'created_at' => $now,
                        ],
                    ]);

                    $metadata = [
                        'task_id' => $taskId,
                        'task_title' => $taskTitle,
                        'amount' => $amount,
                        'decision' => $decision,
                        'dispute_id' => $disputeId,
                    ];
                    $this->logUserActivity($request, $creatorId, 'task_completion_payment', $admin->id, $metadata);
                    $this->logUserActivity($request, $participantId, 'task_completion_earning', $admin->id, $metadata);

                    $payoutMeta = [
                        'amount' => $amount,
                        'from_user_id' => $creatorId,
                        'to_user_id' => $participantId,
                    ];
                    $newTaskStatusId = $statusMap['completed'];
                    $newTaskStatusCode = 'completed';
                    break;

                case 'back_to_progress':
                    DB::table('tasks')->where('id', $taskId)->update([
                        'status_id' => $statusMap['in_progress'],
                        'updated_at' => $now
                    ]);

                    if ($participantId) {
                        DB::table('task_applications')
                            ->where('task_id', $taskId)
                            ->where('user_id', $participantId)
                            ->update([
                                'status' => 'in_progress',
                                'updated_at' => $now
                            ]);
                    }

                    $newTaskStatusId = $statusMap['in_progress'];
                    $newTaskStatusCode = 'in_progress';
                    break;

                case 'reset':
                    DB::table('tasks')->where('id', $taskId)->update([
                        'status_id' => $statusMap['open'],
                        'participant_id' => null,
                        'updated_at' => $now
                    ]);

                    if ($participantId) {
                        DB::table('task_applications')
                            ->where('task_id', $taskId)
                            ->where('user_id', $participantId)
                            ->update([
                                'status' => 'rejected',
                                'updated_at' => $now
                            ]);
                    }

                    $newTaskStatusId = $statusMap['open'];
                    $newTaskStatusCode = 'open';
                    break;
            }

            DB::table('task_dispute_events')
                ->where('id', $disputeId)
                ->update([
                    'status' => 'resolved',
                    'decision_result' => $decision,
                    'decision_note' => $note,
                    'admin_id' => $admin->id,
                    'updated_at' => $now
                ]);

            DB::table('task_dispute_event_logs')->insert([
                'event_id' => is_numeric($disputeId) ? (int)$disputeId : $disputeId,
                'admin_id' => $admin->id,
                'old_status' => $dispute->dispute_status,
                'new_status' => 'resolved',
                'old_decision' => $dispute->decision_result,
                'new_decision' => $decision,
                'note' => $note,
                'created_at' => $now
            ]);

            try {
                AdminActivityLog::create([
                    'admin_id' => $admin->id,
                    'action' => 'resolve',
                    'table_name' => 'task_dispute_events',
                    'record_id' => $disputeId,
                    'description' => "Admin resolved dispute {$disputeId} with decision: {$decision}",
                    'old_data' => json_encode([
                        'status' => $dispute->dispute_status,
                        'decision' => $dispute->decision_result
                    ]),
                    'new_data' => json_encode([
                        'dispute_id' => $disputeId,
                        'decision' => $decision,
                        'note' => $note,
                        'task_status_code' => $newTaskStatusCode
                    ]),
                    'ip_address' => $request->ip(),
                    'user_agent' => $request->userAgent(),
                ]);
            } catch (\Exception $logException) {
                Log::error("Failed to log admin activity for resolve: " . $logException->getMessage());
            }

            $chatRoom = DB::table('chat_rooms')
                ->where('task_id', $taskId)
                ->orderBy('created_at', 'desc')
                ->first();

            if ($chatRoom) {
                try {
                    DB::table('chat_messages')->insert([
                        'room_id' => $chatRoom->id,
                        'from_user_id' => $dispute->dispute_user_id,
                        'content' => "Dispute resolved: {$decision}\nAdmin note: {$note}",
                        'kind' => 'system',
                        'created_at' => $now,
                    ]);
                } catch (\Exception $messageException) {
                    Log::warning('Failed to insert system message for dispute resolution', [
                        'task_id' => $taskId,
                        'error' => $messageException->getMessage(),
                    ]);
                }
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Dispute resolved successfully',
                'data' => [
                    'dispute_id' => $disputeId,
                    'decision' => $decision,
                    'note' => $note,
                    'task_status_code' => $newTaskStatusCode,
                    'task_status_id' => $newTaskStatusId,
                    'resolved_by' => $admin->username ?? $admin->full_name,
                    'resolved_at' => $now->toDateTimeString(),
                    'payout' => $payoutMeta,
                ]
            ]);

        } catch (\Exception $e) {
            DB::rollBack();
            Log::error('Error resolving dispute: ' . $e->getMessage());
            return response()->json([
                'success' => false,
                'message' => 'Server error occurred'
            ], 500);
        }
    }

    private function logUserActivity(Request $request, int $userId, string $action, int $adminId, array $metadata = []): void
    {
        try {
            DB::table('user_active_log')->insert([
                'user_id' => $userId,
                'actor_type' => 'admin',
                'actor_id' => $adminId,
                'action' => $action,
                'field' => 'points',
                'old_value' => null,
                'new_value' => null,
                'reason' => 'admin_dispute_resolution',
                'ip' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'metadata' => json_encode($metadata),
                'created_at' => now()
            ]);
        } catch (\Throwable $e) {
            Log::warning('Failed to write user_active_log for dispute resolution', [
                'user_id' => $userId,
                'action' => $action,
                'error' => $e->getMessage()
            ]);
        }
    }

    /**
     * GET /admin/disputes/{disputeId}/chat-messages
     * 獲取爭議聊天記錄
     */
    public function getChatMessages(Request $request, $disputeId)
    {
        $admin = $request->user();
        
        // 獲取爭議資訊（修正表名為 task_dispute_events）
        $dispute = DB::table('task_dispute_events as tde')
            ->leftJoin('tasks as t', 'tde.task_id', '=', 't.id')
            ->leftJoin('users as creator', 't.creator_id', '=', 'creator.id')
            ->leftJoin('users as participant', 't.participant_id', '=', 'participant.id')
            ->leftJoin('users as submitter', 'tde.user_id', '=', 'submitter.id')
            ->select([
                'tde.id as dispute_id',
                'tde.title as dispute_title',
                'tde.description as dispute_description',
                'tde.status as dispute_status',
                'tde.created_at as dispute_created_at',
                'tde.updated_at as dispute_updated_at',
                't.id as task_id',
                't.title as task_title',
                't.reward_point',
                't.creator_id',  // 添加 creator_id
                't.participant_id',  // 添加 participant_id
                'creator.name as creator_name',
                'creator.avatar_url as creator_avatar',
                'participant.name as participant_name',
                'participant.avatar_url as participant_avatar',
                'submitter.name as submitter_name',
                'submitter.email as submitter_email'
            ])
            ->where('tde.id', $disputeId)
            ->first();

        if (!$dispute) {
            return response()->json([
                'success' => false,
                'message' => 'Dispute not found'
            ], 404);
        }

        // 獲取聊天室資訊
        $chatRoom = DB::table('chat_rooms')
            ->where('task_id', $dispute->task_id)
            ->orderBy('created_at', 'desc')
            ->first();

        if (!$chatRoom) {
            return response()->json([
                'success' => false,
                'message' => 'Chat room not found for this dispute'
            ], 404);
        }

        // 獲取聊天訊息
        $messages = DB::table('chat_messages as cm')
            ->leftJoin('users as u', 'cm.from_user_id', '=', 'u.id')
            ->select([
                'cm.id', 'cm.room_id', 'cm.from_user_id', 'cm.content', 'cm.kind',
                'cm.media_url', 'cm.mime_type', 'cm.created_at',
                'u.name as sender_name', 'u.avatar_url as sender_avatar'
            ])
            ->where('cm.room_id', $chatRoom->id)
            ->orderBy('cm.created_at', 'asc')
            ->get();

        // 處理訊息格式，添加發送者角色
        $processedMessages = $messages->map(function($message) use ($dispute) {
            $senderRole = 'unknown';
            if ($message->from_user_id) {
                if ($message->from_user_id == $dispute->creator_id) {
                    $senderRole = 'creator';
                } elseif ($message->from_user_id == $dispute->participant_id) {
                    $senderRole = 'participant';
                }
            }
            
            return [
                'id' => (int)$message->id,
                'room_id' => $message->room_id,
                'from_user_id' => $message->from_user_id ? (int)$message->from_user_id : null,
                'content' => $message->content,
                'kind' => $message->kind,
                'created_at' => $message->created_at,
                'sender_name' => $message->sender_name ?? 'System',
                'sender_avatar' => $message->sender_avatar,
                'sender_role' => $senderRole,
                'media_url' => $message->media_url,
                'mime_type' => $message->mime_type,
            ];
        });

        return response()->json([
            'success' => true,
            'data' => [
                'dispute' => [
                    'id' => (int)$dispute->dispute_id,
                    'dispute_title' => $dispute->dispute_title,
                    'dispute_description' => $dispute->dispute_description,
                    'status' => $dispute->dispute_status,
                    'created_at' => $dispute->dispute_created_at,
                    'updated_at' => $dispute->dispute_updated_at,
                    'task' => [
                        'id' => $dispute->task_id,
                        'title' => $dispute->task_title,
                        'reward_point' => (int)$dispute->reward_point,
                        'creator_name' => $dispute->creator_name,
                        'participant_name' => $dispute->participant_name,
                    ],
                    'creator' => [
                        'name' => $dispute->creator_name,
                        'avatar_url' => $dispute->creator_avatar,
                    ],
                    'participant' => [
                        'name' => $dispute->participant_name,
                        'avatar_url' => $dispute->participant_avatar,
                    ],
                    'submitter' => [
                        'name' => $dispute->submitter_name,
                        'email' => $dispute->submitter_email,
                    ],
                ],
                'messages' => $processedMessages->toArray(),
                'meta' => [
                    'total_messages' => count($messages),
                    'viewed_by_admin' => $admin->username ?? $admin->full_name,
                    'admin_id' => (int)$admin->id,
                    'viewed_at' => now()->toDateTimeString()
                ]
            ]
        ]);
    }
}
