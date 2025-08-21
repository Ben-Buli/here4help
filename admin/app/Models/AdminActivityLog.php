<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdminActivityLog extends Model
{
    use HasFactory;

    protected $fillable = [
        'admin_id',
        'action',
        'resource_type',
        'resource_id',
        'old_values',
        'new_values',
        'description',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'old_values' => 'array',
        'new_values' => 'array',
    ];

    public function admin()
    {
        return $this->belongsTo(Admin::class);
    }

    public function getActionDisplayName(): string
    {
        $actions = [
            'create' => '建立',
            'update' => '更新',
            'delete' => '刪除',
            'view' => '查看',
            'list' => '列表',
            'login' => '登入',
            'logout' => '登出',
            'unauthorized_access' => '未授權訪問',
        ];

        return $actions[$this->action] ?? $this->action;
    }

    public function getResourceDisplayName(): string
    {
        $resources = [
            'users' => '用戶',
            'tasks' => '任務',
            'services' => '服務',
            'points' => '點數',
            'admins' => '管理員',
            'roles' => '角色',
        ];

        return $resources[$this->resource_type] ?? $this->resource_type;
    }
}
