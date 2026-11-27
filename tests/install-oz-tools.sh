#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
export TMPDIR="${work_dir}"
PLUGINS_DIR="${work_dir}/Plugins"
OZ_TOOLS_DIR="${PLUGINS_DIR}/OZTools"
OZ_TOOLS_RELEASE_API="https://mock.invalid/release"
fixture_archive=""
fail_swap=false

# Load only the installer and its cleanup helper. Game startup is outside this fixture.
# shellcheck source=/dev/null
source <(awk '
  /^(cleanup_oz_tools_update|install_oz_tools)\(\) \{/ { active = 1 }
  active { print }
  active && /^\}/ { active = 0 }
' "${repo_dir}/entrypoint.sh")

curl() {
    while (( $# )); do
        if [[ "$1" == "--output" ]]; then
            cp -- "${fixture_archive}" "$2"
            return
        fi
        if [[ "$1" == "${OZ_TOOLS_RELEASE_API}" ]]; then
            printf '{ "browser_download_url": "https://mock.invalid/release.zip" }\n'
            return
        fi
        shift
    done
    return 1
}

mv() {
    if [[ "${fail_swap}" == "true" && "$1" == */.oztools-install.*/OZTools ]]; then
        return 1
    fi
    command mv "$@"
}

python3 - "${work_dir}" <<'PY'
from io import BytesIO
from pathlib import Path
import sys
from zipfile import ZipFile

root = Path(sys.argv[1])
for version in ("first", "next"):
    jar = BytesIO()
    with ZipFile(jar, "w") as packaged:
        packaged.writestr("resources/plugin.yml", "name: OZ - Tools\nversion: " + version)
    with ZipFile(root / f"{version}.zip", "w") as archive:
        archive.writestr("OZTools/OZTools.jar", jar.getvalue())
        archive.writestr("OZTools/README.md", version)
with ZipFile(root / "missing.zip", "w") as archive:
    archive.writestr("OZTools/README.md", "incomplete")
with ZipFile(root / "invalid.jar.zip", "w") as archive:
    archive.writestr("OZTools/OZTools.jar", "this is not a JAR")
(root / "invalid.zip").write_text("this is not a ZIP")
PY

fixture_archive="${work_dir}/first.zip"
install_oz_tools
[[ "$(cat "${OZ_TOOLS_DIR}/README.md")" == "first" ]]
printf 'local settings\n' > "${OZ_TOOLS_DIR}/settings.world.json"
cp -- "${OZ_TOOLS_DIR}/OZTools.jar" "${work_dir}/old.jar"

for invalid in missing.zip invalid.jar.zip invalid.zip; do
    fixture_archive="${work_dir}/${invalid}"
    if install_oz_tools; then
        printf 'Installer falsely accepted %s\n' "${invalid}" >&2
        exit 1
    fi
    cmp "${work_dir}/old.jar" "${OZ_TOOLS_DIR}/OZTools.jar"
    [[ "$(cat "${OZ_TOOLS_DIR}/README.md")" == "first" ]]
done

fixture_archive="${work_dir}/next.zip"
fail_swap=true
if install_oz_tools; then
    printf 'Installer ignored failed swap\n' >&2
    exit 1
fi
cmp "${work_dir}/old.jar" "${OZ_TOOLS_DIR}/OZTools.jar"
fail_swap=false
install_oz_tools
[[ "$(cat "${OZ_TOOLS_DIR}/README.md")" == "next" ]]
[[ "$(cat "${OZ_TOOLS_DIR}/settings.world.json")" == "local settings" ]]
[[ -z "$(find "${PLUGINS_DIR}" -maxdepth 1 -name '.oztools-*' -print -quit)" ]]
printf 'OZ Tools archive installation tests passed.\n'
