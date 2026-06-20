<?php
declare(strict_types=1);
final class DockerTelegramFormatter {
    public function heartbeatHtml(array $s): string {
        $st = is_array($s['status'] ?? null) ? $s['status'] : []; $c = is_array($s['containers'] ?? null) ? $s['containers'] : []; $e = is_array($s['engine'] ?? null) ? $s['engine'] : []; $i = is_array($s['incidents'] ?? null) ? $s['incidents'] : [];
        return implode("\n", ['<b>Docker heartbeat</b>', 'Estado: '.$this->esc((string)($st['summary'] ?? 'Sin resumen')), 'Engine: '.(!empty($e['available']) ? 'disponible' : 'no disponible'), 'Contenedores: '.(int)($c['running'] ?? 0).' running / '.(int)($c['stopped'] ?? 0).' stopped / '.(int)($c['unhealthy'] ?? 0).' unhealthy', 'Monitoreados: '.(int)($c['monitored'] ?? 0), 'Incidentes abiertos: '.(int)($i['open'] ?? 0)]);
    }
    public function incidentHtml(array $e): string { return implode("\n", ['<b>Docker incidente</b>', 'Tipo: '.$this->esc((string)($e['type'] ?? 'unknown')), 'Severidad: '.$this->esc((string)($e['severity'] ?? 'unknown')), 'Contenedor: '.$this->esc((string)($e['container_name'] ?? 'unknown')), 'Imagen: '.$this->esc((string)($e['image'] ?? 'unknown')), 'Mensaje: '.$this->esc((string)($e['message'] ?? ''))]); }
    private function esc(string $v): string { return class_exists('TelegramHtml') ? TelegramHtml::escape($v) : htmlspecialchars($v, ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8'); }
}
