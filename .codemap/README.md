# Rising World container
<!-- codemap-id: docker-rising-world -->

## Purpose

Container image and scripts for game server startup, backups, optional database compaction and health checks. [Dockerfile](../Dockerfile) installs [entrypoint](../entrypoint.sh).

## Modules

- [Server startup and health](modules/startup.md)
- [Backup and compaction](modules/backup.md)

## Build and tests

Run shell checks in [tests](../tests/) relevant to the changed scripts. [README](../README.md) documents container configuration.
