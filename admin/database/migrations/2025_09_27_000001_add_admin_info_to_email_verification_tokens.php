<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('email_verification_tokens', function (Blueprint $table) {
            if (!Schema::hasColumn('email_verification_tokens', 'created_by')) {
                $table->unsignedBigInteger('created_by')
                    ->nullable()
                    ->after('user_id')
                    ->comment('Admin ID if the token was issued manually');
            }

            if (!Schema::hasColumn('email_verification_tokens', 'created_by_name')) {
                $table->string('created_by_name')
                    ->nullable()
                    ->after('created_by')
                    ->comment('Admin name snapshot');
            }
        });
    }

    public function down(): void
    {
        Schema::table('email_verification_tokens', function (Blueprint $table) {
            if (Schema::hasColumn('email_verification_tokens', 'created_by')) {
                $table->dropColumn('created_by');
            }

            if (Schema::hasColumn('email_verification_tokens', 'created_by_name')) {
                $table->dropColumn('created_by_name');
            }
        });
    }
};
