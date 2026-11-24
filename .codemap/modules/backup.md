# Backup and compaction
<!-- codemap-id: docker-rising-world/backup -->

## Responsibility

Back up game data and optionally compact plugin SQLite databases before server start. A successful backup gates compaction and interrupted swaps are recovered.

## Source and tests

- [Backup script](../../backup.sh), [compaction script](../../compact-plugin-dbs.sh), and [entrypoint](../../entrypoint.sh) own sequencing.
- [Backup tests](../../tests/backup.sh) and [compaction tests](../../tests/compact-plugin-dbs.sh) cover the operations. Plugin owners retain schema responsibility.
