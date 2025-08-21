<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class AdminLoginLog extends Model
{
    use HasFactory;
    
    public $timestamps = false;

    protected $fillable = [
        'admin_id',
        'login_time',
        'logout_time',
        'ip_address',
        'user_agent',
        'status',
    ];

    protected $casts = [
        'login_time' => 'datetime',
        'logout_time' => 'datetime',
    ];

    public function admin()
    {
        return $this->belongsTo(Admin::class);
    }

    public function isSuccess()
    {
        return $this->status === 'success';
    }

    public function isFailed()
    {
        return $this->status === 'failed';
    }

    public function isBlocked()
    {
        return $this->status === 'blocked';
    }
}
