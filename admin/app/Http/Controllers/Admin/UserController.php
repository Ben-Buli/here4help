<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
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
            'status' => 'nullable|string|in:active,pending_review,rejected,banned,inactive',
            'permission' => 'nullable|integer',
            'user_id' => 'nullable|integer',
            'search' => 'nullable|string|max:255',
            'sort_by' => 'string|in:id,name,email,created_at,updated_at,points,permission,status',
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
        $userId = $request->get('user_id');
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

        if ($userId) {
            $query->where('id', $userId);
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
                // 與前端約定：清單鍵名為 items
                'items' => $users,
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

        // 取得學生證認證資料（若有）
        $studentVerification = null;
        $latestVerification = DB::table('student_verifications')
            ->where('user_id', $id)
            ->orderBy('created_at', 'desc')
            ->first();

        if ($latestVerification) {
            $previousVerification = DB::table('student_verifications')
                ->where('user_id', $id)
                ->orderBy('created_at', 'desc')
                ->skip(1)
                ->first();

            $submissionCount = DB::table('student_verifications')
                ->where('user_id', $id)
                ->count();

            $normalizedImagePath = null;
            if ($latestVerification->student_id_image_path) {
                $normalizedImagePath = ltrim($latestVerification->student_id_image_path, '/');
                if (str_starts_with($normalizedImagePath, 'uploads/')) {
                    $normalizedImagePath = substr($normalizedImagePath, strlen('uploads/'));
                }
            }

            $requiresReReview = $previousVerification
                && $previousVerification->verification_status === 'rejected'
                && $latestVerification->verification_status === 'pending';

            $studentVerification = (object) [
                'id' => $latestVerification->id,
                'school_name' => $latestVerification->school_name,
                'student_name' => $latestVerification->student_name,
                'student_id' => $latestVerification->student_id,
                'student_id_image_path' => $normalizedImagePath,
                'student_id_image_url' => $normalizedImagePath ? '/uploads/' . $normalizedImagePath : null,
                'verification_status' => $latestVerification->verification_status,
                'verification_notes' => $latestVerification->verification_notes,
                'created_at' => $latestVerification->created_at,
                'updated_at' => $latestVerification->updated_at,
                'admin_id' => $latestVerification->admin_id ?? null,
                'submission_count' => $submissionCount,
                'previous_status' => $previousVerification->verification_status ?? null,
                'requires_re_review' => $requiresReReview,
            ];
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
                'recent_activities' => $recentActivities,
                'student_verification' => $studentVerification,
            ]
        ]);
    }

    /**
     * 列出用戶邀請碼／推薦碼資訊
     */
    public function referralCodes(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'page' => 'integer|min:1',
            'per_page' => 'integer|min:1|max:200',
            'search' => 'nullable|string|max:255',
            'user_id' => 'nullable|integer',
            'sort_by' => 'string|in:id,name,email,permission,referral_code,intro_referral_code,updated_at',
            'sort_order' => 'string|in:asc,desc',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $page = (int)$request->get('page', 1);
        $perPage = (int)$request->get('per_page', 20);
        $search = $request->get('search');
        $userId = $request->get('user_id');
        $sortBy = $request->get('sort_by', 'updated_at');
        $sortOrder = $request->get('sort_order', 'desc');

        $query = DB::table('users')
            ->select('id', 'name', 'email', 'permission', 'referral_code', 'intro_referral_code', 'updated_at');

        if ($userId) {
            $query->where('id', $userId);
        }

        if ($search) {
            $query->where(function ($q) use ($search) {
                $q->where('name', 'LIKE', "%{$search}%")
                    ->orWhere('email', 'LIKE', "%{$search}%")
                    ->orWhere('referral_code', 'LIKE', "%{$search}%")
                    ->orWhere('intro_referral_code', 'LIKE', "%{$search}%");
            });
        }

        $total = $query->count();

        $records = $query
            ->orderBy($sortBy, $sortOrder)
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get();

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $records,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => ceil($total / $perPage),
                ],
            ],
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

        // 寫入 user_active_log（最小集合）
        try {
            $tableExists = DB::selectOne("SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_active_log'");
            if ((int)($tableExists->c ?? 0) > 0) {
                DB::table('user_active_log')->insert([
                    'user_id' => $id,
                    'actor_type' => 'admin',
                    'actor_id' => $request->user()->id,
                    'action' => 'status_change',
                    'field' => 'status',
                    'old_value' => $oldStatus,
                    'new_value' => $newStatus,
                    'reason' => $reason,
                    'created_at' => now(),
                ]);
            }
        } catch (\Throwable $e) {
            // 靜默失敗，避免阻斷主流程
        }

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

        $oldPermission = (int) $user->permission;
        $newPermission = (int) $request->permission;
        $reason = $request->get('reason', '');
        $isAdminDelete = ($oldPermission !== -2 && $newPermission === -2);
        $blockedReason = $reason !== '' ? $reason : 'Account deleted by admin';
        $anonymizedEmail = null;
        $identities = collect();

        if ($isAdminDelete) {
            $anonymizedEmail = sprintf(
                'deleted_%s_u%s_%s@deleted.invalid',
                now()->format('Ymd'),
                $id,
                Str::lower(Str::random(8))
            );

            $identities = DB::table('user_identities')
                ->where('user_id', $id)
                ->get();
        }

        DB::beginTransaction();
        try {
            // 1) 更新用戶權限
            $updateData = [
                'permission' => $newPermission,
                'updated_at' => now(),
            ];
            if ($isAdminDelete && $anonymizedEmail) {
                $updateData['email'] = $anonymizedEmail;
            }
            DB::table('users')->where('id', $id)->update($updateData);

            // 1.1) 管理員刪除：寫入 blocked 並移除第三方綁定
            if ($isAdminDelete) {
                if (Schema::hasTable('blocked_emails') && !empty($user->email)) {
                    DB::table('blocked_emails')->updateOrInsert(
                        ['email' => $user->email],
                        [
                            'reason' => $blockedReason,
                            'blocked_by' => $request->user()->id,
                            'blocked_at' => now(),
                            'source' => 'admin_delete',
                            'created_at' => now(),
                            'updated_at' => now(),
                        ]
                    );
                }

                if (Schema::hasTable('blocked_identities')) {
                    foreach ($identities as $identity) {
                        if (empty($identity->provider) || empty($identity->provider_user_id)) {
                            continue;
                        }
                        DB::table('blocked_identities')->updateOrInsert(
                            [
                                'provider' => $identity->provider,
                                'provider_user_id' => $identity->provider_user_id,
                            ],
                            [
                                'reason' => $blockedReason,
                                'blocked_by' => $request->user()->id,
                                'blocked_at' => now(),
                                'source' => 'admin_delete',
                                'created_at' => now(),
                                'updated_at' => now(),
                            ]
                        );
                    }
                }

                DB::table('user_identities')->where('user_id', $id)->delete();
            }

            // 2) 若 0 -> 1：
            if ((int)$oldPermission === 0 && (int)$newPermission === 1) {
                // 2.1 生成 referral_code（若沒有）- 暫時註解，等 referral_codes 表建立後啟用
                /*
                if (!$user->referral_code) {
                    do {
                        $refCode = strtoupper(substr(md5($id . rand()), 0, 6));
                        $exists = DB::table('referral_codes')->where('referral_code', $refCode)->exists();
                    } while ($exists);

                    DB::table('referral_codes')->insert([
                        'user_id' => $id,
                        'referral_code' => $refCode,
                        'created_at' => now(),
                        'updated_at' => now(),
                    ]);

                    DB::table('users')->where('id', $id)->update([
                        'referral_code' => $refCode,
                        'updated_at' => now(),
                    ]);
                }

                // 2.2 在 referral_codes 以 used_by_user_id 記錄引用，批准時發點數
                // 確保 awarded_at 欄位存在（若無則新增）
                $col = DB::selectOne("SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'referral_codes' AND COLUMN_NAME = 'awarded_at'");
                if ((int)($col->c ?? 0) === 0) {
                    DB::statement("ALTER TABLE referral_codes ADD COLUMN awarded_at TIMESTAMP NULL DEFAULT NULL, ADD INDEX idx_awarded_at (awarded_at)");
                }

                // 將以此用戶為被推薦人的紀錄標記為已發獎（僅一次），並加點數
                $affected = DB::table('referral_codes')
                    ->where('used_by_user_id', $id)
                    ->whereNull('awarded_at')
                    ->update([
                        'awarded_at' => now(),
                        'updated_at' => now(),
                    ]);

                if ($affected > 0) {
                    DB::table('users')->where('id', $id)->update([
                        'points' => DB::raw('(points + 500)'),
                        'updated_at' => now(),
                    ]);
                }
                */
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to update permission: ' . $e->getMessage(),
            ], 500);
        }

        // 記錄權限變更日誌
        $this->logPermissionChange($request->user(), $id, $oldPermission, $newPermission, $reason);

        // 寫入 user_active_log（最小集合）
        try {
            $tableExists = DB::selectOne("SELECT COUNT(*) AS c FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'user_active_log'");
            if ((int)($tableExists->c ?? 0) > 0) {
                DB::table('user_active_log')->insert([
                    'user_id' => $id,
                    'actor_type' => 'admin',
                    'actor_id' => $request->user()->id,
                    'action' => 'permission_change',
                    'field' => 'permission',
                    'old_value' => (string)$oldPermission,
                    'new_value' => (string)$newPermission,
                    'reason' => $reason,
                    'created_at' => now(),
                ]);
            }
        } catch (\Throwable $e) {
            // 靜默失敗
        }

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
            'table_name' => 'users',
            'record_id' => $userId,
            'old_data' => json_encode(['status' => $oldStatus]),
            'new_data' => json_encode(['status' => $newStatus]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now()
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
            'table_name' => 'users',
            'record_id' => $userId,
            'old_data' => json_encode(['permission' => $oldPermission]),
            'new_data' => json_encode(['permission' => $newPermission]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now()
        ]);
    }

    /**
     * 獲取用戶驗證資料
     */
    public function verification($id)
    {
        try {
            $user = DB::table('users')
                ->select('id', 'name', 'email', 'permission', 'status', 'created_at')
                ->where('id', $id)
                ->first();

            if (!$user) {
                return response()->json([
                    'success' => false,
                    'message' => 'User not found'
                ], 404);
            }

            // 獲取用戶最新的學生證驗證記錄
            $verification = DB::table('student_verifications')
                ->select(
                    'id',
                    'user_id',
                    'school_name',
                    'student_name',
                    'student_id',
                    'student_id_image_path',
                    'verification_status',
                    'verification_notes',
                    'created_at',
                    'updated_at',
                    'admin_id'
                )
                ->where('user_id', $id)
                ->orderBy('created_at', 'desc')
                ->first();

            $previousVerification = DB::table('student_verifications')
                ->select('verification_status')
                ->where('user_id', $id)
                ->orderBy('created_at', 'desc')
                ->skip(1)
                ->first();

            $submissionCount = DB::table('student_verifications')
                ->where('user_id', $id)
                ->count();

            $responseData = [
                'user' => $user,
                'verification' => null
            ];

            if ($verification) {
                // 構建完整的圖片 URL
                $imageUrl = null;
                $normalizedImagePath = null;
                if ($verification->student_id_image_path) {
                    $normalizedImagePath = ltrim($verification->student_id_image_path, '/');
                    if (str_starts_with($normalizedImagePath, 'uploads/')) {
                        $normalizedImagePath = substr($normalizedImagePath, strlen('uploads/'));
                    }
                    
                    // 根據環境構建完整的圖片 URL
                    $appUrl = rtrim(config('app.url', ''), '/');
                    $isLocal = str_contains($appUrl, 'localhost') || str_contains($appUrl, '127.0.0.1');
                    
                    if ($isLocal) {
                        // 本地開發：使用相對路徑，讓 Vite 代理處理
                        $imageUrl = '/uploads/' . $normalizedImagePath;
                    } else {
                        // 生產環境：使用完整 URL，包含 /backend/ 路徑
                        $backendUrl = config('services.backend.url', $appUrl . '/backend');
                        // 移除 /api 後綴（如果有）
                        $backendUrl = preg_replace('#/api$#', '', $backendUrl);
                        $imageUrl = $backendUrl . '/uploads/' . $normalizedImagePath;
                    }
                }

                $requiresReReview = $previousVerification
                    && $previousVerification->verification_status === 'rejected'
                    && $verification->verification_status === 'pending';

                $responseData['verification'] = [
                    'id' => (int)$verification->id,
                    'school_name' => $verification->school_name,
                    'student_name' => $verification->student_name,
                    'student_id' => $verification->student_id,
                    'student_id_image_path' => $normalizedImagePath,
                    'student_id_image' => $imageUrl,
                    'verification_status' => $verification->verification_status,
                    'verification_notes' => $verification->verification_notes,
                    'admin_id' => $verification->admin_id ? (int)$verification->admin_id : null,
                    'created_at' => $verification->created_at,
                    'updated_at' => $verification->updated_at,
                    'previous_status' => $previousVerification->verification_status ?? null,
                    'submission_count' => $submissionCount,
                    'requires_re_review' => $requiresReReview,
                ];
            }

            return response()->json([
                'success' => true,
                'data' => $responseData,
                'message' => 'User verification data retrieved successfully'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Internal server error: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 獲取用戶被推薦資訊
     */
    public function introReferralInfo($id)
    {
        try {
            $user = DB::table('users')
                ->select('id', 'name', 'email', 'permission', 'status', 'created_at', 'intro_referral_code')
                ->where('id', $id)
                ->first();

            if (!$user) {
                return response()->json([
                    'success' => false,
                    'message' => 'User not found'
                ], 404);
            }

            $responseData = null;

            // 如果用戶有 intro_referral_code，查找推薦人資訊
            if (!empty($user->intro_referral_code)) {
                $referrer = DB::table('users')
                    ->select('id', 'name', 'email', 'status', 'permission', 'referral_code')
                    ->where('referral_code', $user->intro_referral_code)
                    ->first();

                if ($referrer) {
                    // 查找點數交易記錄（推薦獎勵）
                    $pointTransaction = DB::table('point_transactions')
                        ->select('id', 'user_id', 'transaction_type', 'amount', 'description', 'related_task_id', 'created_at')
                        ->where('user_id', $id)
                        ->where('transaction_type', 'referral_bonus')
                        ->orderBy('created_at', 'desc')
                        ->first();

                    $responseData = [
                        'intro_referral_code' => $user->intro_referral_code,
                        'referrer' => [
                            'id' => (int)$referrer->id,
                            'name' => $referrer->name,
                            'email' => $referrer->email,
                            'status' => $referrer->status,
                            'permission' => (int)$referrer->permission,
                            'referral_code' => $referrer->referral_code
                        ],
                        'referral_event' => $pointTransaction ? [
                            'id' => (int)$pointTransaction->id,
                            'status' => 'completed',
                            'reward_points' => (int)$pointTransaction->amount,
                            'created_at' => $pointTransaction->created_at,
                            'completed_at' => $pointTransaction->created_at,
                            'notes' => $pointTransaction->description
                        ] : [
                            'status' => 'pending',
                            'reward_points' => 500,
                            'created_at' => null,
                            'completed_at' => null,
                            'notes' => '等待管理員審核通過後發放獎勵'
                        ]
                    ];
                } else {
                    // 推薦碼存在但找不到推薦人（可能是無效的推薦碼）
                    $responseData = [
                        'intro_referral_code' => $user->intro_referral_code,
                        'referrer' => null,
                        'referral_event' => null,
                        'error' => 'Referrer not found - invalid referral code'
                    ];
                }
            }

            return response()->json([
                'success' => true,
                'data' => $responseData,
                'message' => 'User intro referral information retrieved successfully'
            ]);

        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Internal server error: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 使用者條款同意歷史
     */
    public function termsHistory($id)
    {
        $user = DB::table('users')->where('id', $id)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found'
            ], 404);
        }

        $terms = DB::table('app_terms as at')
            ->leftJoin('terms_user_acceptance as tua', function ($join) use ($id) {
                $join->on('tua.accepted_version_id', '=', 'at.id')
                    ->where('tua.user_id', '=', $id);
            })
            ->where('at.created_at', '>=', $user->created_at)
            ->orderBy('at.created_at', 'asc')
            ->get([
                'at.id',
                'at.title',
                'at.created_at',
                'tua.accepted_at',
            ]);

        return response()->json([
            'success' => true,
            'data' => [
                'user_registered_at' => $user->created_at,
                'items' => $terms,
            ],
        ]);
    }

    /**
     * 產生或取得使用者的密碼重設連結
     */
    public function passwordResetLink(Request $request, $id)
    {
        $admin = $request->user();
        $user = DB::table('users')->where('id', $id)->first();

        if (!$user) {
            return response()->json([
                'success' => false,
                'message' => 'User not found',
            ], 404);
        }

        if (empty($user->email)) {
            return response()->json([
                'success' => false,
                'message' => 'The user does not have a valid email address on file.',
            ], 422);
        }

        $now = Carbon::now();
        $existingToken = DB::table('email_verification_tokens')
            ->where('user_id', $id)
            ->where('type', 'password_reset')
            ->where('used', 0)
            ->where('expires_at', '>', $now)
            ->orderByDesc('created_at')
            ->first();

        $tokenRecord = $existingToken;
        $isNew = false;

        DB::beginTransaction();
        try {
            if (!$tokenRecord) {
                DB::table('email_verification_tokens')
                    ->where('user_id', $id)
                    ->where('type', 'password_reset')
                    ->where('used', 0)
                    ->update([
                        'used' => 1,
                        'used_at' => $now,
                    ]);

                $token = bin2hex(random_bytes(32));
                $expiresAt = Carbon::now()->addHour();
                $adminName = $admin->full_name ?? $admin->username ?? $admin->email;

                DB::table('email_verification_tokens')->insert([
                    'user_id' => $id,
                    'token' => $token,
                    'type' => 'password_reset',
                    'expires_at' => $expiresAt,
                    'used' => 0,
                    'created_at' => $now,
                    'created_by' => $admin->id,
                    'created_by_name' => $adminName,
                ]);

                $tokenRecord = (object) [
                    'token' => $token,
                    'expires_at' => $expiresAt->toDateTimeString(),
                    'created_at' => $now->toDateTimeString(),
                    'created_by' => $admin->id,
                    'created_by_name' => $adminName,
                ];
                $isNew = true;
            }

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            return response()->json([
                'success' => false,
                'message' => 'Failed to create password reset link: ' . $e->getMessage(),
            ], 500);
        }

        $expiresAt = Carbon::parse($tokenRecord->expires_at);
        $resetLink = $this->buildPasswordResetLink($tokenRecord->token, $user->email);
        $remainingSeconds = max(0, $now->diffInSeconds($expiresAt, false));

        $responseData = [
            'user_id' => (int) $user->id,
            'user_name' => $user->name,
            'email' => $user->email,
            'reset_link' => $resetLink,
            'token' => $tokenRecord->token,
            'expires_at' => $expiresAt->toDateTimeString(),
            'remaining_seconds' => $remainingSeconds,
            'created_at' => $tokenRecord->created_at ?? $now->toDateTimeString(),
            'created_by' => $tokenRecord->created_by ?? null,
            'created_by_name' => $tokenRecord->created_by_name ?? null,
            'was_existing_link' => !$isNew,
        ];

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => $isNew ? 'password_reset_link_created' : 'password_reset_link_viewed',
            'table_name' => 'users',
            'record_id' => $user->id,
            'old_data' => null,
            'new_data' => json_encode([
                'user_id' => $user->id,
                'email' => $user->email,
                'expires_at' => $responseData['expires_at'],
                'was_existing_link' => !$isNew,
            ]),
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);

        return response()->json([
            'success' => true,
            'data' => $responseData,
            'message' => $isNew
                ? 'Password reset link generated successfully.'
                : 'An active password reset link already exists.',
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
            'table_name' => 'users',
            'record_id' => null,
            'old_data' => null,
            'new_data' => json_encode(['action' => $action, 'user_ids' => $userIds, 'reason' => $reason]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now()
        ]);
    }

    private function buildPasswordResetLink(string $token, string $email): string
    {
        $baseUrl = $this->getPasswordResetBaseUrl();
        return $baseUrl . '?token=' . urlencode($token) . '&email=' . urlencode($email);
    }

    private function getPasswordResetBaseUrl(): string
    {
        $configured = trim((string) config('app.password_reset_page_url', ''));
        if ($configured !== '') {
            return rtrim($configured, '/');
        }

        $appUrl = config('app.url', 'http://localhost');
        $appUrl = rtrim($appUrl ?: 'http://localhost', '/');

        if (str_ends_with($appUrl, '/admin')) {
            $appUrl = rtrim(substr($appUrl, 0, -strlen('/admin')), '/');
        }

        return rtrim($appUrl, '/') . '/account/reset-password';
    }

    /**
     * 管理員審核用戶驗證資料
     */
    public function review(Request $request, $id)
    {
        // 驗證輸入
        $validator = Validator::make($request->all(), [
            'decision' => 'required|in:approve,reject',
            'new_permission' => 'required|integer',
            'notes' => 'nullable|string|max:1000'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 400);
        }

        // 獲取管理員資訊
        $admin = auth('sanctum')->user();
        
        // 檢查用戶是否存在且為未驗證狀態
        $user = DB::table('users')->where('id', $id)->first();
        if (!$user || $user->permission != 0) {
            return response()->json([
                'success' => false,
                'message' => 'User not found or not in unverified status'
            ], 400);
        }

        // 開始資料庫交易
        DB::beginTransaction();
        
        try {
            $referralCode = null;
            $referralReward = null;
            
            // 如果是批准且設定為已驗證用戶
            if ($request->decision === 'approve' && $request->new_permission == 1) {
                // 生成推薦碼
                $referralCode = $this->generateReferralCode($id);
                
                // 處理推薦獎勵
                $referralReward = $this->processReferralReward($id, $admin->id);
            }
            
            // 更新用戶權限
            DB::table('users')
                ->where('id', $id)
                ->update([
                    'permission' => $request->new_permission,
                    'updated_at' => now()
                ]);
            
            // 更新學生證驗證記錄
            $verificationStatus = $request->decision === 'approve' ? 'approved' : 'rejected';
            DB::table('student_verifications')
                ->where('user_id', $id)
                ->orderBy('created_at', 'desc')
                ->limit(1)
                ->update([
                    'verification_status' => $verificationStatus,
                    'verification_notes' => $request->notes,
                    'admin_id' => $admin->id,
                    'updated_at' => now()
                ]);
            
            // 記錄操作日誌
            $this->logUserReview($id, $admin->id, $request->all(), $referralCode, $referralReward);
            
            // 提交交易
            DB::commit();
            
            // 返回成功回應
            $responseData = [
                'user_id' => $id,
                'decision' => $request->decision,
                'old_permission' => $user->permission,
                'new_permission' => $request->new_permission,
                'notes' => $request->notes,
                'reviewed_by' => $admin->id,
                'reviewed_at' => now()->toDateTimeString()
            ];
            
            if ($referralCode) {
                $responseData['referral_code_generated'] = $referralCode;
            }
            
            if ($referralReward) {
                $responseData['referral_reward'] = $referralReward;
            }
            
            $message = $request->decision === 'approve' 
                ? 'User verification approved successfully' 
                : 'User verification rejected successfully';
                
            if ($referralReward) {
                $message .= " - Referral reward of {$referralReward['reward_points']} points awarded to {$referralReward['referrer_name']}";
            }
            
            return response()->json([
                'success' => true,
                'data' => $responseData,
                'message' => $message
            ]);
            
        } catch (\Exception $e) {
            DB::rollback();
            return response()->json([
                'success' => false,
                'message' => 'Internal server error: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * 生成推薦碼
     */
    private function generateReferralCode($userId)
    {
        $length = 12;
        $maxAttempts = 50;
        $attempt = 0;
        
        do {
            $attempt++;
            
            // 生成推薦碼：字母數字組合，避免容易混淆的字符
            $characters = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
            $referralCode = '';
            
            for ($i = 0; $i < $length; $i++) {
                $referralCode .= $characters[random_int(0, strlen($characters) - 1)];
            }
            
            // 檢查是否已存在
            $exists = DB::table('users')
                ->where('referral_code', $referralCode)
                ->exists();
                
            if (!$exists) {
                // 更新用戶的推薦碼
                DB::table('users')
                    ->where('id', $userId)
                    ->update(['referral_code' => $referralCode]);
                    
                return $referralCode;
            }
            
        } while ($attempt < $maxAttempts);
        
        throw new \Exception('Unable to generate unique referral code after ' . $maxAttempts . ' attempts');
    }

    /**
     * 處理推薦獎勵
     */
    private function processReferralReward($userId, $adminId)
    {
        // 檢查用戶是否有 intro_referral_code
        $user = DB::table('users')
            ->where('id', $userId)
            ->first();
            
        if (!$user || empty($user->intro_referral_code)) {
            return null;
        }
        
        // 查找推薦人
        $referrer = DB::table('users')
            ->where('referral_code', $user->intro_referral_code)
            ->where('permission', '>', 0)
            ->where('status', 'active')
            ->first();
            
        if (!$referrer) {
            return null;
        }
        
        // 給被推薦人（新用戶）加500點數
        DB::table('users')
            ->where('id', $userId)
            ->increment('points', 500);
        
        // 記錄被推薦人的點數交易
        DB::table('point_transactions')->insert([
            'user_id' => $userId,
            'transaction_type' => 'referral_bonus',
            'amount' => 500,
            'description' => "使用推薦碼註冊獎勵 - 推薦人ID: {$referrer->id}",
            'related_task_id' => null,
            'created_at' => now()
        ]);
        
        // 記錄管理員操作到 admin_activity_logs
        DB::table('admin_activity_logs')->insert([
            'admin_id' => $adminId,
            'action' => 'referral_bonus',
            'table_name' => 'users',
            'record_id' => $userId,
            'old_data' => null,
            'new_data' => json_encode([
                'action' => 'referral_bonus',
                'referee_id' => $userId,
                'referrer_id' => $referrer->id,
                'intro_referral_code' => $user->intro_referral_code,
                'reward_points' => 500
            ]),
            'ip_address' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'created_at' => now()
        ]);
        
        return [
            'referee_id' => $userId,
            'referrer_id' => $referrer->id,
            'referrer_name' => $referrer->name,
            'reward_points' => 500,
            'intro_referral_code' => $user->intro_referral_code
        ];
    }

    /**
     * 記錄用戶審核日誌
     */
    private function logUserReview($userId, $adminId, $requestData, $referralCode, $referralReward)
    {
        $logDetails = [
            'decision' => $requestData['decision'],
            'old_permission' => DB::table('users')->where('id', $userId)->value('permission'),
            'new_permission' => $requestData['new_permission'],
            'notes' => $requestData['notes'] ?? '',
            'admin_id' => $adminId,
            'referral_code_generated' => $referralCode,
            'referral_reward' => $referralReward
        ];
        
        DB::table('user_active_log')->insert([
            'user_id' => $userId,
            'actor_type' => 'admin',
            'actor_id' => $adminId,
            'action' => 'user_verification_review',
            'field' => 'permission',
            'old_value' => (string)$logDetails['old_permission'],
            'new_value' => (string)$logDetails['new_permission'],
            'reason' => $logDetails['notes'],
            'ip' => request()->ip(),
            'user_agent' => request()->userAgent(),
            'metadata' => json_encode($logDetails),
            'created_at' => now()
        ]);
    }
}
