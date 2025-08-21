<?php

namespace Database\Seeders;

use Illuminate\Database\Console\Seeds\WithoutModelEvents;
use Illuminate\Database\Seeder;

class AdminSeeder extends Seeder
{
    /**
     * Run the database seeds.
     */
    public function run(): void
    {
        // 建立管理員角色
        $superAdminRole = \App\Models\AdminRole::firstOrCreate([
            'name' => 'super_admin'
        ], [
            'display_name' => '超級管理員',
            'description' => '擁有所有權限的超級管理員',
            'permissions' => [
                'users.list', 'users.view', 'users.edit', 'users.delete',
                'tasks.list', 'tasks.view', 'tasks.edit', 'tasks.delete',
                'services.list', 'services.view', 'services.edit', 'services.delete',
                'points.list', 'points.view', 'points.edit', 'points.delete',
                'admins.list', 'admins.view', 'admins.create', 'admins.edit', 'admins.delete',
                'roles.list', 'roles.view', 'roles.create', 'roles.edit', 'roles.delete',
                'logs.view'
            ],
            'is_active' => true
        ]);

        $adminRole = \App\Models\AdminRole::firstOrCreate([
            'name' => 'admin'
        ], [
            'display_name' => '管理員',
            'description' => '一般管理員，擁有大部分權限',
            'permissions' => [
                'users.list', 'users.view', 'users.edit',
                'tasks.list', 'tasks.view', 'tasks.edit',
                'services.list', 'services.view', 'services.edit',
                'points.list', 'points.view', 'points.edit'
            ],
            'is_active' => true
        ]);

        // 建立預設超級管理員
        \App\Models\Admin::firstOrCreate([
            'email' => 'admin@here4help.com'
        ], [
            'username' => 'superadmin',
            'full_name' => 'Super Admin',
            'password' => \Illuminate\Support\Facades\Hash::make('admin123'),
            'role_id' => $superAdminRole->id,
            'status' => 'active',
            'login_attempts' => 0
        ]);

        // 建立測試管理員
        \App\Models\Admin::firstOrCreate([
            'email' => 'test@here4help.com'
        ], [
            'username' => 'testadmin',
            'full_name' => 'Test Admin',
            'password' => \Illuminate\Support\Facades\Hash::make('test123'),
            'role_id' => $adminRole->id,
            'status' => 'active',
            'login_attempts' => 0
        ]);

        $this->command->info('Admin roles and users created successfully!');
        $this->command->info('Super Admin: admin@here4help.com / admin123');
        $this->command->info('Test Admin: test@here4help.com / test123');
    }
}
