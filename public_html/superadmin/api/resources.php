<?php
declare(strict_types=1);
require_once __DIR__ . '/../support/api.php';
$resources=(new DockerStatusService())->resources();
docker_superadmin_json($resources,(bool)($resources['available']??false)?200:404);
