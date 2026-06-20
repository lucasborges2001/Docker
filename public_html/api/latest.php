<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
header('Content-Type: application/json; charset=utf-8');
$s=new DockerStatusService(); $l=$s->latest(); http_response_code($l===null?404:200); echo json_encode($l ?: $s->health(), JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);
