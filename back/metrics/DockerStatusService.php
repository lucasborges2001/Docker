<?php
declare(strict_types=1);
final class DockerStatusService {
    private $reader; private $events; private $history;
    public function __construct(?DockerSnapshotReader $reader = null, ?DockerEventReader $events = null, ?DockerHistoryService $history = null) { $this->reader = $reader ?: new DockerSnapshotReader(); $this->events = $events ?: new DockerEventReader(); $this->history = $history ?: new DockerHistoryService(); }
    public function latest(): ?array { return $this->reader->latestForApi(); }
    public function events(int $limit = 50): array { return $this->events->latest($limit); }
    public function health(): array {
        $latest = $this->latest();
        if ($latest === null) return ['ok'=>false,'module'=>DOCKER_MODULE_NAME,'severity'=>'unknown','summary'=>$this->reader->lastError() ?: 'No hay snapshot Docker disponible','latest_path'=>$this->reader->path(),'events_path'=>$this->events->path()];
        $severity = (string)($latest['status']['severity'] ?? 'unknown');
        return ['ok'=>in_array($severity, ['ok','info'], true),'module'=>DOCKER_MODULE_NAME,'severity'=>$severity,'summary'=>(string)($latest['status']['summary'] ?? ''),'generated_at'=>(string)($latest['generated_at'] ?? ''),'latest_path'=>$this->reader->path(),'events_path'=>$this->events->path()];
    }
    public function summary(): array { $latest = $this->latest(); return $latest === null ? ['available'=>false,'health'=>$this->health(),'events'=>$this->events(20),'history'=>[]] : ['available'=>true,'health'=>$this->health(),'latest'=>$latest,'events'=>$this->events(20),'history'=>$this->history->recent(5)]; }
}
