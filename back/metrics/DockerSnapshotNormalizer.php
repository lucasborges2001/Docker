<?php
declare(strict_types=1);

final class DockerSnapshotNormalizer implements MetricSnapshotNormalizer
{
    public function normalize(array $raw): MetricSnapshot
    {
        try { $generatedAt = new DateTimeImmutable((string) ($raw['generated_at'] ?? 'now')); }
        catch (Exception $exception) { $generatedAt = new DateTimeImmutable('now', new DateTimeZone('UTC')); }
        $statusRaw = is_array($raw['status'] ?? null) ? $raw['status'] : [];
        $status = new MetricStatus((string) ($statusRaw['overall'] ?? 'unknown'), (string) ($statusRaw['severity'] ?? MetricSeverity::UNKNOWN), (string) ($statusRaw['summary'] ?? 'Sin estado Docker disponible'), $generatedAt, DOCKER_MODULE_NAME);
        return new MetricSnapshot(
            DOCKER_MODULE_NAME,
            (string) ($raw['schema_version'] ?? DOCKER_SCHEMA_VERSION),
            $generatedAt,
            $status,
            ['engine'=>$this->sanitizeEngine($raw['engine'] ?? []),'containers'=>$this->sanitizeContainers($raw['containers'] ?? []),'aggregates'=>$this->sanitizeAggregates($raw['aggregates'] ?? []),'top_restarters'=>$this->sanitizeTop($raw['top_restarters'] ?? [], 'restart_count')],
            ['server'=>is_array($raw['server'] ?? null)?$raw['server']:[],'monitoring'=>$this->sanitizeMonitoring($raw['monitoring'] ?? []),'incidents'=>is_array($raw['incidents'] ?? null)?$raw['incidents']:[],'telegram'=>is_array($raw['telegram'] ?? null)?$raw['telegram']:[]],
            is_array($raw['artifacts'] ?? null) ? $raw['artifacts'] : [],
            []
        );
    }

    public function normalizeForApi(array $raw): array
    {
        $snapshot=$this->normalize($raw); $normalizedStatus=$snapshot->status()->toArray(); $aggregates=$this->sanitizeAggregates($raw['aggregates'] ?? []);
        return [
            'module'=>DOCKER_MODULE_NAME,
            'schema_version'=>(int)($raw['schema_version'] ?? DOCKER_SCHEMA_VERSION),
            'schema_compatibility'=>$this->sanitizeSchemaCompatibility($raw['schema_compatibility'] ?? []),
            'generated_at'=>(string)($raw['generated_at'] ?? $snapshot->generatedAt()->format(DateTimeInterface::ATOM)),
            'server'=>is_array($raw['server'] ?? null)?$raw['server']:[],
            'status'=>['overall'=>(string)($raw['status']['overall'] ?? $normalizedStatus['status'] ?? 'unknown'),'severity'=>(string)($raw['status']['severity'] ?? $normalizedStatus['severity'] ?? 'unknown'),'summary'=>(string)($raw['status']['summary'] ?? $normalizedStatus['summary'] ?? '')],
            'engine'=>$this->sanitizeEngine($raw['engine'] ?? []),
            'containers'=>$this->sanitizeContainers($raw['containers'] ?? []),
            'aggregates'=>$aggregates,
            'monitoring'=>$this->sanitizeMonitoring($raw['monitoring'] ?? []),
            'incidents'=>is_array($raw['incidents'] ?? null)?$raw['incidents']:[],
            'top_restarters'=>$this->sanitizeTop($raw['top_restarters'] ?? ($aggregates['top_restarters'] ?? []), 'restart_count'),
            'telegram'=>is_array($raw['telegram'] ?? null)?$raw['telegram']:[],
            'artifacts'=>$snapshot->artifacts(),
            'base_snapshot'=>$snapshot->toArray(),
        ];
    }

    private function sanitizeSchemaCompatibility($value): array
    {
        $raw=is_array($value)?$value:[];
        return ['minimum'=>max(1,(int)($raw['minimum'] ?? DOCKER_MINIMUM_COMPATIBLE_SCHEMA_VERSION)),'current'=>max(1,(int)($raw['current'] ?? DOCKER_SCHEMA_VERSION)),'mode'=>(string)($raw['mode'] ?? 'expand-only')];
    }

    private function sanitizeEngine($value): array
    {
        $raw=is_array($value)?$value:[];
        return ['available'=>(bool)($raw['available'] ?? false),'version'=>isset($raw['version'])&&$raw['version']!==''?(string)$raw['version']:null,'socket_resolved'=>(bool)($raw['socket_resolved'] ?? isset($raw['socket']))];
    }

    private function sanitizeContainers($value): array
    {
        $raw=is_array($value)?$value:[]; $items=[];
        foreach(is_array($raw['items'] ?? null)?$raw['items']:[] as $item){ if(is_array($item))$items[]=$this->sanitizeContainer($item); }
        return ['total'=>max(0,(int)($raw['total'] ?? 0)),'running'=>max(0,(int)($raw['running'] ?? 0)),'stopped'=>max(0,(int)($raw['stopped'] ?? 0)),'unhealthy'=>max(0,(int)($raw['unhealthy'] ?? 0)),'monitored'=>max(0,(int)($raw['monitored'] ?? count($items))),'without_memory_limit'=>max(0,(int)($raw['without_memory_limit'] ?? 0)),'without_healthcheck'=>max(0,(int)($raw['without_healthcheck'] ?? 0)),'items'=>$items];
    }

