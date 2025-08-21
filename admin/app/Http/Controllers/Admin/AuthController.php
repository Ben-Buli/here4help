<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use App\Models\AdminLoginLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Illuminate\Validation\ValidationException;

class AuthController extends Controller
{
    /**
     * 管理員登入
     */
    public function login(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'email' => 'required|email',
            'password' => 'required|string|min:6',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors()
            ], 422);
        }

        $email = $request->email;
        $password = $request->password;
        $ipAddress = $request->ip();
        $userAgent = $request->userAgent();

        // 查找管理員
        $admin = Admin::where('email', $email)->first();

        // 記錄登入嘗試
        $this->logLoginAttempt($admin?->id, $email, $ipAddress, $userAgent);

        if (!$admin) {
            $this->logLoginFailure(null, $email, 'User not found', $ipAddress, $userAgent);
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials'
            ], 401);
        }

        // 檢查帳號狀態
        if (!$admin->isActive()) {
            $this->logLoginFailure($admin->id, $email, 'Account inactive', $ipAddress, $userAgent);
            return response()->json([
                'success' => false,
                'message' => 'Account is inactive'
            ], 401);
        }

        // 檢查帳號是否被鎖定
        if ($admin->locked_until && $admin->locked_until > now()) {
            $this->logLoginFailure($admin->id, $email, 'Account locked', $ipAddress, $userAgent);
            return response()->json([
                'success' => false,
                'message' => 'Account is temporarily locked'
            ], 401);
        }

        // 驗證密碼
        if (!Hash::check($password, $admin->password)) {
            $this->handleFailedLogin($admin, $email, $ipAddress, $userAgent);
            return response()->json([
                'success' => false,
                'message' => 'Invalid credentials'
            ], 401);
        }

        // 登入成功
        $this->handleSuccessfulLogin($admin, $ipAddress, $userAgent);

        // 生成 API token
        $token = $admin->createToken('admin-token', ['admin'])->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Login successful',
            'data' => [
                'admin' => [
                    'id' => $admin->id,
                    'username' => $admin->username,
                    'full_name' => $admin->full_name,
                    'email' => $admin->email,
                    'role' => $admin->role,
                    'status' => $admin->status,
                    'last_login' => $admin->last_login,
                ],
                'token' => $token,
                'permissions' => $admin->role?->permissions ?? []
            ]
        ]);
    }

    /**
     * 管理員登出
     */
    public function logout(Request $request)
    {
        $admin = $request->user();
        
        if ($admin) {
            // 撤銷當前 token
            $request->user()->currentAccessToken()->delete();
            
            return response()->json([
                'success' => true,
                'message' => 'Logout successful'
            ]);
        }

        return response()->json([
            'success' => false,
            'message' => 'Not authenticated'
        ], 401);
    }

    /**
     * 獲取當前管理員資訊
     */
    public function me(Request $request)
    {
        $admin = $request->user();
        
        if (!$admin) {
            return response()->json([
                'success' => false,
                'message' => 'Not authenticated'
            ], 401);
        }

        return response()->json([
            'success' => true,
            'data' => [
                'admin' => [
                    'id' => $admin->id,
                    'username' => $admin->username,
                    'full_name' => $admin->full_name,
                    'email' => $admin->email,
                    'role' => $admin->role,
                    'status' => $admin->status,
                    'last_login' => $admin->last_login,
                ],
                'permissions' => $admin->role?->permissions ?? []
            ]
        ]);
    }

    /**
     * 刷新 token
     */
    public function refresh(Request $request)
    {
        $admin = $request->user();
        
        if (!$admin) {
            return response()->json([
                'success' => false,
                'message' => 'Not authenticated'
            ], 401);
        }

        // 撤銷舊 token
        $request->user()->currentAccessToken()->delete();
        
        // 生成新 token
        $token = $admin->createToken('admin-token', ['admin'])->plainTextToken;

        return response()->json([
            'success' => true,
            'message' => 'Token refreshed',
            'data' => [
                'token' => $token
            ]
        ]);
    }

    /**
     * 處理登入失敗
     */
    private function handleFailedLogin(Admin $admin, string $email, string $ipAddress, ?string $userAgent)
    {
        $admin->increment('login_attempts');
        
        // 如果失敗次數超過 5 次，鎖定帳號 30 分鐘
        if ($admin->login_attempts >= 5) {
            $admin->update([
                'locked_until' => now()->addMinutes(30)
            ]);
            $reason = 'Too many failed attempts - account locked';
        } else {
            $reason = 'Invalid password';
        }

        $this->logLoginFailure($admin->id, $email, $reason, $ipAddress, $userAgent);
    }

    /**
     * 處理登入成功
     */
    private function handleSuccessfulLogin(Admin $admin, string $ipAddress, ?string $userAgent)
    {
        $admin->update([
            'last_login' => now(),
            'login_attempts' => 0,
            'locked_until' => null
        ]);

        $this->logLoginSuccess($admin->id, $admin->email, $ipAddress, $userAgent);
    }

    /**
     * 記錄登入嘗試
     */
    private function logLoginAttempt(?int $adminId, string $email, string $ipAddress, ?string $userAgent)
    {
        // 這裡可以添加額外的登入嘗試記錄邏輯
        // 例如：檢測異常登入模式、IP 黑名單等
    }

    /**
     * 記錄登入成功
     */
    private function logLoginSuccess(int $adminId, string $email, string $ipAddress, ?string $userAgent)
    {
        AdminLoginLog::create([
            'admin_id' => $adminId,
            'login_time' => now(),
            'status' => 'success',
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
        ]);
    }

    /**
     * 記錄登入失敗
     */
    private function logLoginFailure(?int $adminId, string $email, string $reason, string $ipAddress, ?string $userAgent)
    {
        AdminLoginLog::create([
            'admin_id' => $adminId,
            'login_time' => now(),
            'status' => 'failed',
            'ip_address' => $ipAddress,
            'user_agent' => $userAgent,
        ]);
    }
}
