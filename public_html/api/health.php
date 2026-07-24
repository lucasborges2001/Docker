<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
docker_api_json((new DockerStatusService())->health());
