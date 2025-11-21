<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use App\Models\Admin;
use Carbon\Carbon;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;

class AdminPasswordResetController extends Controller
{
    public function show(Request $request)
    {
        return view('admin.reset-password');
    }

    public function reset(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'token' => 'required|string',
            'email' => 'required|email',
            'new_password' => [
                'required',
                'string',
                'min:8',
                'regex:/[a-z]/',
                'regex:/[A-Z]/',
                'regex:/\d/',
            ],
            'confirm_password' => 'required|same:new_password',
        ], [
            'new_password.regex' => 'Password must contain uppercase, lowercase letters, and numbers.',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        $tokenRecord = DB::table('admin_verification_tokens')
            ->where('token', $request->token)
            ->where('type', 'password_reset')
            ->where('used', 0)
            ->where('expires_at', '>', Carbon::now())
            ->orderByDesc('created_at')
            ->first();

        if (!$tokenRecord) {
            return response()->json([
                'success' => false,
                'message' => 'Invalid or expired reset link.',
            ], 422);
        }

        $admin = Admin::where('id', $tokenRecord->admin_id)
            ->where('email', $request->email)
            ->first();

        if (!$admin) {
            return response()->json([
                'success' => false,
                'message' => 'Admin not found for provided email.',
            ], 404);
        }

        if (Hash::check($request->new_password, $admin->password)) {
            return response()->json([
                'success' => false,
                'message' => 'New password must be different from the current password.',
            ], 422);
        }

        DB::beginTransaction();
        try {
            $admin->password = Hash::make($request->new_password);
            $admin->login_attempts = 0;
            $admin->locked_until = null;
            $admin->save();

            DB::table('admin_verification_tokens')
                ->where('id', $tokenRecord->id)
                ->update([
                    'used' => 1,
                    'used_at' => Carbon::now(),
                ]);

            DB::table('admin_activity_logs')->insert([
                'admin_id' => $admin->id,
                'action' => 'admin_password_reset',
                'table_name' => 'admins',
                'record_id' => $admin->id,
                'old_data' => null,
                'new_data' => json_encode([
                    'reset_at' => Carbon::now()->toDateTimeString(),
                    'token_created_by' => $tokenRecord->created_by,
                ]),
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
                'created_at' => now(),
            ]);

            DB::commit();
        } catch (\Throwable $e) {
            DB::rollBack();

            return response()->json([
                'success' => false,
                'message' => 'Failed to reset password. Please try again.',
            ], 500);
        }

        return response()->json([
            'success' => true,
            'message' => 'Password reset successfully. You may now log in with the new password.',
        ]);
    }
}
