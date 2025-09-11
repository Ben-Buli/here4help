<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdminActivityLog extends Model
{
    use HasFactory;

    // 禁用自動時間戳記，因為表只有 created_at
    public $timestamps = false;
    
    // 或者只啟用 created_at
    const CREATED_AT = 'created_at';
    const UPDATED_AT = null;

    protected $fillable = [
        'admin_id',
        'action',
        'table_name',
        'record_id',
        'old_data',
        'new_data',
        'ip_address',
        'user_agent',
    ];

    protected $casts = [
        'old_data' => 'array',
        'new_data' => 'array',
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

        return $resources[$this->table_name] ?? $this->table_name;
    }
}
