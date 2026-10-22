<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/bootstrap.php';

$r = new DockerEventReader(__DIR__ . '/../../var/sample-reports/events.jsonl');
$events = $r->latest(10);
if (count($events) < 1 || !isset($events[0]['type'])) {
    throw new RuntimeException('events failed');
}

$path = tempnam(sys_get_temp_dir(), 'docker-events-');
if ($path === false) {
    throw new RuntimeException('cannot create temporary event fixture');
}
try {
    file_put_contents($path, json_encode([
        'time' => '2026-10-22T18:00:00Z',
        'type' => 'die',
        'severity' => 'error',
        'container_name' => 'my-api',
        'message' => 'secret=top-secret',
        'container_id' => '0123456789abcdef',
        'labels' => ['password' => 'top-secret'],
        'raw' => ['Actor' => ['Attributes' => ['token' => 'top-secret']]],
    ], JSON_THROW_ON_ERROR) . "\n");
    $safe = (new DockerEventReader($path))->latest(1)[0] ?? [];
    foreach (['raw', 'labels', 'container_id', 'image', 'incident_key'] as $forbidden) {
        if (array_key_exists($forbidden, $safe)) {
            throw new RuntimeException('event leaked ' . $forbidden);
        }
    }
    if (($safe['type'] ?? null) !== 'die'
        || ($safe['severity'] ?? null) !== 'error'
        || str_contains(json_encode($safe, JSON_THROW_ON_ERROR), 'top-secret')
    ) {
        throw new RuntimeException('event redaction failed');
    }
} finally {
    unlink($path);
}
echo "DockerEventReaderTest OK\n";
