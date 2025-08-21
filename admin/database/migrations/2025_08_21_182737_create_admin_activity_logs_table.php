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
        Schema::create('admin_activity_logs', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('admin_id');
            $table->string('action'); // 動作類型
            $table->string('resource_type')->nullable(); // 資源類型
            $table->unsignedBigInteger('resource_id')->nullable(); // 資源 ID
            $table->json('old_values')->nullable(); // 修改前的值
            $table->json('new_values')->nullable(); // 修改後的值
            $table->text('description')->nullable(); // 描述
            $table->string('ip_address')->nullable();
            $table->text('user_agent')->nullable();
            $table->timestamps();
            
            $table->foreign('admin_id')->references('id')->on('admins')->onDelete('cascade');
            $table->index(['admin_id', 'created_at']);
            $table->index(['resource_type', 'resource_id']);
            $table->index('action');
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admin_activity_logs');
    }
};
