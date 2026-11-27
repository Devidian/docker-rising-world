# Server startup and health
<!-- codemap-id: docker-rising-world/startup -->

## Responsibility

Configure and start the dedicated server, optionally install OZ Tools, and provide container health status.

## Source and tests

- [OZ Tools installer fixture](../../tests/install-oz-tools.sh) covers archive validation, preservation of settings and failed-swap rollback.

- [Entrypoint](../../entrypoint.sh), [Dockerfile](../../Dockerfile), and [healthcheck](../../healthcheck.sh) implement the lifecycle.
- [Healthcheck tests](../../tests/healthcheck.sh) cover health behavior. See [backup](backup.md) for startup data handling.

## Dependencies

- `rw-plugin-oz-tools` — optional installation during startup. [Entrypoint](../../entrypoint.sh)
