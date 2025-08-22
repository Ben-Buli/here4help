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
     * 獲取申訴列表
     */
    public function index(Request $request)
    {
        try {
            $perPage = $request->get('per_page', 15);
            $status = $request->get('status');
            $search = $request->get('search');
            
            $query = DB::table('task_disputes as td')
                ->join('tasks as t', 'td.task_id', '=', 't.id')
                ->join('users as u', 'td.user_id', '=', 'u.id')
                ->leftJoin('users as creator', 't.creator_id', '=', 'creator.id')
                ->leftJoin('users as participant', 't.participant_id', '=', 'participant.id')
                ->select([
                    'td.id',
                    'td.task_id',
                    'td.user_id',
                    'td.status',
                    'td.created_at',
                    'td.updated_at',
                    'td.resolved_at',
                    'td.rejected_at',
                    't.title as task_title',
                    't.description as task_description',
                    't.reward_point',
                    'u.name as disputer_name',
                    'u.email as disputer_email',
                    'creator.name as creator_name',
                    'creator.email as creator_email',
                    'participant.name as participant_name',
                    'participant.email as participant_email'
                ]);

            // 狀態篩選
            if ($status) {
                $query->where('td.status', $status);
            }

            // 搜尋功能
            if ($search) {
                $query->where(function($q) use ($search) {
                    $q->where('t.title', 'LIKE', "%{$search}%")
                      ->orWhere('u.name', 'LIKE', "%{$search}%")
                      ->orWhere('u.email', 'LIKE', "%{$search}%");
                });
            }

            $disputes = $query->orderBy('td.created_at', 'desc')
                             ->paginate($perPage);

            // 統計資料
            $stats = [
                'total' => DB::table('task_disputes')->count(),
                'open' => DB::table('task_disputes')->where('status', 'open')->count(),
                'in_review' => DB::table('task_disputes')->where('status', 'in_review')->count(),
                'resolved' => DB::table('task_disputes')->where('status', 'resolved')->count(),
                'rejected' => DB::table('task_disputes')->where('status', 'rejected')->count(),
            ];

            return response()->json([
                'success' => true,
                'data' => $disputes->items(),
                'pagination' => [
                    'current_page' => $disputes->currentPage(),
                    'last_page' => $disputes->lastPage(),
                    'per_page' => $disputes->perPage(),
                    'total' => $disputes->total(),
                ],
                'stats' => $stats
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to fetch disputes: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 獲取申訴詳情
     */
    public function show($id)
    {
        try {
            $dispute = DB::table('task_disputes as td')
                ->join('tasks as t', 'td.task_id', '=', 't.id')
                ->join('users as u', 'td.user_id', '=', 'u.id')
                ->leftJoin('users as creator', 't.creator_id', '=', 'creator.id')
                ->leftJoin('users as participant', 't.participant_id', '=', 'participant.id')
                ->leftJoin('task_statuses as ts', 't.status_id', '=', 'ts.id')
                ->select([
                    'td.*',
                    't.title as task_title',
                    't.description as task_description',
                    't.reward_point',
                    't.location',
                    't.task_date',
                    't.created_at as task_created_at',
                    'ts.display_name as task_status',
                    'u.name as disputer_name',
                    'u.email as disputer_email',
                    'u.phone as disputer_phone',
                    'creator.name as creator_name',
                    'creator.email as creator_email',
                    'participant.name as participant_name',
                    'participant.email as participant_email'
                ])
                ->where('td.id', $id)
                ->first();

            if (!$dispute) {
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute not found'
                ], 404);
            }

            // 獲取申訴相關的任務日誌
            $taskLogs = DB::table('task_logs')
                ->where('task_id', $dispute->task_id)
                ->orderBy('created_at', 'desc')
                ->get();

            // 獲取申訴狀態變更日誌
            $disputeLogs = DB::table('dispute_status_logs as dsl')
                ->leftJoin('users as u', 'dsl.changed_by', '=', 'u.id')
                ->select([
                    'dsl.*',
                    'u.name as changed_by_name'
                ])
                ->where('dsl.dispute_id', $id)
                ->orderBy('dsl.changed_at', 'desc')
                ->get();

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
     * 更新申訴狀態
     */
    public function updateStatus(Request $request, $id)
    {
        $validator = Validator::make($request->all(), [
            'status' => 'required|in:open,in_review,resolved,rejected',
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

            // 檢查申訴是否存在
            $dispute = DB::table('task_disputes')->where('id', $id)->first();
            if (!$dispute) {
                return response()->json([
                    'success' => false,
                    'message' => 'Dispute not found'
                ], 404);
            }

            $oldStatus = $dispute->status;
            $newStatus = $request->status;
            $adminId = $request->user()->id;

            // 更新申訴狀態
            $updateData = [
                'status' => $newStatus,
                'updated_at' => now()
            ];

            if ($newStatus === 'resolved') {
                $updateData['resolved_at'] = now();
            } elseif ($newStatus === 'rejected') {
                $updateData['rejected_at'] = now();
            }

            DB::table('task_disputes')
                ->where('id', $id)
                ->update($updateData);

            // 記錄狀態變更日誌
            DB::table('dispute_status_logs')->insert([
                'dispute_id' => $id,
                'status' => $newStatus,
                'changed_at' => now(),
                'changed_by' => $adminId
            ]);

            // 記錄管理員活動日誌
            AdminActivityLog::create([
                'admin_id' => $adminId,
                'action' => 'dispute_status_updated',
                'table_name' => 'task_disputes',
                'record_id' => $id,
                'old_data' => json_encode(['status' => $oldStatus]),
                'new_data' => json_encode([
                    'status' => $newStatus,
                    'notes' => $request->notes,
                    'resolution' => $request->resolution
                ]),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent()
            ]);

            // 如果申訴被解決或拒絕，可能需要更新任務狀態
            if (in_array($newStatus, ['resolved', 'rejected'])) {
                // 這裡可以根據業務邏輯決定是否要更新任務狀態
                // 例如：申訴被拒絕時恢復原狀態，申訴被接受時採取相應行動
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => 'Dispute status updated successfully',
                'data' => [
                    'id' => $id,
                    'old_status' => $oldStatus,
                    'new_status' => $newStatus,
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
     * 批量操作申訴
     */
    public function batchAction(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'action' => 'required|in:review,resolve,reject',
            'dispute_ids' => 'required|array|min:1',
            'dispute_ids.*' => 'integer|exists:task_disputes,id',
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
            $disputeIds = $request->dispute_ids;
            $adminId = $request->user()->id;
            
            $statusMap = [
                'review' => 'in_review',
                'resolve' => 'resolved',
                'reject' => 'rejected'
            ];
            
            $newStatus = $statusMap[$action];
            $successCount = 0;

            foreach ($disputeIds as $disputeId) {
                // 獲取當前狀態
                $dispute = DB::table('task_disputes')->where('id', $disputeId)->first();
                if (!$dispute) continue;

                $oldStatus = $dispute->status;

                // 更新狀態
                $updateData = [
                    'status' => $newStatus,
                    'updated_at' => now()
                ];

                if ($newStatus === 'resolved') {
                    $updateData['resolved_at'] = now();
                } elseif ($newStatus === 'rejected') {
                    $updateData['rejected_at'] = now();
                }

                DB::table('task_disputes')
                    ->where('id', $disputeId)
                    ->update($updateData);

                // 記錄狀態變更日誌
                DB::table('dispute_status_logs')->insert([
                    'dispute_id' => $disputeId,
                    'status' => $newStatus,
                    'changed_at' => now(),
                    'changed_by' => $adminId
                ]);

                // 記錄管理員活動日誌
                AdminActivityLog::create([
                    'admin_id' => $adminId,
                    'action' => "dispute_batch_{$action}",
                    'table_name' => 'task_disputes',
                    'record_id' => $disputeId,
                    'old_data' => json_encode(['status' => $oldStatus]),
                    'new_data' => json_encode([
                        'status' => $newStatus,
                        'notes' => $request->notes,
                        'batch_action' => true
                    ]),
                    'ip_address' => $request->ip(),
                    'user_agent' => $request->userAgent()
                ]);

                $successCount++;
            }

            DB::commit();

            return response()->json([
                'success' => true,
                'message' => "Successfully processed {$successCount} disputes",
                'data' => [
                    'processed_count' => $successCount,
                    'total_count' => count($disputeIds),
                    'action' => $action,
                    'new_status' => $newStatus
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
