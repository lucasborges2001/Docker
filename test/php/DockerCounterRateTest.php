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
// Missing counters are unknown, not zero. They must not discard valid rates.
$missing = $current;
$missing['network_rx_bytes_total'] = null;
$rate = DockerCounterRate::between($previous, $missing);
if (!$rate['compatible'] || $rate['reason'] !== null
    || $rate['network_rx_bytes_per_second'] !== null
    || $rate['network_tx_bytes_per_second'] !== 100.0
    || $rate['block_write_bytes_per_second'] !== 50.0) {
    throw new RuntimeException('missing RX must preserve valid counters without inventing zero: ' . json_encode($rate));
}
$missingBlock = $current;
$missingBlock['block_read_bytes_total'] = null;
$rate = DockerCounterRate::between($previous, $missingBlock);
if (!$rate['compatible'] || $rate['network_rx_bytes_per_second'] !== 1000.0
    || $rate['network_tx_bytes_per_second'] !== 100.0
    || $rate['block_read_bytes_per_second'] !== null) {
    throw new RuntimeException('missing Block I/O must not invalidate network: ' . json_encode($rate));
}
$missingAll = $current;
foreach (['network_rx_bytes_total', 'network_tx_bytes_total', 'block_read_bytes_total', 'block_write_bytes_total'] as $counter) {
    unset($missingAll[$counter]);
}
$rate = DockerCounterRate::between($previous, $missingAll);
if ($rate['compatible'] || $rate['reason'] !== 'counter_missing'
    || $rate['network_rx_bytes_per_second'] !== null
    || $rate['block_write_bytes_per_second'] !== null) {
    throw new RuntimeException('no valid counters must remain incompatible: ' . json_encode($rate));
}
// Reset still invalidates the complete comparison, even if another counter is absent.
$resetWithMissing = $current;
$resetWithMissing['network_rx_bytes_total'] = null;
$resetWithMissing['block_write_bytes_total'] = 1;
$rate = DockerCounterRate::between($previous, $resetWithMissing);
if ($rate['compatible'] || $rate['reason'] !== 'counter_reset'
    || $rate['network_tx_bytes_per_second'] !== null) {
    throw new RuntimeException('reset must dominate missing counters: ' . json_encode($rate));
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
