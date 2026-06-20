<?php
declare(strict_types=1);
final class DockerSnapshotNormalizer implements MetricSnapshotNormalizer {
    public function normalize(array $raw): MetricSnapshot {
        try { $generatedAt = new DateTimeImmutable((string)($raw['generated_at'] ?? 'now')); }
        catch (Exception $e) { $generatedAt = new DateTimeImmutable('now', new DateTimeZone('UTC')); }
        $sr = is_array($raw['status'] ?? null) ? $raw['status'] : [];
        $status = new MetricStatus((string)($sr['overall'] ?? 'unknown'), (string)($sr['severity'] ?? MetricSeverity::UNKNOWN), (string)($sr['summary'] ?? 'Sin estado Docker disponible'), $generatedAt, DOCKER_MODULE_NAME);
        return new MetricSnapshot(DOCKER_MODULE_NAME, (string)($raw['schema_version'] ?? DOCKER_SCHEMA_VERSION), $generatedAt, $status,
            ['engine'=>$raw['engine'] ?? [], 'containers'=>$raw['containers'] ?? [], 'top_restarters'=>$raw['top_restarters'] ?? []],
            ['server'=>$raw['server'] ?? [], 'monitoring'=>$raw['monitoring'] ?? [], 'incidents'=>$raw['incidents'] ?? [], 'telegram'=>$raw['telegram'] ?? []],
            is_array($raw['artifacts'] ?? null) ? $raw['artifacts'] : [], $raw);
    }
    public function normalizeForApi(array $raw): array {
        $snap = $this->normalize($raw);
        $st = $snap->status()->toArray();
        return [
            'module' => DOCKER_MODULE_NAME,
            'schema_version' => (int)($raw['schema_version'] ?? DOCKER_SCHEMA_VERSION),
            'generated_at' => (string)($raw['generated_at'] ?? $snap->generatedAt()->format(DateTimeInterface::ATOM)),
            'server' => is_array($raw['server'] ?? null) ? $raw['server'] : [],
            'status' => ['overall'=>(string)($raw['status']['overall'] ?? $st['status'] ?? 'unknown'), 'severity'=>(string)($raw['status']['severity'] ?? $st['severity'] ?? 'unknown'), 'summary'=>(string)($raw['status']['summary'] ?? $st['summary'] ?? '')],
            'engine' => is_array($raw['engine'] ?? null) ? $raw['engine'] : [],
            'containers' => is_array($raw['containers'] ?? null) ? $raw['containers'] : [],
            'monitoring' => is_array($raw['monitoring'] ?? null) ? $raw['monitoring'] : [],
            'incidents' => is_array($raw['incidents'] ?? null) ? $raw['incidents'] : [],
            'top_restarters' => is_array($raw['top_restarters'] ?? null) ? $raw['top_restarters'] : [],
            'telegram' => is_array($raw['telegram'] ?? null) ? $raw['telegram'] : [],
            'artifacts' => $snap->artifacts(),
            'base_snapshot' => $snap->toArray(),
        ];
    }
}
