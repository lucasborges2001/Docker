<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
header('Content-Type: application/json; charset=utf-8');
echo json_encode((new DockerStatusService())->health(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
