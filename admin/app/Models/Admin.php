<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Sanctum\HasApiTokens;

class Admin extends Authenticatable
{
    use HasApiTokens, HasFactory, Notifiable;

    protected $fillable = [
        'username',
        'full_name',
        'email',
        'password',
        'role_id',
        'status',
        'last_login',
        'login_attempts',
        'locked_until',
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

    protected $casts = [
        'email_verified_at' => 'datetime',
        'last_login' => 'datetime',
        'locked_until' => 'datetime',
        'password' => 'hashed',
    ];

    public function role()
    {
        return $this->belongsTo(AdminRole::class, 'role_id');
    }

    public function activityLogs()
    {
        return $this->hasMany(AdminActivityLog::class);
    }

    public function loginLogs()
    {
        return $this->hasMany(AdminLoginLog::class);
    }

    public function hasPermission($permission)
    {
        if (!$this->role) {
            return false;
        }

        $permissions = $this->role->permissions ?? [];
        return in_array($permission, $permissions);
    }

    public function isActive()
    {
        return $this->status === 'active';
    }
}
