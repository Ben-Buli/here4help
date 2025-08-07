<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

require_once '../../config/database.php';
require_once '../../utils/Response.php';

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    $db = Database::getInstance();
    
    $sql = "SELECT id, code, name, native FROM languages ORDER BY name ASC";
    $languages = $db->fetchAll($sql);

    Response::success($languages, 'Languages retrieved successfully');

} catch (PDOException $e) {
    Response::error('Database error: ' . $e->getMessage(), 500);
} catch (Exception $e) {
    Response::error('Server error: ' . $e->getMessage(), 500);
}
?> 