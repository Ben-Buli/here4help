<?php
// 載入 PHP 8.4 相容性配置
require_once __DIR__ . '/../../config/php84_compatibility.php';

require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

Response::setCorsHeaders();

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(200);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    Response::methodNotAllowed('Method not allowed');
}

try {
    $db = Database::getInstance();
    $policy = $db->fetch('
        SELECT id, title, content_json, is_active, updated_at
        FROM point_policies
        WHERE is_active = 1
        ORDER BY updated_at DESC, id DESC
        LIMIT 1
    ');

    if (!$policy) {
        $policy = [
            'id' => null,
            'title' => 'Point Policy',
            'content_json' => json_encode(getDefaultPointPolicyContent(), JSON_UNESCAPED_UNICODE),
            'is_active' => 1,
            'updated_at' => date('Y-m-d H:i:s'),
        ];
    }

    $content = json_decode($policy['content_json'], true);
    if (!is_array($content)) {
        $content = getDefaultPointPolicyContent();
    }

    Response::success([
        'id' => $policy['id'],
        'title' => $policy['title'],
        'is_active' => (int)$policy['is_active'] === 1,
        'content' => $content,
        'updated_at' => $policy['updated_at'],
    ]);
} catch (Exception $e) {
    Response::serverError('Failed to load point policy: ' . $e->getMessage());
}

function getDefaultPointPolicyContent(): array
{
    return [
        'type' => 'doc',
        'content' => [
            [
                'type' => 'heading',
                'attrs' => ['level' => 2],
                'content' => [
                    ['type' => 'text', 'text' => 'Conversion Rate'],
                ],
            ],
            [
                'type' => 'paragraph',
                'content' => [
                    ['type' => 'text', 'text' => '1 Point = NT$1'],
                ],
            ],
            [
                'type' => 'heading',
                'attrs' => ['level' => 2],
                'content' => [
                    ['type' => 'text', 'text' => 'Purchasing Points & Reward Rules'],
                ],
            ],
            [
                'type' => 'table',
                'content' => [
                    [
                        'type' => 'tableRow',
                        'content' => [
                            createTableHeader('Purchase Amount (NT$)'),
                            createTableHeader('Bonus Offer'),
                        ],
                    ],
                    [
                        'type' => 'tableRow',
                        'content' => [
                            createTableCell('Below 600'),
                            createTableCell('No coupon issued'),
                        ],
                    ],
                    [
                        'type' => 'tableRow',
                        'content' => [
                            createTableCell('600–999'),
                            createTableCell('30-point discount coupon applicable to task payments (e.g., for a 600-point task, only 570 points are required after applying the coupon).'),
                        ],
                    ],
                    [
                        'type' => 'tableRow',
                        'content' => [
                            createTableCell('1,000–1499'),
                            createTableCell('Get an additional 100 points credited to your balance (e.g., pay 1,500, receive 1,600 points).'),
                        ],
                    ],
                    [
                        'type' => 'tableRow',
                        'content' => [
                            createTableCell('2,000 and above'),
                            createTableCell('Get an additional 150 points credited (e.g., pay 2000, recive 2,150 points).'),
                        ],
                    ],
                ],
            ],
            [
                'type' => 'heading',
                'attrs' => ['level' => 2],
                'content' => [
                    ['type' => 'text', 'text' => 'Points Withdrawal Policy'],
                ],
            ],
            [
                'type' => 'bulletList',
                'content' => [
                    [
                        'type' => 'listItem',
                        'content' => [
                            [
                                'type' => 'paragraph',
                                'content' => [
                                    ['type' => 'text', 'text' => 'Points earned from completed tasks will be disbursed to the task taker on the '],
                                    ['type' => 'text', 'text' => '10th of the following month', 'marks' => [['type' => 'bold']]],
                                    ['type' => 'text', 'text' => '.'],
                                ],
                            ],
                        ],
                    ],
                    [
                        'type' => 'listItem',
                        'content' => [
                            [
                                'type' => 'paragraph',
                                'content' => [
                                    ['type' => 'text', 'text' => 'Any task under dispute is excluded from scheduled disbursement.'],
                                ],
                            ],
                        ],
                    ],
                    [
                        'type' => 'listItem',
                        'content' => [
                            [
                                'type' => 'paragraph',
                                'content' => [
                                    ['type' => 'text', 'text' => 'Once a dispute is resolved, the corresponding points will be disbursed '],
                                    ['type' => 'text', 'text' => 'within 7 days', 'marks' => [['type' => 'bold']]],
                                    ['type' => 'text', 'text' => ' of resolution.'],
                                ],
                            ],
                        ],
                    ],
                ],
            ],
        ],
    ];
}

function createTableHeader(string $text): array
{
    return [
        'type' => 'tableHeader',
        'attrs' => ['colspan' => 1, 'rowspan' => 1, 'colwidth' => null],
        'content' => [
            [
                'type' => 'paragraph',
                'content' => [
                    ['type' => 'text', 'text' => $text],
                ],
            ],
        ],
    ];
}

function createTableCell(string $text): array
{
    return [
        'type' => 'tableCell',
        'attrs' => ['colspan' => 1, 'rowspan' => 1, 'colwidth' => null],
        'content' => [
            [
                'type' => 'paragraph',
                'content' => [
                    ['type' => 'text', 'text' => $text],
                ],
            ],
        ],
    ];
}
