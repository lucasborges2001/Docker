<?php
$c=is_array($dockerLatest['containers']??null)?$dockerLatest['containers']:[];
$items=is_array($c['items']??null)?$c['items']:[];
$i=is_array($dockerLatest['incidents']??null)?$dockerLatest['incidents']:[];
?>
<article class="card full">
  <div class="card-heading"><div><h2>Contenedores monitoreados</h2><p class="muted">Incidentes abiertos: <strong><?= (int)($i['open']??0) ?></strong>. Vista estrictamente read-only.</p></div><span class="badge"><?= count($items) ?> items</span></div>
  <?php if(!$items): ?><p class="muted">Sin detalle de recursos. El snapshot puede ser v1, la telemetría puede estar deshabilitada o el engine puede no estar disponible.</p><?php else: ?>
  <div class="table-wrap"><table><thead><tr><th>Contenedor</th><th>Estado</th><th>CPU</th><th>Memoria</th><th>RX / TX</th><th>Block R / W</th><th>PIDs</th><th>Restarts</th><th>Uptime</th></tr></thead><tbody>
  <?php foreach($items as $item): ?>
    <tr>
      <td><strong><?= docker_h($item['name']??'container') ?></strong><small><?= docker_h($item['container_ref']??'') ?></small><?php $compose=is_array($item['compose']??null)?$item['compose']:[];if(!empty($compose['project'])||!empty($compose['service'])): ?><small><?= docker_h(($compose['project']??'').' / '.($compose['service']??'')) ?></small><?php endif; ?></td>
      <td><span class="state state-<?= docker_h((string)($item['health']??$item['state']??'unknown')) ?>"><?= docker_h($item['health']??$item['state']??'unknown') ?></span></td>
      <td><?= docker_h(docker_format_percent($item['cpu_percent']??null)) ?></td>
      <td><?= docker_h(docker_format_bytes($item['memory_used_bytes']??null)) ?><small><?= $item['memory_limit_bytes']===null?'sin límite':'de '.docker_h(docker_format_bytes($item['memory_limit_bytes'])) ?></small></td>
      <td><?= docker_h(docker_format_bytes($item['network_rx_bytes_total']??null)) ?><small><?= docker_h(docker_format_bytes($item['network_tx_bytes_total']??null)) ?></small></td>
      <td><?= docker_h(docker_format_bytes($item['block_read_bytes_total']??null)) ?><small><?= docker_h(docker_format_bytes($item['block_write_bytes_total']??null)) ?></small></td>
      <td><?= $item['pids']===null?'N/D':(int)$item['pids'] ?></td>
      <td><?= (int)($item['restart_count']??0) ?></td>
      <td><?= docker_h(docker_format_duration($item['uptime_seconds']??null)) ?></td>
    </tr>
  <?php endforeach; ?>
  </tbody></table></div>
  <?php endif; ?>
</article>
