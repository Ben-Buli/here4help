<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class TaskReportController extends Controller
{
    /**
     * 列出指定任務的檢舉紀錄
     */
    public function index($taskId)
    {
        $task = DB::table('tasks as t')
            ->leftJoin('users as creators', 't.creator_id', '=', 'creators.id')
            ->select('t.id', 't.title', 't.creator_id', 't.participant_id', 'creators.name as creator_name')
            ->where('t.id', $taskId)
            ->first();

        if (!$task) {
            return response()->json([
                'success' => false,
                'message' => 'Task not found'
            ], 404);
        }

        $reports = DB::table('task_reports as tr')
            ->leftJoin('users as reporter', 'tr.reporter_id', '=', 'reporter.id')
            ->leftJoin('admins as admin', 'tr.admin_id', '=', 'admin.id')
            ->select([
                'tr.id',
                'tr.task_id',
                'tr.reason',
                'tr.description',
                'tr.status',
                'tr.admin_notes',
                'tr.created_at',
                'tr.updated_at',
                'reporter.id as reporter_id',
                'reporter.name as reporter_name',
                'reporter.email as reporter_email',
                'admin.username as admin_username'
            ])
            ->where('tr.task_id', $taskId)
            ->orderByDesc('tr.created_at')
            ->get()
            ->map(function ($report) use ($task) {
                $report->task_creator_id = $task->creator_id;
                $report->task_creator_name = $task->creator_name;
                return $report;
            });

        $hasPending = DB::table('task_reports')
            ->where('task_id', $taskId)
            ->where('status', 'pending')
            ->exists();

        return response()->json([
            'success' => true,
            'data' => [
                'task_id' => (int) $taskId,
                'task_title' => $task->title,
                'has_pending' => $hasPending,
                'reports' => $reports
            ]
        ]);
    }

    /**
     * 管理員處理檢舉
     */
    public function resolve(Request $request, $reportId)
    {
        $validator = Validator::make($request->all(), [
            'decision' => 'required|in:approve_remove',
            'notes' => 'required|string|min:10|max:1000'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $admin = $request->user();
        $decision = $request->input('decision');
        $notes = $request->input('notes');

        return DB::transaction(function () use ($reportId, $decision, $notes, $admin, $request) {
            $report = DB::table('task_reports')
                ->lockForUpdate()
                ->where('id', $reportId)
                ->first();

            if (!$report) {
                return response()->json([
                    'success' => false,
                    'message' => 'Report not found'
                ], 404);
            }

            if ($report->status !== 'pending') {
                return response()->json([
                    'success' => false,
                    'message' => 'Report already processed'
                ], 422);
            }

            $task = DB::table('tasks as t')
                ->leftJoin('task_statuses as ts', 't.status_id', '=', 'ts.id')
                ->select('t.*', 'ts.code as status_code', 'ts.display_name as status_display')
                ->lockForUpdate()
                ->where('t.id', $report->task_id)
                ->first();

            if (!$task) {
                return response()->json([
                    'success' => false,
                    'message' => 'Task not found for report'
                ], 404);
            }

            $statusMap = DB::table('task_statuses')->pluck('id', 'code');
            $cancelStatusId = $statusMap['cancelled'] ?? 8;

            $systemMessage = "This task was reported and has been cancelled by an administrator after review.";
            $oldStatusCode = $task->status_code ?? 'unknown';

            switch ($decision) {
                case 'approve_remove':
                    // 更新檢舉紀錄
                    DB::table('task_reports')
                        ->where('id', $reportId)
                        ->update([
                            'status' => 'resolved',
                            'admin_id' => $admin->id,
                            'admin_notes' => $notes,
                            'updated_at' => now()
                        ]);

                    // 更新任務
                    DB::table('tasks')
                        ->where('id', $task->id)
                        ->update([
                            'status_id' => $cancelStatusId,
                            'participant_id' => null,
                            'updated_at' => now()
                        ]);

                    // 插入聊天室系統訊息（僅當有參與者）
                    if (!empty($task->participant_id)) {
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

                    // task_logs
                    DB::table('task_logs')->insert([
                        'task_id' => $task->id,
                        'user_id' => null,
                        'action' => 'admin_report_approved',
                        'old_status' => $oldStatusCode,
                        'new_status' => 'cancelled',
                        'notes' => "Admin #{$admin->id} cancelled task via report #{$report->id}. {$notes}",
                        'created_at' => now()
                    ]);

                    // admin_activity_logs
                    DB::table('admin_activity_logs')->insert([
                        'admin_id' => $admin->id,
                        'action' => 'resolve_task_report',
                        'table_name' => 'tasks',
                        'record_id' => $task->id,
                        'old_data' => json_encode([
                            'status_id' => $task->status_id,
                            'status_code' => $oldStatusCode,
                            'participant_id' => $task->participant_id,
                            'report_status' => $report->status
                        ]),
                        'new_data' => json_encode([
                            'status_id' => $cancelStatusId,
                            'status_code' => 'cancelled',
                            'participant_id' => null,
                            'report_id' => $report->id,
                            'report_status' => 'resolved'
                        ]),
                        'ip_address' => $request->ip(),
                        'user_agent' => $request->userAgent(),
                        'created_at' => now()
                    ]);

                    break;
                default:
                    return response()->json([
                        'success' => false,
                        'message' => 'Unsupported decision'
                    ], 422);
            }

            return response()->json([
                'success' => true,
                'message' => 'Report handled successfully',
                'data' => [
                    'report_id' => (int) $report->id,
                    'task_id' => (int) $task->id,
                    'decision' => $decision
                ]
            ]);
        });
    }
}
