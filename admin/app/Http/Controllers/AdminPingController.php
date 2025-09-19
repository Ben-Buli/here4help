<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;

class AdminPingController extends Controller
{
    public function index()
    {
        return response()->json([
            'message' => 'Admin API is alive',
            'timestamp' => now(),
        ]);
    }

    public function test()
    {
        return response()->json([
            'message' => 'Admin API test endpoint',
            'version' => '1.0.0',
            'timestamp' => now(),
        ]);
    }

    public function admins()
    {
        return response()->json([
            'message' => 'Admins management - coming soon',
        ]);
    }

    public function dashboard()
    {
        return response()->json([
            'message' => 'Admin dashboard data',
            'timestamp' => now(),
            'server_time' => now()->toDateTimeString(),
            'uptime' => 'System operational',
        ]);
    }
}