<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
header('Content-Type: application/json; charset=utf-8');
$limit=isset($_GET['limit'])?(int)$_GET['limit']:10; echo json_encode(['history'=>(new DockerHistoryService())->recent($limit)], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
