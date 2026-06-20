<?php
declare(strict_types=1);

if (!function_exists('docker_bootstrap_base_candidates')) {
    function docker_bootstrap_base_candidates(): array {
        $root = dirname(__DIR__);
        $out = [];
        $env = getenv('BASE_DIR');
        if (is_string($env) && $env !== '') $out[] = rtrim($env, '/');
        $out[] = dirname($root) . '/Base';
        $out[] = dirname(__DIR__, 2) . '/Base';
        $out[] = '/opt/base';
        return array_values(array_unique($out));
    }
}
if (!function_exists('docker_resolve_base_dir')) {
    function docker_resolve_base_dir(): ?string {
        foreach (docker_bootstrap_base_candidates() as $candidate) {
            if (is_dir($candidate . '/back') || is_dir($candidate . '/lib/shell')) return $candidate;
        }
        return null;
    }
}
if (!function_exists('docker_require_if_file')) {
    function docker_require_if_file(string $file): bool { if (is_file($file)) { require_once $file; return true; } return false; }
}
$__dockerBaseDir = docker_resolve_base_dir();
if ($__dockerBaseDir !== null) {
    if (is_file($__dockerBaseDir . '/back/bootstrap.php')) {
        require_once $__dockerBaseDir . '/back/bootstrap.php';
        if (function_exists('base_bootstrap_load_core')) base_bootstrap_load_core();
    }
    foreach ([
        '/back/metrics/MetricSeverity.php',
        '/back/metrics/MetricStatus.php',
        '/back/metrics/MetricSnapshot.php',
        '/back/metrics/MetricSnapshotReader.php',
        '/back/metrics/MetricSnapshotNormalizer.php',
        '/back/metrics/JsonMetricSnapshotRepository.php',
        '/back/telegram/TelegramHtml.php',
        '/back/telegram/TelegramResponseParser.php',
    ] as $f) docker_require_if_file($__dockerBaseDir . $f);
}
foreach ([
    '/support/contracts.php',
    '/support/paths.php',
    '/support/config.php',
    '/metrics/DockerMetricSummary.php',
    '/metrics/DockerSnapshotNormalizer.php',
    '/metrics/DockerSnapshotReader.php',
    '/metrics/DockerEventReader.php',
    '/metrics/DockerHistoryService.php',
    '/metrics/DockerStatusService.php',
    '/telegram/DockerTelegramFormatter.php',
] as $f) require_once __DIR__ . $f;
function docker_bootstrap(): void {}
