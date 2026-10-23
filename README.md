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

### Steam beta branch

Set `RW_BETA` to the Steam branch name to install and update that version:

```bash
RW_BETA=branch-name docker compose -f compose.named-volume.yaml up -d
```

Replace `branch-name` with the exact Steam branch name. Use the same setting
with `compose.bind-mount.yaml` if needed. Set `RW_IMAGE` to a different image
tag when testing a local build. The branch is
selected when SteamCMD runs at startup. Set `RW_BETA=public` to switch an
existing installation back to the public branch. Keep `RW_UPDATE_ON_START=true`
when changing branches; an absent server installation is downloaded even when
updates are disabled. Back up persistent server data before switching between
branches with different world or configuration formats.

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
| `RW_BETA` | empty | Select a Steam beta branch with `-beta <branch>`. Empty uses SteamCMD's default branch behavior; use `public` explicitly to return from a beta. |
| `RW_INSTALL_OZ_TOOLS` | `false` | Download and install the latest OZ Tools release before every server start. Installation failures are non-fatal. |
| `RW_BACKUP_ON_START` | `true` | Snapshot existing `Worlds` and `Plugins` before SteamCMD, plugin updates, and the game server start. |
| `RW_BACKUP_KEEP` | `7` | Number of startup archives to retain (1–999999). Oldest archives are pruned only after a new archive completes. |

The boolean variables accept only the literal values `true` and `false`.

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

By default, each container start archives the existing `Worlds` and `Plugins`
directories **before** SteamCMD or the game server runs. The first start skips
the backup if neither directory exists. Borg stores the archives in
`Backups/docker-rising-world/repository/` inside the persistent server directory.
Each archive is independently restorable, while Borg deduplicates unchanged
data and changed chunks within large SQLite databases. The repository uses
authenticated, unencrypted storage with an empty passphrase. A failed backup
prevents the server from starting. Set `RW_BACKUP_ON_START=false` to disable
this behavior; set `RW_BACKUP_KEEP` to change the retention count. These are
startup backups, so a continuously running container does not create new
archives on a timer.

To restore, stop the server and preserve the current data outside the server
directory. List archives with `borg list Backups/docker-rising-world/repository`
from inside the server directory. Move the current `Worlds` and `Plugins`
directories aside, then run
`borg extract Backups/docker-rising-world/repository::ARCHIVE` from that
directory. Set `BORG_PASSPHRASE=''`, `BORG_CACHE_DIR` and `BORG_SECURITY_DIR`
to the corresponding paths under `Backups/docker-rising-world/` when running
Borg outside the image. With a named volume, use a temporary helper container
while the game server is stopped. Archives remain in the same persistent
volume and do not protect against volume or host loss. Copy the repository to
external storage and periodically test a restore.

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
