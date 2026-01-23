<?php

namespace App\Http\Controllers;

use App\Mail\PasswordResetMail;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Facades\Mail;

class PasswordResetController extends Controller
{
    public function forgot(Request $request)
    {
        $validated = $request->validate([
            'email' => 'required|email',
        ]);

        $email = trim($validated['email']);
        $user = DB::table('users')->where('email', $email)->first();

        // 不暴露帳號是否存在
        if (!$user) {
            return $this->genericResponse();
        }

        $permission = (int)($user->permission ?? 0);
        if ($permission < 0 && $permission != -1) {
            return $this->genericResponse();
        }

        $now = Carbon::now();
        $token = bin2hex(random_bytes(32));
        $expiresAt = $now->copy()->addHour();

        DB::beginTransaction();
        try {
            DB::table('email_verification_tokens')
                ->where('user_id', $user->id)
                ->where('type', 'password_reset')
                ->where('used', 0)
                ->update([
                    'used' => 1,
                    'used_at' => $now,
                ]);

            DB::table('email_verification_tokens')->insert([
                'user_id' => $user->id,
                'token' => $token,
                'type' => 'password_reset',
                'expires_at' => $expiresAt,
                'used' => 0,
                'created_at' => $now,
            ]);

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();
            Log::error('Failed to create password reset token', [
                'user_id' => $user->id,
                'error' => $e->getMessage(),
            ]);
            return response()->json([
                'success' => false,
                'message' => 'Unable to process the request right now.',
            ], 500);
        }

        $resetLink = $this->buildPasswordResetLink($token, $email);

        try {
            Mail::to($email)->send(new PasswordResetMail(
                userName: $user->name ?? 'User',
                resetLink: $resetLink,
                expiresAt: $expiresAt
            ));
        } catch (\Throwable $mailError) {
            Log::error('Password reset mail send failed', [
                'user_id' => $user->id,
                'error' => $mailError->getMessage(),
            ]);
        }

        try {
            DB::table('user_activity_logs')->insert([
                'user_id' => $user->id,
                'action' => 'password_reset_requested',
                'details' => json_encode([
                    'email' => $email,
                    'token_expires_at' => $expiresAt->toDateTimeString(),
                ], JSON_UNESCAPED_UNICODE),
                'ip_address' => $request->ip(),
                'created_at' => $now,
            ]);
        } catch (\Throwable $logError) {
            Log::warning('Failed to log password reset request', [
                'user_id' => $user->id,
                'error' => $logError->getMessage(),
            ]);
        }

        return $this->genericResponse();
    }

    private function genericResponse()
    {
        return response()->json([
            'success' => true,
            'message' => 'If this email exists in our system, you will receive a password reset link shortly.',
        ]);
    }

    private function buildPasswordResetLink(string $token, string $email): string
    {
        $baseUrl = $this->getPasswordResetBaseUrl();
        return $baseUrl . '?token=' . urlencode($token) . '&email=' . urlencode($email);
    }

    private function getPasswordResetBaseUrl(): string
    {
        $configured = trim((string) env('PASSWORD_RESET_PAGE_URL', ''));
        if ($configured !== '') {
            return rtrim($configured, '/');
        }

        $appUrl = config('app.url', env('APP_URL', 'http://localhost'));
        $appUrl = rtrim($appUrl ?: 'http://localhost', '/');

        if (str_ends_with($appUrl, '/admin')) {
            $appUrl = rtrim(substr($appUrl, 0, -strlen('/admin')), '/');
        }

        return rtrim($appUrl, '/') . '/account/reset-password';
    }
}
