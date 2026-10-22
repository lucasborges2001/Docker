<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/metrics/DockerCounterRate.php';
require_once __DIR__ . '/../../back/metrics/DockerTrendBuilder.php';
function snapshot(string $time, string $instance, int $rx, bool $withContainer = true): array {
    $item = [
        'container_ref' => 'name:api', 'instance_ref' => $instance, 'sampled_at' => $time,
        'cpu_percent' => 4.0, 'memory_used_bytes' => 1024,
        'network_rx_bytes_total' => $rx, 'network_tx_bytes_total' => $rx,
        'block_read_bytes_total' => $rx, 'block_write_bytes_total' => $rx,
    ];
    return ['engine' => ['available' => true, 'version' => '27'],
            'containers' => ['items' => $withContainer ? [$item] : []]];
}
$t0 = snapshot('2026-10-22T10:00:00Z', 'instance:a', 100);
$t1 = snapshot('2026-10-22T10:01:00Z', 'instance:a', 1300);
$t2 = snapshot('2026-10-22T10:02:00Z', 'instance:b', 50);
$rows = DockerTrendBuilder::forContainer([$t2, $t1, $t0], 'name:api', 3);
if (count($rows) !== 3 || $rows[0]['rate'] !== null
    || ($rows[1]['rate']['network_rx_bytes_per_second'] ?? null) !== 20.0
    || ($rows[2]['rate']['reason'] ?? '') !== 'identity_changed') {
    throw new RuntimeException('invalid trend or recreate: ' . json_encode($rows));
}
$absent = snapshot('2026-10-22T10:01:00Z', 'instance:a', 0, false);
$rows = DockerTrendBuilder::forContainer([$t2, $absent, $t0], 'name:api', 3);
if (count($rows) !== 2 || $rows[1]['rate'] !== null) {
    throw new RuntimeException('missing container must break continuity');
}
$rows = DockerTrendBuilder::forContainer([$t2, $t1, $t0], 'name:api', 2);
if (count($rows) !== 2 || $rows[0]['rate'] !== null) {
    throw new RuntimeException('hidden previous sample produced a rate');
}
echo "DockerTrendBuilderTest OK\n";
