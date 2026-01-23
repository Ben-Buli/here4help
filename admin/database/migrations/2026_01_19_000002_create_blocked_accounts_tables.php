<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('blocked_emails', function (Blueprint $table) {
            $table->id();
            $table->string('email', 191)->unique();
            $table->text('reason')->nullable();
            $table->unsignedBigInteger('blocked_by')->nullable();
            $table->timestamp('blocked_at')->nullable();
            $table->string('source', 50)->nullable();
            $table->timestamps();
        });

        Schema::create('blocked_identities', function (Blueprint $table) {
            $table->id();
            $table->string('provider', 50);
            $table->string('provider_user_id', 255);
            $table->text('reason')->nullable();
            $table->unsignedBigInteger('blocked_by')->nullable();
            $table->timestamp('blocked_at')->nullable();
            $table->string('source', 50)->nullable();
            $table->timestamps();

            $table->unique(['provider', 'provider_user_id'], 'uq_blocked_provider_uid');
            $table->index(['provider', 'provider_user_id']);
        });
    }

    public function down(): void
    {
        Schema::dropIfExists('blocked_identities');
        Schema::dropIfExists('blocked_emails');
    }
};
