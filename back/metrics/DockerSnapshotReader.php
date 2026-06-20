<?php
declare(strict_types=1);
final class DockerSnapshotReader implements MetricSnapshotReader {
    private $path; private $normalizer; private $lastError = null;
    public function __construct(?string $path = null, ?DockerSnapshotNormalizer $normalizer = null) { $this->path = $path ?: docker_effective_latest_report_path(); $this->normalizer = $normalizer ?: new DockerSnapshotNormalizer(); }
    public function latest(): ?MetricSnapshot { $raw = $this->readRaw(); return $raw === null ? null : $this->normalizer->normalize($raw); }
    public function latestForApi(): ?array { $raw = $this->readRaw(); return $raw === null ? null : $this->normalizer->normalizeForApi($raw); }
    public function readRaw(): ?array {
        $this->lastError = null;
        if (class_exists('JsonMetricSnapshotRepository')) {
            $r = new JsonMetricSnapshotRepository($this->path); $d = $r->read();
            if ($d === null) $this->lastError = is_file($this->path) ? 'Snapshot Docker inválido o vacío' : 'No existe snapshot Docker';
            return is_array($d) ? $d : null;
        }
        if (!is_file($this->path)) { $this->lastError = 'No existe snapshot Docker'; return null; }
        $d = json_decode((string)file_get_contents($this->path), true);
        if (!is_array($d)) { $this->lastError = 'Snapshot Docker inválido'; return null; }
        return $d;
    }
    public function path(): string { return $this->path; }
    public function lastError(): ?string { return $this->lastError; }
}
