<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/support/contracts.php';
require_once __DIR__ . '/../../back/support/paths.php';

// A missing live report must never appear as a healthy sample in production.
$dir = sys_get_temp_dir() . '/docker-paths-missing-' . bin2hex(random_bytes(8));
$old = [];
foreach (['DOCKER_WATCH_REPORTS_DIR', 'DOCKER_WATCH_EVENTS_LOG', 'DOCKER_WATCH_ALLOW_SAMPLE_REPORTS'] as $key) {
    $old[$key] = getenv($key);
}
try {
    putenv('DOCKER_WATCH_REPORTS_DIR=' . $dir);
    putenv('DOCKER_WATCH_EVENTS_LOG=' . $dir . '/events.jsonl');
    putenv('DOCKER_WATCH_ALLOW_SAMPLE_REPORTS=false');
    if (docker_effective_latest_report_path() !== $dir . '/latest/report.json') {
        throw new RuntimeException('Missing live snapshot silently fell back to sample');
    }
    if (docker_events_log_path() !== $dir . '/events.jsonl') {
        throw new RuntimeException('Missing live events silently fell back to sample');
    }
    putenv('DOCKER_WATCH_ALLOW_SAMPLE_REPORTS=true');
    if (docker_effective_latest_report_path() !== docker_sample_reports_dir() . '/latest/report.json') {
        throw new RuntimeException('Explicit fixture opt-in is broken');
    }
    if (docker_events_log_path() !== docker_sample_reports_dir() . '/events.jsonl') {
        throw new RuntimeException('Explicit event fixture opt-in is broken');
    }
} finally {
    foreach ($old as $key => $value) {
        $value === false ? putenv($key) : putenv($key . '=' . $value);
    }
}
echo "DockerPathsTest OK\n";
