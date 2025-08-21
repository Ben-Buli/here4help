<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
	exit(0);
}

require_once __DIR__ . '/../../config/env_loader.php';
require_once __DIR__ . '/../../config/database.php';
require_once __DIR__ . '/../../utils/Response.php';

try {
	if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
		http_response_code(405);
		echo json_encode(['error' => 'Method not allowed']);
		exit;
	}

	$token = $_GET['token'] ?? '';
	$peek = isset($_GET['peek']) && $_GET['peek'] === 'true';

	if (empty($token)) {
		http_response_code(400);
		echo json_encode(['error' => 'Token is required']);
		exit;
	}

	$db = Database::getInstance();
	$stmt = $db->query(
		"SELECT provider, provider_user_id, email, name, avatar_url, raw_data, expired_at \n\
		 FROM oauth_temp_users WHERE token = ?",
		[$token]
	);
	$row = $stmt->fetch();

	if (!$row) {
		http_response_code(404);
		echo json_encode(['error' => 'Token not found']);
		exit;
	}

	if (!empty($row['expired_at']) && strtotime($row['expired_at']) <= time()) {
		http_response_code(410);
		echo json_encode(['error' => 'Token expired']);
		exit;
	}

	$response = [
		'provider' => $row['provider'],
		'provider_user_id' => $row['provider_user_id'],
		'email' => $row['email'] ?? null,
		'name' => $row['name'] ?? null,
		'avatar_url' => $row['avatar_url'] ?? null,
		'raw_data' => $row['raw_data'] ? json_decode($row['raw_data'], true) : null,
	];

	// peek=true 僅查看；資料消費留待 register-oauth
	echo json_encode($response);
	exit;
} catch (Exception $e) {
	http_response_code(500);
	echo json_encode(['error' => $e->getMessage()]);
	exit;
}

?>


