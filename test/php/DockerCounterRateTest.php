<?php
declare(strict_types=1);
require_once __DIR__ . '/../../back/metrics/DockerCounterRate.php';

$previous = [
    'container_ref' => 'compose:demo/api/1',
    'instance_ref' => 'instance:abc',
    'sampled_at' => '2026-10-22T15:00:00Z',
    'network_rx_bytes_total' => 1200000,
    'network_tx_bytes_total' => 2000,
    'block_read_bytes_total' => 4000,
    'block_write_bytes_total' => 8000,
    'memory_used_bytes' => 2000,
];
$current = $previous;
$current['sampled_at'] = '2026-10-22T15:01:00Z';
$current['network_rx_bytes_total'] = 1260000;
$current['network_tx_bytes_total'] = 8000;
$current['block_read_bytes_total'] = 4000;
$current['block_write_bytes_total'] = 11000;
$current['memory_used_bytes'] = 1500;
$rate = DockerCounterRate::between($previous, $current);
if (!$rate['compatible'] || $rate['interval_seconds'] !== 60
    || $rate['network_rx_bytes_per_second'] !== 1000.0
    || $rate['network_tx_bytes_per_second'] !== 100.0
    || $rate['memory_delta_bytes'] !== -500) {
    throw new RuntimeException('valid sample rate mismatch: ' . json_encode($rate));
}
$recreated = $current;
$recreated['instance_ref'] = 'instance:new';
$rate = DockerCounterRate::between($previous, $recreated);
if ($rate['compatible'] || $rate['network_rx_bytes_per_second'] !== null
    || $rate['reason'] !== 'identity_changed') {
    throw new RuntimeException('instance recreation must invalidate rates');
}
$reset = $current;
$reset['network_rx_bytes_total'] = 10;
$rate = DockerCounterRate::between($previous, $reset);
if ($rate['compatible'] || $rate['network_tx_bytes_per_second'] !== null
    || $rate['reason'] !== 'counter_reset') {
    throw new RuntimeException('counter reset must invalidate all rates');
}
$missing = $current;
$missing['network_rx_bytes_total'] = null;
$rate = DockerCounterRate::between($previous, $missing);
if ($rate['compatible'] || $rate['reason'] !== 'counter_missing') {
    throw new RuntimeException('null counter was treated as zero');
}
$sameTime = $previous;
$rate = DockerCounterRate::between($previous, $sameTime);
if ($rate['compatible'] || $rate['reason'] !== 'invalid_interval') {
    throw new RuntimeException('zero-second comparison must be invalid');
}
$invalidTime = $current;
$invalidTime['sampled_at'] = 'yesterday';
if (DockerCounterRate::between($previous, $invalidTime)['compatible']) {
    throw new RuntimeException('invalid timestamp accepted');
}
echo "DockerCounterRateTest OK\n";
