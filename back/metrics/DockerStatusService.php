<?php
declare(strict_types=1);
final class DockerStatusService {
    private $reader; private $events; private $history;
    public function __construct(?DockerSnapshotReader $reader=null,?DockerEventReader $events=null,?DockerHistoryService $history=null){$this->reader=$reader?:new DockerSnapshotReader();$this->events=$events?:new DockerEventReader();$this->history=$history?:new DockerHistoryService();}
    public function latest():?array{return $this->reader->latestForApi();}
    public function events(int $limit=50):array{return $this->events->latest($limit);}
    public function health():array{$latest=$this->latest();if($latest===null)return ['ok'=>false,'module'=>DOCKER_MODULE_NAME,'severity'=>'unknown','summary'=>$this->reader->lastError()?:'No hay snapshot Docker disponible','latest_path'=>$this->reader->path(),'events_path'=>$this->events->path()];$severity=(string)($latest['status']['severity']??'unknown');return ['ok'=>in_array($severity,['ok','info'],true),'module'=>DOCKER_MODULE_NAME,'severity'=>$severity,'summary'=>(string)($latest['status']['summary']??''),'generated_at'=>(string)($latest['generated_at']??''),'latest_path'=>$this->reader->path(),'events_path'=>$this->events->path()];}
    public function resources():array{$latest=$this->latest();if($latest===null)return ['available'=>false,'health'=>$this->health(),'aggregates'=>[],'containers'=>[]];return ['available'=>true,'generated_at'=>$latest['generated_at']??null,'status'=>$latest['status']??[],'aggregates'=>$latest['aggregates']??[],'containers'=>$latest['containers']??[],'monitoring'=>$latest['monitoring']??[]];}
    public function container(string $containerRef):?array{$resources=$this->resources();foreach(is_array($resources['containers']['items']??null)?$resources['containers']['items']:[] as $item){if(is_array($item)&&hash_equals((string)($item['container_ref']??''),$containerRef))return ['generated_at'=>$resources['generated_at']??null,'container'=>$item];}return null;}
    public function summary():array{$latest=$this->latest();return $latest===null?['available'=>false,'health'=>$this->health(),'events'=>$this->events(20),'history'=>[]]:['available'=>true,'health'=>$this->health(),'latest'=>$latest,'resources'=>$this->resources(),'events'=>$this->events(20),'history'=>$this->history->recent(5)];}
}
