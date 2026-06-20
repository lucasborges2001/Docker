<?php
declare(strict_types=1);
final class DockerMetricSummary {
    public static function fromSnapshot(array $s): array {
        $c = is_array($s['containers'] ?? null) ? $s['containers'] : [];
        $e = is_array($s['engine'] ?? null) ? $s['engine'] : [];
        $i = is_array($s['incidents'] ?? null) ? $s['incidents'] : [];
        return [
            'engine_available' => (bool)($e['available'] ?? false),
            'total' => (int)($c['total'] ?? 0),
            'running' => (int)($c['running'] ?? 0),
            'stopped' => (int)($c['stopped'] ?? 0),
            'unhealthy' => (int)($c['unhealthy'] ?? 0),
            'monitored' => (int)($c['monitored'] ?? 0),
            'open_incidents' => (int)($i['open'] ?? 0),
        ];
    }
}
