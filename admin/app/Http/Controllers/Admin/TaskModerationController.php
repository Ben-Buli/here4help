<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Validator;

class TaskModerationController extends Controller
{
    /**
     * 管理員直接操作任務狀態
     */
    public function moderate(Request $request, $taskId)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|in:cancel',
            'reason' => 'required|string|min:10|max:1000'
        ]);

        if ($validator->fails()) {
            Log::channel('admin_ops')->warning('Task moderation validation failed', [
                'task_id' => $taskId,
                'admin_id' => $request->user()?->id,
                'errors' => $validator->errors()->toArray(),
                'payload_keys' => array_keys($request->all()),
            ]);
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $admin = $request->user();
        $action = $request->input('action');
        $reason = $request->input('reason');

        $hasPendingReports = DB::table('task_reports')
            ->where('task_id', $taskId)
            ->where('status', 'pending')
            ->exists();

        if ($hasPendingReports) {
            return response()->json([
                'success' => false,
                'message' => 'Resolve pending reports before performing this action.'
            ], 422);
        }

        try {
            return DB::transaction(function () use ($taskId, $action, $reason, $admin, $request) {
                $task = DB::table('tasks as t')
                    ->leftJoin('task_statuses as ts', 't.status_id', '=', 'ts.id')
                    ->select('t.*', 'ts.code as status_code', 'ts.display_name as status_display')
                    ->lockForUpdate()
                    ->where('t.id', $taskId)
                    ->first();

                if (!$task) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Task not found'
                    ], 404);
                }

            $statusCode = $task->status_code ?? null;
            $allowedStatuses = ['open', 'in_progress', 'pending_confirmation'];
            if (!$statusCode) {
                // Fallback：使用 status_id 判斷
                $allowedIds = [1, 2, 3];
                if (!in_array((int) $task->status_id, $allowedIds, true)) {
                    return response()->json([
                        'success' => false,
                        'message' => 'Task status does not allow moderation.'
                    ], 422);
                }
            } elseif (!in_array($statusCode, $allowedStatuses, true)) {
                return response()->json([
                    'success' => false,
                    'message' => 'Task status does not allow moderation.'
                ], 422);
            }

            // 再次確認是否有 pending report（避免競態）
            $hasPendingReports = DB::table('task_reports')
                ->where('task_id', $taskId)
                ->where('status', 'pending')
                ->lockForUpdate()
                ->exists();

            if ($hasPendingReports) {
                return response()->json([
                    'success' => false,
                    'message' => 'Resolve pending reports before performing this action.'
                ], 422);
            }

            $statusMap = DB::table('task_statuses')->pluck('id', 'code');
            $cancelStatusId = $statusMap['cancelled'] ?? 8;
            $oldStatusCode = $task->status_code ?? 'unknown';
            $oldParticipant = $task->participant_id;

            switch ($action) {
                case 'cancel':
                    DB::table('tasks')
                        ->where('id', $task->id)
                        ->update([
                            'status_id' => $cancelStatusId,
                            'participant_id' => null,
                            'updated_at' => now()
                        ]);

                    $systemMessage = "This task was found to violate platform policies and has been cancelled by an administrator. Reason: {$reason}";
                    if (!empty($oldParticipant)) {
                        $room = DB::table('chat_rooms')
                            ->select('id')
                            ->where('task_id', $task->id)
                            ->orderByDesc('id')
                            ->first();

                        if ($room) {
                            DB::table('chat_messages')->insert([
                                'room_id' => $room->id,
                                'from_user_id' => $task->creator_id,
                                'content' => $systemMessage,
                                'kind' => 'system',
                                'created_at' => now()
                            ]);
                        }
                    }

                    DB::table('task_logs')->insert([
                        'task_id' => $task->id,
                        'user_id' => null,
                        'admin_id' => $admin->id,
                        'action' => 'admin_task_cancel',
                        'old_status' => $oldStatusCode,
                        'new_status' => 'cancelled',
                        'description' => "Admin #{$admin->id} cancelled task directly. {$reason}",
                        'created_at' => now()
                    ]);

                    DB::table('admin_activity_logs')->insert([
                        'admin_id' => $admin->id,
                        'action' => 'moderate_task',
                        'table_name' => 'tasks',
                        'record_id' => $task->id,
                        'old_data' => json_encode([
                            'status_id' => $task->status_id,
                            'status_code' => $oldStatusCode,
                            'participant_id' => $oldParticipant
                        ]),
                        'new_data' => json_encode([
                            'status_id' => $cancelStatusId,
                            'status_code' => 'cancelled',
                            'participant_id' => null,
                            'action' => $action,
                            'reason' => $reason
                        ]),
                        'ip_address' => $request->ip(),
                        'user_agent' => $request->userAgent(),
                        'created_at' => now()
                    ]);

                    break;
                default:
                    return response()->json([
                        'success' => false,
                        'message' => 'Unsupported action'
                    ], 422);
            }

                return response()->json([
                    'success' => true,
                    'message' => 'Task updated successfully',
                    'data' => [
                        'task_id' => (int) $task->id,
                        'action' => $action
                    ]
                ]);
            });
        } catch (\Throwable $e) {
            Log::channel('admin_ops')->error('Task moderation failed', [
                'task_id' => $taskId,
                'admin_id' => $admin?->id,
                'action' => $action,
                'exception' => $e->getMessage(),
            ]);
            return response()->json([
                'success' => false,
                'message' => 'Unable to update the task right now. Please try again later.'
            ], 500);
        }
    }
}
