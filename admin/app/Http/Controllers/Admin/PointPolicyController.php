<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Validator;

class PointPolicyController extends Controller
{
    public function index()
    {
        try {
            $db = $this->getBackendDB();

            $items = $db->query("
                SELECT id, title, is_active, created_at, updated_at
                FROM point_policies
                ORDER BY is_active DESC, updated_at DESC, id DESC
            ")->fetchAll(\PDO::FETCH_ASSOC);

            $items = array_map(function ($item) {
                $item['is_active'] = (int)($item['is_active'] ?? 0) === 1;
                return $item;
            }, $items);

            return response()->json([
                'success' => true,
                'data' => $items,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to load point policies: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function show(int $id)
    {
        try {
            $db = $this->getBackendDB();
            $statement = $db->prepare("
                SELECT id, title, content_json, is_active, created_at, updated_at
                FROM point_policies WHERE id = ?
            ");
            $statement->execute([$id]);
            $policy = $statement->fetch(\PDO::FETCH_ASSOC);

            if (!$policy) {
                return response()->json([
                    'success' => false,
                    'message' => 'Point policy not found',
                ], 404);
            }

            $content = json_decode($policy['content_json'], true);
            if (!is_array($content)) {
                $content = null;
            }

            $policy['is_active'] = (int)$policy['is_active'] === 1;
            $policy['content'] = $content;
            unset($policy['content_json']);

            return response()->json([
                'success' => true,
                'data' => $policy,
            ]);
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to load point policy: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'required|string|max:255',
            'content' => 'required',
            'is_active' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $db = $this->getBackendDB();
            $content = $this->normalizeContentPayload($request->input('content'));
            $contentJson = json_encode($content, JSON_UNESCAPED_UNICODE);

            $db->beginTransaction();
            try {
                $isActive = $request->boolean('is_active', false);

                if ($isActive) {
                    $db->exec('UPDATE point_policies SET is_active = 0');
                }

                $statement = $db->prepare("
                    INSERT INTO point_policies (title, content_json, is_active, created_by, updated_by, created_at, updated_at)
                    VALUES (?, ?, ?, ?, ?, NOW(), NOW())
                ");
                $statement->execute([
                    $request->input('title'),
                    $contentJson,
                    $isActive ? 1 : 0,
                    auth()->id(),
                    auth()->id(),
                ]);

                $newId = (int)$db->lastInsertId();
                $db->commit();

                $this->logPolicyAction(
                    $request,
                    'create_point_policy',
                    $newId,
                    null,
                    [
                        'title' => $request->input('title'),
                        'is_active' => $isActive ? 1 : 0,
                    ]
                );

                return $this->show($newId);
            } catch (\Exception $e) {
                $db->rollBack();
                throw $e;
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to create point policy: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function update(int $id, Request $request)
    {
        $validator = Validator::make($request->all(), [
            'title' => 'sometimes|required|string|max:255',
            'content' => 'sometimes|required',
            'is_active' => 'boolean',
        ]);

        if ($validator->fails()) {
            return response()->json([
                'success' => false,
                'message' => 'Validation failed',
                'errors' => $validator->errors(),
            ], 422);
        }

        try {
            $db = $this->getBackendDB();
            $statement = $db->prepare('SELECT id, title, is_active FROM point_policies WHERE id = ?');
            $statement->execute([$id]);
            $existing = $statement->fetch(\PDO::FETCH_ASSOC);
            if (!$existing) {
                return response()->json([
                    'success' => false,
                    'message' => 'Point policy not found',
                ], 404);
            }

            $db->beginTransaction();
            try {
                $fields = [];
                $params = [];

                if ($request->filled('title')) {
                    $fields[] = 'title = ?';
                    $params[] = $request->input('title');
                }

                if ($request->has('content')) {
                    $content = $this->normalizeContentPayload($request->input('content'));
                    $fields[] = 'content_json = ?';
                    $params[] = json_encode($content, JSON_UNESCAPED_UNICODE);
                }

                $isActiveProvided = $request->has('is_active');
                if ($isActiveProvided && $request->boolean('is_active')) {
                    $db->exec('UPDATE point_policies SET is_active = 0');
                    $fields[] = 'is_active = 1';
                } elseif ($isActiveProvided) {
                    $fields[] = 'is_active = 0';
                }

                $fields[] = 'updated_by = ?';
                $params[] = auth()->id();
                $fields[] = 'updated_at = NOW()';

                $params[] = $id;

                $sql = sprintf(
                    'UPDATE point_policies SET %s WHERE id = ?',
                    implode(', ', $fields)
                );
                $updateStatement = $db->prepare($sql);
                $updateStatement->execute($params);

                $db->commit();

                $this->logPolicyAction(
                    $request,
                    'update_point_policy',
                    $id,
                    [
                        'title' => $existing['title'],
                        'is_active' => (int) $existing['is_active'],
                    ],
                    [
                        'title' => $request->filled('title') ? $request->input('title') : $existing['title'],
                        'is_active' => $isActiveProvided
                            ? ($request->boolean('is_active') ? 1 : 0)
                            : (int) $existing['is_active'],
                    ]
                );

                return $this->show($id);
            } catch (\Exception $e) {
                $db->rollBack();
                throw $e;
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to update point policy: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function activate(int $id)
    {
        try {
            $db = $this->getBackendDB();
            $statement = $db->prepare('SELECT id, title, is_active FROM point_policies WHERE id = ?');
            $statement->execute([$id]);
            $policy = $statement->fetch(\PDO::FETCH_ASSOC);
            if (!$policy) {
                return response()->json([
                    'success' => false,
                    'message' => 'Point policy not found',
                ], 404);
            }

            $db->beginTransaction();
            try {
                $db->exec('UPDATE point_policies SET is_active = 0');
                $update = $db->prepare('UPDATE point_policies SET is_active = 1, updated_by = ?, updated_at = NOW() WHERE id = ?');
                $update->execute([auth()->id(), $id]);
                $db->commit();

                $this->logPolicyAction(
                    $request,
                    'activate_point_policy',
                    $id,
                    ['is_active' => (int) $policy['is_active']],
                    ['is_active' => 1]
                );

                return $this->show($id);
            } catch (\Exception $e) {
                $db->rollBack();
                throw $e;
            }
        } catch (\Exception $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to activate point policy: ' . $e->getMessage(),
            ], 500);
        }
    }

    private function normalizeContentPayload($content): array
    {
        if (is_string($content)) {
            $decoded = json_decode($content, true);
            if (!is_array($decoded)) {
                throw new \InvalidArgumentException('Invalid JSON content payload');
            }
            return $decoded;
        }

        if (is_array($content)) {
            return $content;
        }

        throw new \InvalidArgumentException('Invalid content payload');
    }

    private function getBackendDB()
    {
        $config = config('database.connections.backend');

        if (!$config) {
            // 回退至 Laravel 預設的資料庫連線，避免未配置 backend 連線時拋錯
            return DB::connection()->getPdo();
        }

        $dsn = sprintf(
            'mysql:host=%s;port=%s;dbname=%s;charset=utf8mb4',
            $config['host'],
            $config['port'],
            $config['database']
        );

        return new \PDO($dsn, $config['username'], $config['password'], [
            \PDO::ATTR_ERRMODE => \PDO::ERRMODE_EXCEPTION,
            \PDO::ATTR_DEFAULT_FETCH_MODE => \PDO::FETCH_ASSOC,
        ]);
    }

    private function logPolicyAction(Request $request, string $action, ?int $recordId, ?array $oldData, ?array $newData): void
    {
        $admin = $request->user();
        if (!$admin) {
            return;
        }

        DB::table('admin_activity_logs')->insert([
            'admin_id' => $admin->id,
            'action' => $action,
            'table_name' => 'point_policies',
            'record_id' => $recordId,
            'old_data' => $oldData ? json_encode($oldData) : null,
            'new_data' => $newData ? json_encode($newData) : null,
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'created_at' => now(),
        ]);
    }
}