    private function sanitizeContainer(array $raw): array
    {
        $compose=is_array($raw['compose'] ?? null)?$raw['compose']:[];
        return [
            'container_ref'=>(string)($raw['container_ref'] ?? ''),'instance_ref'=>(string)($raw['instance_ref'] ?? ''),'name'=>(string)($raw['name'] ?? ''),
            'compose'=>['project'=>$this->nullableString($compose['project'] ?? null),'service'=>$this->nullableString($compose['service'] ?? null),'container_number'=>$this->nullableString($compose['container_number'] ?? null)],
            'state'=>(string)($raw['state'] ?? 'unknown'),'health'=>$this->nullableString($raw['health'] ?? null),'has_healthcheck'=>(bool)($raw['has_healthcheck'] ?? false),'status'=>(string)($raw['status'] ?? ''),
            'cpu_percent'=>$this->nullableFloat($raw['cpu_percent'] ?? null),'memory_used_bytes'=>$this->nullableInteger($raw['memory_used_bytes'] ?? null),'memory_limit_bytes'=>$this->nullableInteger($raw['memory_limit_bytes'] ?? null),'memory_percent'=>$this->nullableFloat($raw['memory_percent'] ?? null),
            'network_rx_bytes_total'=>$this->nullableInteger($raw['network_rx_bytes_total'] ?? null),'network_tx_bytes_total'=>$this->nullableInteger($raw['network_tx_bytes_total'] ?? null),'block_read_bytes_total'=>$this->nullableInteger($raw['block_read_bytes_total'] ?? null),'block_write_bytes_total'=>$this->nullableInteger($raw['block_write_bytes_total'] ?? null),
            'pids'=>$this->nullableInteger($raw['pids'] ?? null),'restart_count'=>max(0,(int)($raw['restart_count'] ?? 0)),'started_at'=>$this->nullableString($raw['started_at'] ?? null),'uptime_seconds'=>$this->nullableInteger($raw['uptime_seconds'] ?? null),'sampled_at'=>$this->nullableString($raw['sampled_at'] ?? null),
        ];
    }

    private function sanitizeAggregates($value): array
    {
        $raw=is_array($value)?$value:[];
        return [
            'cpu_percent'=>(float)($raw['cpu_percent'] ?? 0.0),'memory_used_bytes'=>max(0,(int)($raw['memory_used_bytes'] ?? 0)),'network_rx_bytes_total'=>max(0,(int)($raw['network_rx_bytes_total'] ?? 0)),'network_tx_bytes_total'=>max(0,(int)($raw['network_tx_bytes_total'] ?? 0)),'block_read_bytes_total'=>max(0,(int)($raw['block_read_bytes_total'] ?? 0)),'block_write_bytes_total'=>max(0,(int)($raw['block_write_bytes_total'] ?? 0)),'pids'=>max(0,(int)($raw['pids'] ?? 0)),'without_memory_limit'=>max(0,(int)($raw['without_memory_limit'] ?? 0)),'without_healthcheck'=>max(0,(int)($raw['without_healthcheck'] ?? 0)),
            'top_cpu'=>$this->sanitizeTop($raw['top_cpu'] ?? [],'cpu_percent'),'top_memory'=>$this->sanitizeTop($raw['top_memory'] ?? [],'memory_used_bytes'),'top_network_rx'=>$this->sanitizeTop($raw['top_network_rx'] ?? [],'network_rx_bytes_total'),'top_network_tx'=>$this->sanitizeTop($raw['top_network_tx'] ?? [],'network_tx_bytes_total'),'top_restarters'=>$this->sanitizeTop($raw['top_restarters'] ?? [],'restart_count'),
        ];
    }

    private function sanitizeTop($value,string $field): array
    {
        $items=[];
        foreach(is_array($value)?$value:[] as $raw){
            if(!is_array($raw))continue;
            $items[]=['container_ref'=>(string)($raw['container_ref'] ?? ''),'name'=>(string)($raw['name'] ?? 'container'),$field=>$field==='cpu_percent'?(float)($raw[$field] ?? 0.0):max(0,(int)($raw[$field] ?? 0))];
        }
        return array_slice($items,0,20);
    }

    private function sanitizeMonitoring($value): array
    {
        $raw=is_array($value)?$value:[]; $errors=[];
        foreach(is_array($raw['errors'] ?? null)?$raw['errors']:[] as $error){ if(!is_array($error))continue; $safe=['code'=>(string)($error['code'] ?? 'unknown')]; if(isset($error['limit']))$safe['limit']=max(0,(int)$error['limit']); $errors[]=$safe; }
        return ['label'=>(string)($raw['label'] ?? DOCKER_DEFAULT_MONITOR_LABEL),'watcher_running'=>(bool)($raw['watcher_running'] ?? false),'heartbeat_enabled'=>(bool)($raw['heartbeat_enabled'] ?? false),'telemetry_enabled'=>(bool)($raw['telemetry_enabled'] ?? false),'include_unlabeled'=>(bool)($raw['include_unlabeled'] ?? false),'interval_seconds'=>max(5,(int)($raw['interval_seconds'] ?? 60)),'sampled_at'=>$this->nullableString($raw['sampled_at'] ?? null),'errors'=>$errors];
    }

    private function nullableString($value): ?string { return $value===null||$value===''?null:(string)$value; }
    private function nullableInteger($value): ?int { return $value===null||$value===''?null:max(0,(int)$value); }
    private function nullableFloat($value): ?float { return $value===null||$value===''?null:(float)$value; }
}
