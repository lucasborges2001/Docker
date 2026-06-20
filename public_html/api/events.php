<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
header('Content-Type: application/json; charset=utf-8');
$limit=isset($_GET['limit'])?(int)$_GET['limit']:50; echo json_encode(['events'=>(new DockerStatusService())->events($limit),'path'=>docker_events_log_path()], JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
