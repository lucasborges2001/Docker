<?php
declare(strict_types=1);
final class DockerMetricSummary {
    public static function fromSnapshot(array $s): array {
        $c=is_array($s['containers']??null)?$s['containers']:[]; $e=is_array($s['engine']??null)?$s['engine']:[]; $i=is_array($s['incidents']??null)?$s['incidents']:[]; $a=is_array($s['aggregates']??null)?$s['aggregates']:[];
        return ['engine_available'=>(bool)($e['available']??false),'total'=>(int)($c['total']??0),'running'=>(int)($c['running']??0),'stopped'=>(int)($c['stopped']??0),'unhealthy'=>(int)($c['unhealthy']??0),'monitored'=>(int)($c['monitored']??0),'without_memory_limit'=>(int)($c['without_memory_limit']??0),'without_healthcheck'=>(int)($c['without_healthcheck']??0),'open_incidents'=>(int)($i['open']??0),'cpu_percent'=>(float)($a['cpu_percent']??0.0),'memory_used_bytes'=>(int)($a['memory_used_bytes']??0),'network_rx_bytes_total'=>(int)($a['network_rx_bytes_total']??0),'network_tx_bytes_total'=>(int)($a['network_tx_bytes_total']??0)];
    }
}
