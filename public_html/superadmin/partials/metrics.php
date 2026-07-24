<?php
$c=is_array($dockerLatest['containers']??null)?$dockerLatest['containers']:[];
$a=is_array($dockerLatest['aggregates']??null)?$dockerLatest['aggregates']:[];
$m=is_array($dockerLatest['monitoring']??null)?$dockerLatest['monitoring']:[];
?>
<article class="card">
  <h2>Recursos Docker</h2>
  <div class="metric-grid">
    <div><strong><?= docker_h(docker_format_percent($a['cpu_percent']??0)) ?></strong><span>CPU agregada</span></div>
    <div><strong><?= docker_h(docker_format_bytes($a['memory_used_bytes']??0)) ?></strong><span>Memoria usada</span></div>
    <div><strong><?= docker_h(docker_format_bytes($a['network_rx_bytes_total']??0)) ?></strong><span>Network RX</span></div>
    <div><strong><?= docker_h(docker_format_bytes($a['network_tx_bytes_total']??0)) ?></strong><span>Network TX</span></div>
    <div><strong><?= (int)($a['pids']??0) ?></strong><span>PIDs</span></div>
  </div>
  <div class="metric-grid compact">
    <div><strong><?= (int)($c['total']??0) ?></strong><span>Total</span></div>
    <div><strong><?= (int)($c['running']??0) ?></strong><span>Running</span></div>
    <div><strong><?= (int)($c['stopped']??0) ?></strong><span>Stopped</span></div>
    <div><strong><?= (int)($c['unhealthy']??0) ?></strong><span>Unhealthy</span></div>
    <div><strong><?= (int)($c['monitored']??0) ?></strong><span>Monitoreados</span></div>
  </div>
  <p class="muted">Label: <code><?= docker_h($m['label']??'dockwatch.monitor=true') ?></code> · intervalo <?= (int)($m['interval_seconds']??60) ?> s · sin límite de memoria: <?= (int)($c['without_memory_limit']??0) ?> · sin healthcheck: <?= (int)($c['without_healthcheck']??0) ?></p>
</article>
