<?php

namespace App\Http\Controllers\Admin;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use App\Models\AdminActivityLog;

class AppTermsController extends Controller
{
    public function index()
    {
        try {
            $db = $this->getBackendDB();
            $items = $db->query("
                SELECT at.*, creator.full_name AS created_by_full_name, creator.username AS created_by_username, creator.email AS created_by_email
                FROM app_terms at
                LEFT JOIN admins AS creator ON creator.id = at.created_by
                WHERE at.type = 'terms'
                ORDER BY at.is_active DESC, COALESCE(at.published_at, at.created_at) DESC, at.id DESC
            ")->fetchAll(\PDO::FETCH_ASSOC);

            $items = array_map(function ($row) {
                return $this->formatTermRow($row);
            }, $items);

            return response()->json([
                'success' => true,
                'data' => $items,
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to load terms: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function show(int $id)
    {
        try {
            $db = $this->getBackendDB();
            $statement = $db->prepare("
                SELECT at.*, creator.full_name AS created_by_full_name, creator.username AS created_by_username, creator.email AS created_by_email
                FROM app_terms at
                LEFT JOIN admins AS creator ON creator.id = at.created_by
                WHERE at.id = ?
            ");
            $statement->execute([$id]);
            $term = $statement->fetch(\PDO::FETCH_ASSOC);

            if (!$term) {
                return response()->json([
                    'success' => false,
                    'message' => 'Terms not found',
                ], 404);
            }

            return response()->json([
                'success' => true,
                'data' => $this->formatTermRow($term),
            ]);
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to load terms: ' . $e->getMessage(),
            ], 500);
        }
    }

    public function push(int $id, Request $request)
    {
        try {
            $db = $this->getBackendDB();
            $statement = $db->prepare("
                SELECT id, slug, type, title, summary, content, requires_ack
                FROM app_terms
                WHERE id = ?
            ");
            $statement->execute([$id]);
            $baseTerm = $statement->fetch(\PDO::FETCH_ASSOC);

            if (!$baseTerm) {
                return response()->json([
                    'success' => false,
                    'message' => 'Terms not found',
                ], 404);
            }

            $db->beginTransaction();
            try {
                $db->exec('UPDATE app_terms SET is_active = 0');

                $title = $request->input('title', $baseTerm['title']);
                $summary = $request->input('summary', $baseTerm['summary']);
                $content = $request->input('content', $baseTerm['content']);
                $requiresAck = $request->has('requires_ack')
                    ? $request->boolean('requires_ack')
                    : (int)($baseTerm['requires_ack'] ?? 1) === 1;

                $insert = $db->prepare("
                    INSERT INTO app_terms (slug, type, title, summary, content, is_active, requires_ack, created_by, created_at, updated_at, published_at)
                    VALUES (?, ?, ?, ?, ?, 1, ?, ?, NOW(), NOW(), NOW())
                ");
                $insert->execute([
                    $this->generateNewSlug($baseTerm['slug'] ?? null),
                    $baseTerm['type'] ?? 'terms',
                    $title,
                    $summary,
                    $content,
                    $requiresAck ? 1 : 0,
                    auth()->id(),
                ]);

                $newId = (int)$db->lastInsertId();
                $db->commit();

                $this->recordAdminActivity(
                    $request,
                    'create',
                    'app_terms',
                    $newId,
                    [
                        'source_term_id' => $baseTerm['id'] ?? null,
                        'source_version' => $baseTerm['slug'] ?? null,
                        'previous_active_id' => $baseTerm['id'] ?? null,
                    ],
                    [
                        'title' => $title,
                        'summary' => $summary,
                        'requires_ack' => $requiresAck,
                        'content_length' => strlen($content ?? ''),
                    ]
                );

                return $this->show($newId);
            } catch (\Throwable $e) {
                $db->rollBack();
                throw $e;
            }
        } catch (\Throwable $e) {
            return response()->json([
                'success' => false,
                'message' => 'Failed to push new version: ' . $e->getMessage(),
            ], 500);
        }
    }

    private function generateNewSlug(?string $baseSlug): string
    {
        $prefix = $baseSlug ?: 'terms_of_service';
        $normalized = strtolower(preg_replace('/[^a-z0-9_]+/i', '_', $prefix));
        return trim($normalized, '_') . '_' . date('YmdHis');
    }

    private function getBackendDB()
    {
        $config = config('database.connections.backend');

        if (!$config) {
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

    private function formatTermRow(?array $row): ?array
    {
        if (!$row) {
            return null;
        }

        $row['is_active'] = (int)($row['is_active'] ?? 0) === 1;
        $row['requires_ack'] = (int)($row['requires_ack'] ?? 0) === 1;
        $row['version'] = $row['slug'];
        $row['created_by_admin'] = null;
        if (!empty($row['created_by'])) {
            $row['created_by_admin'] = [
                'id' => (int)$row['created_by'],
                'name' => $row['created_by_full_name'] ?? null,
                'username' => $row['created_by_username'] ?? null,
                'email' => $row['created_by_email'] ?? null,
            ];
        }
        unset($row['created_by_full_name'], $row['created_by_username'], $row['created_by_email']);
        return $row;
    }

    private function recordAdminActivity(
        Request $request,
        string $action,
        string $table,
        int $recordId,
        ?array $oldData = null,
        ?array $newData = null
    ): void {
        try {
            AdminActivityLog::create([
                'admin_id' => auth()->id(),
                'action' => $action,
                'table_name' => $table,
                'record_id' => $recordId,
                'old_data' => $oldData,
                'new_data' => $newData,
                'ip_address' => $request->ip(),
                'user_agent' => $request->userAgent(),
            ]);
        } catch (\Throwable $e) {
            Log::warning('Failed to record admin activity for terms', [
                'error' => $e->getMessage(),
                'action' => $action,
                'table' => $table,
                'record_id' => $recordId,
            ]);
        }
    }
}
