<?php

namespace App\Http\Middleware;

use App\Models\AdminActivityLog;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AdminMiddleware
{
    /**
     * Handle an incoming request.
     *
     * @param  \Closure(\Illuminate\Http\Request): (\Symfony\Component\HttpFoundation\Response)  $next
     * @param  string|null  $permission  需要的權限
     */
    public function handle(Request $request, Closure $next, string $permission = null): Response
    {
        $admin = $request->user();

        // 檢查是否已認證
        if (!$admin) {
            return response()->json([
                'success' => false,
                'message' => 'Unauthorized - Admin authentication required'
            ], 401);
        }

        // 檢查管理員狀態
        if (!$admin->isActive()) {
            return response()->json([
                'success' => false,
                'message' => 'Account is inactive'
            ], 403);
        }

        // 檢查帳號是否被鎖定
        if ($admin->locked_until && $admin->locked_until > now()) {
            return response()->json([
                'success' => false,
                'message' => 'Account is temporarily locked'
            ], 403);
        }

        // 檢查特定權限（如果指定）
        if ($permission && !$admin->hasPermission($permission)) {
            $this->logUnauthorizedAccess($admin, $request, $permission);
            
            return response()->json([
                'success' => false,
                'message' => 'Insufficient permissions',
                'required_permission' => $permission
            ], 403);
        }

        // 記錄管理員活動（僅對修改操作）
        if (in_array($request->method(), ['POST', 'PUT', 'PATCH', 'DELETE'])) {
            $this->logAdminActivity($admin, $request);
        }

        return $next($request);
    }

    /**
     * 記錄管理員活動
     */
    private function logAdminActivity($admin, Request $request)
    {
        try {
            $action = $this->getActionFromRequest($request);
            $resourceType = $this->getResourceTypeFromRequest($request);
            
            AdminActivityLog::create([
                'admin_id' => $admin->id,
                'action' => $action,
                'resource_type' => $resourceType,
                'resource_id' => $this->getResourceIdFromRequest($request),
                'description' => $this->getDescriptionFromRequest($request),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        } catch (\Exception $e) {
            // 記錄失敗不應該影響正常流程
            \Log::error('Failed to log admin activity: ' . $e->getMessage());
        }
    }

    /**
     * 記錄未授權訪問嘗試
     */
    private function logUnauthorizedAccess($admin, Request $request, string $permission)
    {
        try {
            AdminActivityLog::create([
                'admin_id' => $admin->id,
                'action' => 'unauthorized_access',
                'description' => "Attempted to access {$request->path()} without permission: {$permission}",
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        } catch (\Exception $e) {
            \Log::error('Failed to log unauthorized access: ' . $e->getMessage());
        }
    }

    /**
     * 從請求中獲取動作類型
     */
    private function getActionFromRequest(Request $request): string
    {
        $method = $request->method();
        $path = $request->path();

        // 根據 HTTP 方法和路徑推斷動作
        switch ($method) {
            case 'GET':
                return str_contains($path, '/') ? 'view' : 'list';
            case 'POST':
                return 'create';
            case 'PUT':
            case 'PATCH':
                return 'update';
            case 'DELETE':
                return 'delete';
            default:
                return strtolower($method);
        }
    }

    /**
     * 從請求中獲取資源類型
     */
    private function getResourceTypeFromRequest(Request $request): ?string
    {
        $path = $request->path();
        
        // 從 API 路徑中提取資源類型
        if (preg_match('/admin\/([^\/]+)/', $path, $matches)) {
            return $matches[1];
        }

        return null;
    }

    /**
     * 從請求中獲取資源 ID
     */
    private function getResourceIdFromRequest(Request $request): ?int
    {
        $path = $request->path();
        
        // 從路徑中提取數字 ID
        if (preg_match('/\/(\d+)(?:\/|$)/', $path, $matches)) {
            return (int) $matches[1];
        }

        return null;
    }

    /**
     * 從請求中獲取描述
     */
    private function getDescriptionFromRequest(Request $request): string
    {
        $method = $request->method();
        $path = $request->path();
        $action = $this->getActionFromRequest($request);
        $resourceType = $this->getResourceTypeFromRequest($request);

        return "Admin {$action} on {$resourceType} via {$method} {$path}";
    }
}
