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
        $studentVerification = DB::table('student_verifications')
            ->where('user_id', $id)
            ->orderBy('updated_at', 'desc')
            ->first();

        if ($studentVerification && $studentVerification->student_id_image_path) {
            $normalizedImagePath = ltrim($studentVerification->student_id_image_path, '/');
            if (str_starts_with($normalizedImagePath, 'uploads/')) {
                $normalizedImagePath = substr($normalizedImagePath, strlen('uploads/'));
            }
            $studentVerification->student_id_image_path = $normalizedImagePath;
            $studentVerification->student_id_image_url = '/uploads/' . $normalizedImagePath;
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

        $oldPermission = $user->permission;
        $newPermission = $request->permission;
        $reason = $request->get('reason', '');

        DB::beginTransaction();
        try {
            // 1) 更新用戶權限
            DB::table('users')
                ->where('id', $id)
                ->update([
                    'permission' => $newPermission,
                    'updated_at' => now()
                ]);

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
                ->select('id', 'user_id', 'school_name', 'student_name', 'student_id', 
                        'student_id_image_path', 'verification_status', 'verification_notes', 
                        'created_at', 'updated_at')
                ->where('user_id', $id)
                ->orderBy('updated_at', 'desc')
                ->first();

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
                    // 直接使用 /uploads 路徑，讓 Vite 代理處理
                    $imageUrl = '/uploads/' . $normalizedImagePath;
                }

                $responseData['verification'] = [
                    'id' => (int)$verification->id,
                    'school_name' => $verification->school_name,
                    'student_name' => $verification->student_name,
                    'student_id' => $verification->student_id,
                    'student_id_image_path' => $normalizedImagePath,
                    'student_id_image' => $imageUrl,
                    'verification_status' => $verification->verification_status,
                    'verification_notes' => $verification->verification_notes,
                    'admin_id' => null, // admin_id 欄位不存在
                    'created_at' => $verification->created_at,
                    'updated_at' => $verification->updated_at
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
        if (!$user || $user->permission !== 0) {
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
                ->orderBy('updated_at', 'desc')
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
