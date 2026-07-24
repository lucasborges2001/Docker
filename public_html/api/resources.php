<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$resources=(new DockerStatusService())->resources();
docker_api_json($resources,$resources['available']??false?200:404);
