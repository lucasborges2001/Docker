# Arquitectura

Docker queda dividido en shell servidor, Base reusable, back PHP read-only y SuperAdmin. Shell sourcea `Base/lib/shell/*.sh`; PHP carga `Base/back/bootstrap.php` si existe y luego clases Base.

Docker solo implementa dominio Docker: eventos, heartbeat, incidentes, snapshots y rendering específico.
