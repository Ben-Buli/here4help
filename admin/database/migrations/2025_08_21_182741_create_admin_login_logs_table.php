<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * Run the migrations.
     */
    public function up(): void
    {
        Schema::create('admin_login_logs', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('admin_id')->nullable(); // 可能登入失敗
            $table->string('email'); // 嘗試登入的 email
            $table->enum('status', ['success', 'failed', 'blocked']); // 登入狀態
            $table->string('failure_reason')->nullable(); // 失敗原因
            $table->string('ip_address');
            $table->text('user_agent')->nullable();
            $table->timestamp('attempted_at');
            $table->timestamps();
            
            $table->foreign('admin_id')->references('id')->on('admins')->onDelete('set null');
            $table->index(['admin_id', 'attempted_at']);
            $table->index(['email', 'status', 'attempted_at']);
            $table->index(['ip_address', 'attempted_at']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admin_login_logs');
    }
};
