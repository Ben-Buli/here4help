<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;

class WebController extends Controller
{
    public function index()
    {
        return view('welcome');
    }

    public function redirectRoot()
    {
        return redirect('/admin/');
    }
}