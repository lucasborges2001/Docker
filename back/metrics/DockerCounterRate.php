<?php
declare(strict_types=1);

/**
 * Domain-only comparison of two Docker samples. Never infer negative rates
 * or bridge distinct container instances. No Docker access or filesystem I/O.
 */
final class DockerCounterRate
{
    private const COUNTERS = [
        'network_rx_bytes_total' => 'network_rx_bytes_per_second',
        'network_tx_bytes_total' => 'network_tx_bytes_per_second',
        'block_read_bytes_total' => 'block_read_bytes_per_second',
        'block_write_bytes_total' => 'block_write_bytes_per_second',
    ];

    public static function between(array $previous, array $current): array
    {
        $result = ['compatible' => false, 'reason' => 'missing_identity', 'interval_seconds' => null];
        foreach (self::COUNTERS as $rateField) {
            $result[$rateField] = null;
        }
        $result['memory_delta_bytes'] = null;

        $prevRef = $previous['container_ref'] ?? null;
        $currRef = $current['container_ref'] ?? null;
        $prevInstance = $previous['instance_ref'] ?? null;
        $currInstance = $current['instance_ref'] ?? null;
        if (!is_string($prevRef) || $prevRef === '' || !is_string($currRef) || $currRef === ''
            || !is_string($prevInstance) || $prevInstance === '' || !is_string($currInstance) || $currInstance === '') {
            return $result;
        }
        if ($prevRef !== $currRef || $prevInstance !== $currInstance) {
            $result['reason'] = 'identity_changed';
            return $result;
        }
        $t1 = self::timestamp($previous['sampled_at'] ?? null);
        $t2 = self::timestamp($current['sampled_at'] ?? null);
        if ($t1 === null || $t2 === null || $t2 <= $t1) {
            $result['reason'] = 'invalid_interval';
            return $result;
        }
        $interval = $t2 - $t1;
        $result['interval_seconds'] = $interval;
        foreach (self::COUNTERS as $input => $output) {
            $p = $previous[$input] ?? null;
            $c = $current[$input] ?? null;
            if (!is_int($p) || !is_int($c) || $p < 0 || $c < 0) {
                $result['reason'] = 'counter_missing';
                return $result;
            }
            if ($c < $p) {
                $result['reason'] = 'counter_reset';
                return $result;
            }
        }
        foreach (self::COUNTERS as $input => $output) {
            $result[$output] = round(($current[$input] - $previous[$input]) / $interval, 4);
        }
        $oldMemory = $previous['memory_used_bytes'] ?? null;
        $newMemory = $current['memory_used_bytes'] ?? null;
        if (is_int($oldMemory) && is_int($newMemory)) {
            $result['memory_delta_bytes'] = $newMemory - $oldMemory;
        }
        $result['compatible'] = true;
        $result['reason'] = null;
        return $result;
    }

    private static function timestamp($raw): ?int
    {
        if (!is_string($raw) || !preg_match('/\A\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?Z\z/', $raw)) {
            return null;
        }
        $value = strtotime($raw);
        return $value === false ? null : $value;
    }
}
