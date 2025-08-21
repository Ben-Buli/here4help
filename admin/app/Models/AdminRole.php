<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdminRole extends Model
{
    use HasFactory;

    protected $fillable = [
        'name',
        'description',
    ];

    // 靜態權限配置（適配現有簡單表結構）
    protected static $rolePermissions = [
        'super_admin' => [
            'users.list', 'users.view', 'users.edit', 'users.delete',
            'tasks.list', 'tasks.view', 'tasks.edit', 'tasks.delete',
            'services.list', 'services.view', 'services.edit', 'services.delete',
            'points.list', 'points.view', 'points.edit', 'points.delete',
            'admins.list', 'admins.view', 'admins.create', 'admins.edit', 'admins.delete',
            'roles.list', 'roles.view', 'roles.create', 'roles.edit', 'roles.delete',
            'logs.view'
        ],
        'admin' => [
            'users.list', 'users.view', 'users.edit',
            'tasks.list', 'tasks.view', 'tasks.edit',
            'services.list', 'services.view', 'services.edit',
            'points.list', 'points.view', 'points.edit'
        ],
        'moderator' => [
            'users.list', 'users.view',
            'tasks.list', 'tasks.view', 'tasks.edit',
            'services.list', 'services.view'
        ],
        'developer' => [
            'users.list', 'users.view',
            'tasks.list', 'tasks.view',
            'logs.view'
        ],
        'support' => [
            'users.list', 'users.view',
            'services.list', 'services.view'
        ]
    ];

    // 動態獲取權限
    public function getPermissionsAttribute()
    {
        return self::$rolePermissions[$this->name] ?? [];
    }

    // 獲取顯示名稱
    public function getDisplayNameAttribute()
    {
        $displayNames = [
            'super_admin' => '超級管理員',
            'admin' => '管理員',
            'moderator' => '版主',
            'developer' => '開發者',
            'support' => '客服'
        ];
        
        return $displayNames[$this->name] ?? $this->name;
    }

    public function admins()
    {
        return $this->hasMany(Admin::class, 'role_id');
    }

    public function rolePermissions()
    {
        return $this->hasMany(AdminRolePermission::class, 'role_id');
    }

    public function hasPermission($permission)
    {
        $permissions = $this->permissions ?? [];
        return in_array($permission, $permissions);
    }

    public function addPermission($permission)
    {
        $permissions = $this->permissions ?? [];
        if (!in_array($permission, $permissions)) {
            $permissions[] = $permission;
            $this->permissions = $permissions;
        }
    }

    public function removePermission($permission)
    {
        $permissions = $this->permissions ?? [];
        $this->permissions = array_values(array_diff($permissions, [$permission]));
    }
}
