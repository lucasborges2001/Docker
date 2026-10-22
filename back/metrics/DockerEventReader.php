<?php
declare(strict_types=1);

final class DockerEventReader
{
    private $path;
    private $lastError = null;

    public function __construct(?string $path = null)
    {
        $this->path = $path ?: docker_events_log_path();
    }

    public function latest(int $limit = 50): array
    {
        $this->lastError = null;
        $limit = max(1, min(500, $limit));
        if (!is_file($this->path)) {
            $this->lastError = 'No existe events.jsonl';
            return [];
        }
        $lines = file($this->path, FILE_IGNORE_NEW_LINES | FILE_SKIP_EMPTY_LINES);
        if (!is_array($lines)) {
            $this->lastError = 'No se pudo leer events.jsonl';
            return [];
        }
        $out = [];
        foreach (array_reverse($lines) as $line) {
            $decoded = json_decode($line, true);
            if (is_array($decoded)) {
                $out[] = $this->forApi($decoded);
            }
            if (count($out) >= $limit) {
                break;
            }
        }
        return $out;
    }

    /**
     * Allowlist the public event contract. Raw Docker events and labels stay on disk.
     * Do not reuse the persisted payload directly in an HTTP response.
     */
    private function forApi(array $raw): array
    {
        $type = substr((string) ($raw['type'] ?? 'unknown'), 0, 64);
        $type = preg_replace('/[^a-zA-Z0-9_ :.-]/', '', $type) ?: 'unknown';
        $severity = (string) ($raw['severity'] ?? 'unknown');
        if (!in_array($severity, ['info', 'ok', 'warning', 'error'], true)) {
            $severity = 'unknown';
        }
        $name = substr((string) ($raw['container_name'] ?? ''), 0, 128);
        $name = preg_replace('/[^a-zA-Z0-9_.-]/', '-', $name) ?: '';
        $time = substr((string) ($raw['time'] ?? ''), 0, 40);
        $time = preg_match('/\A[0-9TZ:+.\-]{10,40}\z/', $time) ? $time : '';
        return [
            'time' => $time,
            'type' => $type,
            'severity' => $severity,
            'container_name' => $name,
            'message' => $type === 'unknown' ? 'Evento Docker' : 'Evento Docker: ' . $type,
        ];
    }

    public function filterBySeverity(string $severity): array
    {
        return array_values(array_filter(
            $this->latest(500),
            static fn(array $event): bool => $event['severity'] === $severity
        ));
    }

    public function path(): string { return $this->path; }
    public function lastError(): ?string { return $this->lastError; }
}
