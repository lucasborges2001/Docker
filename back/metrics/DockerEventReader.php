<?php
declare(strict_types=1);
final class DockerEventReader {
    private $path; private $lastError = null;
    public function __construct(?string $path = null) { $this->path = $path ?: docker_events_log_path(); }
    public function latest(int $limit = 50): array {
        $this->lastError = null; $limit = max(1, min(500, $limit));
        if (!is_file($this->path)) { $this->lastError = 'No existe events.jsonl'; return []; }
        $lines = file($this->path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!is_array($lines)) { $this->lastError = 'No se pudo leer events.jsonl'; return []; }
        $out = [];
        foreach (array_reverse($lines) as $line) {
            $d = json_decode($line, true);
            if (is_array($d)) $out[] = $d;
            if (count($out) >= $limit) break;
        }
        return $out;
    }
    public function filterBySeverity(string $severity): array { return array_values(array_filter($this->latest(500), static fn(array $e): bool => (string)($e['severity'] ?? '') === $severity)); }
    public function path(): string { return $this->path; }
    public function lastError(): ?string { return $this->lastError; }
}
