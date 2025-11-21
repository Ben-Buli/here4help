<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (Schema::hasTable('admin_verification_tokens')) {
            return;
        }

        Schema::create('admin_verification_tokens', function (Blueprint $table) {
            $table->bigIncrements('id');
            $table->unsignedBigInteger('admin_id');
            $table->string('token', 64);
            $table->enum('type', ['email_verification', 'password_reset'])->default('email_verification');
            $table->timestamp('expires_at')->nullable();
            $table->boolean('used')->default(false);
            $table->timestamp('used_at')->nullable();
            $table->unsignedBigInteger('created_by');
            $table->timestamps();

            $table->index('admin_id');
            $table->index('created_by');

            $table->foreign('admin_id')
                ->references('id')->on('admins')
                ->onDelete('cascade')
                ->onUpdate('cascade');

            $table->foreign('created_by')
                ->references('id')->on('admins')
                ->onDelete('restrict')
                ->onUpdate('cascade');
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('admin_verification_tokens');
    }
};
