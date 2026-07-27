# Rising World Dedicated Server

Docker image for the Linux `Rising World` dedicated server. The image installs
and updates Steam application `339010` at container startup and runs the game
server as the unprivileged `steam` user.

The image supports `linux/amd64`.

## Quick start

The named-volume example works without host-side permission preparation:

```bash
docker compose -f compose.named-volume.yaml up -d
docker compose -f compose.named-volume.yaml logs -f
```

The first startup downloads and validates the required SteamCMD metadata and can
take several minutes. Server files, configuration, worlds, and plugins persist
in the `rising-world-data` volume.

## Compose examples

- `compose.named-volume.yaml` uses a Docker-managed volume and is recommended
  for new installations.
- `compose.bind-mount.yaml` stores the server data in
  `${RW_DATA_DIR:-./data}` on the host.

Both examples publish TCP and UDP ports `4254` through `4259`, enable a two
minute graceful-stop window, and limit Docker log retention.

### Bind-mount permissions

The container runs as uid `1000` and gid `1000`. Prepare an existing host
directory before switching from an older root-based image:

```bash
sudo chown -R 1000:1000 /absolute/path/to/rising-world-data
RW_DATA_DIR=/absolute/path/to/rising-world-data \
  docker compose -f compose.bind-mount.yaml up -d
```

Replace the example path with the exact dedicated-server directory. The
container exits with a clear error when the mounted directory is not writable.

## Install OZ Tools

### Automatic installation

Set `RW_INSTALL_OZ_TOOLS` to `true` in either Compose example to download and
install the latest OZ Tools release before every server start:

```yaml
environment:
  RW_INSTALL_OZ_TOOLS: "true"
```

API, download, or extraction failures are logged as warnings and never prevent
the Rising World server from starting. Existing local OZ Tools configuration
files are carried over when the release files are replaced.

### One-off installation

Both Compose examples create the server container as
`rising-world-server-1`. The following one-liner downloads the latest OZ Tools
release, installs it into the persistent `Plugins` directory with the correct
ownership, and restarts the server:

```bash
docker run --rm --volumes-from rising-world-server-1 alpine:3.22 sh -ec 'apk add --no-cache curl unzip >/dev/null; plugins=/appdata/rising-world/dedicated-server/Plugins; url="$(curl -fsSL https://api.github.com/repos/Devidian/rw-plugin-oz-tools/releases/latest | sed -n "s/.*\"browser_download_url\": \"\\([^\"]*\\.zip\\)\".*/\\1/p" | head -n 1)"; test -n "$url"; mkdir -p "$plugins"; curl -fsSL "$url" -o /tmp/oztools.zip; unzip -oq /tmp/oztools.zip -d "$plugins"; test -f "$plugins/OZTools/OZTools.jar"; chown -R 1000:1000 "$plugins/OZTools"' && docker restart rising-world-server-1
```

The helper container inherits the server's mount, so the command works with
both the named-volume and bind-mount variants. If the Compose project name was
changed, replace `rising-world-server-1` with the actual server container name.
Running the command again updates the existing OZ Tools installation while
retaining its local configuration files.

## Configuration

| Variable | Default | Description |
| --- | --- | --- |
| `RW_UPDATE_ON_START` | `true` | Run SteamCMD `app_update` before starting the server. A missing installation is always installed. |
| `RW_VALIDATE` | `false` | Add `validate` to `app_update`. This makes startup slower but verifies all installed files. |
| `RW_INSTALL_OZ_TOOLS` | `false` | Download and install the latest OZ Tools release before every server start. Installation failures are non-fatal. |

Only the literal values `true` and `false` are accepted.

Rising World configuration is stored inside the persistent server directory:

```text
/appdata/rising-world/dedicated-server
```

## Health and shutdown

The image checks `http://127.0.0.1:4254/info` every 30 seconds. A ten minute
startup grace period accommodates the first installation. Docker health status
is observational: a container marked `unhealthy` is not restarted solely by the
Compose restart policy.

The server replaces the entrypoint process and receives Docker stop signals
directly. The Compose examples allow up to two minutes for world data to be
saved before Docker forces termination.

## Backups

Stop the server cleanly before taking a filesystem-level backup. Back up the
complete persistent server directory or named volume and periodically test a
restore into a separate volume. In-game backups stored in the same volume do
not replace an external backup.

## Build

```bash
docker build \
  --build-arg VERSION=dev \
  --build-arg VCS_REF="$(git rev-parse HEAD)" \
  -t rising-world-docker:dev .
```

Published releases use immutable version tags such as `2.1.0`, the compatible
major tag `2`, and `latest`.

## License

This project is available under the MIT License.
