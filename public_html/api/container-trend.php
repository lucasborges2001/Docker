<?php
declare(strict_types=1);
require_once __DIR__ . '/_common.php';
$ref = $_GET['container_ref'] ?? null;
if (!is_string($ref) || strlen($ref) > 220
    || !preg_match('/\A(?:name:[a-z0-9_.-]+|compose:[a-z0-9_.-]+\/[a-z0-9_.-]+\/[a-z0-9_.-]+)\z/', $ref)) {
    docker_api_json(['ok' => false, 'module' => DOCKER_MODULE_NAME, 'error' => ['code' => 'invalid_container_ref']], 400);
    exit;
}
$limit = isset($_GET['limit']) && is_scalar($_GET['limit']) ? (int)$_GET['limit'] : 20;
docker_api_json([
    'module' => DOCKER_MODULE_NAME,
    'container_ref' => $ref,
    'samples' => (new DockerStatusService())->containerTrend($ref, $limit),
]);
