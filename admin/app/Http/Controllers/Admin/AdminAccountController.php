<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Carbon\Carbon;
use Exception;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;

class AdminAccountController extends Controller
{
    public function index(Request $request)
    {
        $page = max((int) $request->get('page', 1), 1);
        $perPage = max(min((int) $request->get('per_page', 20), 100), 1);
        $search = trim((string) $request->get('search', ''));
        $status = $request->get('status');
        $role = $request->get('role');
        $sortBy = $request->get('sort_by', 'id');
        $sortOrder = strtolower($request->get('sort_order', 'desc')) === 'asc' ? 'asc' : 'desc';

        $allowedSort = ['id', 'full_name', 'email', 'status', 'last_login', 'created_at'];
        if (!in_array($sortBy, $allowedSort)) {
            $sortBy = 'id';
        }

        $query = DB::table('admins')
            ->leftJoin('admin_roles', 'admins.role_id', '=', 'admin_roles.id')
            ->select([
                'admins.id',
                'admins.username',
                'admins.full_name',
                'admins.email',
                'admins.status',
                'admins.last_login',
                'admins.login_attempts',
                'admins.locked_until',
                'admins.created_at',
                'admin_roles.name as role_name',
            ]);

        if ($search !== '') {
            $query->where(function ($q) use ($search) {
                $q->where('admins.full_name', 'LIKE', "%{$search}%")
                    ->orWhere('admins.email', 'LIKE', "%{$search}%")
                    ->orWhere('admins.username', 'LIKE', "%{$search}%");
            });
        }

        if ($status) {
            $query->where('admins.status', $status);
        }

        if ($role) {
            $query->where('admin_roles.name', $role);
        }

        $total = (clone $query)->count();

        $admins = $query
            ->orderBy($sortBy === 'role_name' ? 'admin_roles.name' : "admins.$sortBy", $sortOrder)
            ->offset(($page - 1) * $perPage)
            ->limit($perPage)
            ->get()
            ->map(function ($admin) {
                return [
                    'id' => (int) $admin->id,
                    'username' => $admin->username,
                    'full_name' => $admin->full_name,
                    'email' => $admin->email,
                    'status' => $admin->status,
                    'last_login' => $admin->last_login,
                    'login_attempts' => (int) $admin->login_attempts,
                    'locked_until' => $admin->locked_until,
                    'created_at' => $admin->created_at,
                    'role' => [
                        'name' => $admin->role_name,
                        'display_name' => $admin->role_name, // 直接顯示原始名稱，不轉換成中文
                    ],
                ];
            });

        return response()->json([
            'success' => true,
            'data' => [
                'items' => $admins,
                'pagination' => [
                    'current_page' => $page,
                    'per_page' => $perPage,
                    'total' => $total,
                    'last_page' => (int) ceil($total / $perPage),
                ],
            ],
        ]);
    }

    public function passwordResetLink(Request $request, int $adminId)
    {
        $actor = $request->user();
        $target = Admin::with('role')->find($adminId);

        if (!$target) {
            return response()->json([
                'success' => false,
                'message' => 'Admin not found',
            ], 404);
        }

        $actor->loadMissing('role');
        $target->loadMissing('role');

        if (!$this->canIssueReset($actor, $target)) {
            return response()->json([
                'success' => false,
                'message' => 'You are not allowed to reset this admin password.',
            ], 403);
        }

        $now = Carbon::now();

        $tokenRecord = DB::table('admin_verification_tokens')
            ->where('admin_id', $target->id)
            ->where('type', 'password_reset')
            ->where('used', 0)
            ->where('expires_at', '>', $now)
            ->orderByDesc('created_at')
            ->first();

        $isNew = false;

        DB::beginTransaction();
        try {
            if (!$tokenRecord) {
                DB::table('admin_verification_tokens')
                    ->where('admin_id', $target->id)
                    ->where('type', 'password_reset')
                    ->where('used', 0)
                    ->update([
                        'used' => 1,
                        'used_at' => $now,
                    ]);

                $token = bin2hex(random_bytes(32));
                $expiresAt = (clone $now)->addHour();

                $tokenId = DB::table('admin_verification_tokens')->insertGetId([
                    'admin_id' => $target->id,
                    'token' => $token,
                    'type' => 'password_reset',
                    'expires_at' => $expiresAt,
                    'used' => 0,
                    'created_by' => $actor->id,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $tokenRecord = DB::table('admin_verification_tokens')->where('id', $tokenId)->first();
                $isNew = true;
            }

            DB::commit();
        } catch (Exception $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => 'Failed to generate reset link: ' . $e->getMessage(),
            ], 500);
        }

        $expiresAt = Carbon::parse($tokenRecord->expires_at);
        $resetLink = $this->buildResetLink($tokenRecord->token, $target->email);

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $actor->id,
            'action' => $isNew ? 'admin_password_reset_link_created' : 'admin_password_reset_link_viewed',
            'table_name' => 'admins',
            'record_id' => $target->id,
            'old_data' => null,
            'new_data' => json_encode([
                'target_admin_id' => $target->id,
                'target_email' => $target->email,
                'expires_at' => $expiresAt->toDateTimeString(),
                'was_existing_link' => !$isNew,
            ]),
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);

        $creatorName = DB::table('admins')->where('id', $tokenRecord->created_by)->value('full_name');

        return response()->json([
            'success' => true,
            'message' => $isNew ? 'Password reset link generated successfully.' : 'An active password reset link already exists.',
            'data' => [
                'admin_id' => $target->id,
                'admin_name' => $target->full_name,
                'admin_email' => $target->email,
                'role_name' => $target->role?->name,
                'reset_link' => $resetLink,
                'token' => $tokenRecord->token,
                'expires_at' => $expiresAt->toDateTimeString(),
                'remaining_seconds' => max(0, $now->diffInSeconds($expiresAt, false)),
                'created_at' => Carbon::parse($tokenRecord->created_at)->toDateTimeString(),
                'created_by' => (int) $tokenRecord->created_by,
                'created_by_name' => $creatorName,
                'was_existing_link' => !$isNew,
            ],
        ]);
    }

    private function canIssueReset(Admin $actor, Admin $target): bool
    {
        $actorRole = optional($actor->role)->name;
        $targetRole = optional($target->role)->name;

        if (!$actorRole || !in_array($actorRole, ['super_admin', 'developer'])) {
            return false;
        }

        if ($actorRole === 'super_admin' && $targetRole === 'developer') {
            return false;
        }

        return true;
    }

    private function buildResetLink(string $token, string $email): string
    {
        $baseUrl = rtrim(config('app.admin_password_reset_url') ?: config('app.url', 'http://localhost') . '/admin/reset-password', '/');
        if (!str_contains($baseUrl, 'http')) {
            $baseUrl = rtrim(config('app.url', 'http://localhost'), '/') . '/' . ltrim($baseUrl, '/');
        }

        return $baseUrl . '?token=' . urlencode($token) . '&email=' . urlencode($email);
    }

    private function getRoleDisplayName(?string $roleName): string
    {
        $map = [
            'super_admin' => '超級管理員',
            'admin' => '管理員',
            'moderator' => '版主',
            'developer' => '開發者',
            'support' => '客服',
        ];

        return $map[$roleName] ?? ($roleName ?: 'Unknown');
    }
}
