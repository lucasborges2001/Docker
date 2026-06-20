<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';
require_once __DIR__ . '/support/helpers.php';
$dockerService = new DockerStatusService();
$dockerSummary = $dockerService->summary();
$dockerLatest = $dockerSummary['latest'] ?? [];
$dockerHealth = $dockerSummary['health'] ?? $dockerService->health();
$dockerEvents = $dockerSummary['events'] ?? [];
$dockerHistory = $dockerSummary['history'] ?? [];
$dockerPaths = docker_config();
