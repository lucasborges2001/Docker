<?php
declare(strict_types=1);

/** Produce bounded, chronological per-container trends from sanitized snapshots. */
final class DockerTrendBuilder
{
    public static function forContainer(array $historyNewestFirst, string $ref, int $limit = 20): array
    {
        $samples = [];
        $previous = null;
        $previousEngineVersion = null;
        foreach (array_reverse($historyNewestFirst) as $snapshot) {
            if (!is_array($snapshot) || !($snapshot['engine']['available'] ?? false)) {
                $previous = null;
                $previousEngineVersion = null;
                continue;
            }
            $version = $snapshot['engine']['version'] ?? null;
            $found = null;
            $items = $snapshot['containers']['items'] ?? [];
            foreach (is_array($items) ? $items : [] as $item) {
                if (is_array($item) && ($item['container_ref'] ?? null) === $ref) {
                    $found = $item;
                    break;
                }
            }
            if ($found === null) {
                $previous = null;
                $previousEngineVersion = null;
                continue;
            }
            $rate = null;
            if ($previous !== null && $previousEngineVersion === $version) {
                $rate = DockerCounterRate::between($previous, $found);
            }
            $samples[] = [
                'sampled_at' => $found['sampled_at'] ?? null,
                'instance_ref' => $found['instance_ref'] ?? null,
                'cpu_percent' => $found['cpu_percent'] ?? null,
                'memory_used_bytes' => $found['memory_used_bytes'] ?? null,
                'network_rx_bytes_total' => $found['network_rx_bytes_total'] ?? null,
                'network_tx_bytes_total' => $found['network_tx_bytes_total'] ?? null,
                'rate' => $rate,
            ];
            $previous = $found;
            $previousEngineVersion = $version;
        }
        $out = array_slice($samples, -max(1, min(50, $limit)));
        if ($out) {
            // Consumers must not receive a rate whose prior sample is hidden.
            $out[0]['rate'] = null;
        }
        return $out;
    }
}
