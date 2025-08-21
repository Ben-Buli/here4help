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
        Schema::create('admin_role_permissions', function (Blueprint $table) {
            $table->id();
            $table->unsignedBigInteger('role_id');
            $table->string('permission_name');
            $table->string('resource'); // 資源類型：users, tasks, services, points, admins
            $table->string('action'); // 動作：list, view, create, edit, delete
            $table->json('conditions')->nullable(); // 額外條件
            $table->timestamps();
            
            $table->foreign('role_id')->references('id')->on('admin_roles')->onDelete('cascade');
            $table->unique(['role_id', 'permission_name']);
            $table->index(['resource', 'action']);
        });
    }

    /**
     * Reverse the migrations.
     */
    public function down(): void
    {
        Schema::dropIfExists('admin_role_permissions');
    }
};
