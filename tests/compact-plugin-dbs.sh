#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
work_dir="$(mktemp -d)"
trap 'rm -rf -- "${work_dir}"' EXIT
game_dir="${work_dir}/game"
plugin_dir="${game_dir}/Plugins/Example Plugin's"
mkdir -p -- "${plugin_dir}" "${work_dir}/bin"
db="${plugin_dir}/World.db"
small_db="${plugin_dir}/Small.db"
backup_calls="${work_dir}/backup-calls"

cat > "${work_dir}/backup.sh" <<'EOF'
#!/usr/bin/env bash
printf 'backup\n' >> "${BACKUP_CALLS}"
[[ "${BACKUP_FAIL:-false}" != true ]]
EOF
chmod +x "${work_dir}/backup.sh"
export BACKUP_CALLS="${backup_calls}"

sqlite3 "${db}" 'CREATE TABLE records (id INTEGER PRIMARY KEY, payload BLOB);
    INSERT INTO records (payload) VALUES (zeroblob(2097152));
    DELETE FROM records; INSERT INTO records (payload) VALUES (zeroblob(1));'
sqlite3 "${small_db}" 'CREATE TABLE records (id INTEGER PRIMARY KEY);'
original_size="$(stat -c %s -- "${db}")"
[[ "${original_size}" -gt 1048576 ]]

bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" false 1 false 7 "${work_dir}/backup.sh"
[[ ! -e "${backup_calls}" ]]
[[ "$(stat -c %s -- "${db}")" == "${original_size}" ]]

bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" true 1 false 7 "${work_dir}/backup.sh"
[[ "$(wc -l < "${backup_calls}")" == 1 ]]
[[ "$(stat -c %s -- "${db}")" -lt "${original_size}" ]]
[[ "$(sqlite3 "${db}" 'SELECT hex(payload) FROM records;')" == 00 ]]
[[ -f "${small_db}" ]]

# Include committed rows that exist only in an uncheckpointed WAL.
wal_db="${plugin_dir}/WAL.db"
python3 - "${wal_db}" <<'PY'
import os
import sqlite3
import sys

connection = sqlite3.connect(sys.argv[1])
connection.execute("CREATE TABLE records (payload BLOB)")
connection.execute("INSERT INTO records VALUES (zeroblob(2097152))")
connection.commit()
connection.execute("PRAGMA journal_mode=WAL")
connection.execute("DELETE FROM records")
connection.execute("INSERT INTO records VALUES (zeroblob(1))")
connection.commit()
os._exit(0)
PY
[[ -f "${wal_db}-wal" ]]
bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" true 1 false 7 "${work_dir}/backup.sh"
[[ "$(sqlite3 "${wal_db}" 'SELECT hex(payload) FROM records;')" == 00 ]]
[[ "$(sqlite3 "${wal_db}" 'PRAGMA quick_check;')" == ok ]]
[[ ! -e "${wal_db}-wal" && ! -e "${wal_db}-shm" ]]

# A failed required backup leaves the database untouched.
sqlite3 "${db}" 'INSERT INTO records (payload) VALUES (zeroblob(2097152)); DELETE FROM records WHERE id > 1;'
original_size="$(stat -c %s -- "${db}")"
BACKUP_FAIL=true bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" true 1 false 7 "${work_dir}/backup.sh"
[[ "$(stat -c %s -- "${db}")" == "${original_size}" ]]
if BACKUP_FAIL=true bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" true 1 true 7 "${work_dir}/backup.sh"; then
    printf 'A failed normal startup backup must stop startup.\n' >&2
    exit 1
fi

# A SQLite failure rolls back locally, then a simulated interrupted swap is recovered.
real_sqlite3="$(command -v sqlite3)"
cat > "${work_dir}/bin/sqlite3" <<'EOF'
#!/usr/bin/env bash
if [[ "$*" == *'VACUUM INTO'* ]]; then
    exit 1
fi
exec "${REAL_SQLITE3}" "$@"
EOF
chmod +x "${work_dir}/bin/sqlite3"
REAL_SQLITE3="${real_sqlite3}" PATH="${work_dir}/bin:${PATH}" \
    bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" true 1 false 7 "${work_dir}/backup.sh"
[[ "$(stat -c %s -- "${db}")" == "${original_size}" ]]
[[ "$(sqlite3 "${db}" 'PRAGMA quick_check;')" == ok ]]

marker="${db}.rw-compact-rollback"
mkdir -- "${marker}"
mv -- "${db}" "${marker}/original.db"
sqlite3 "${db}" 'CREATE TABLE interrupted (id INTEGER);'
bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" false 1 false 7 "${work_dir}/backup.sh"
[[ ! -e "${marker}" ]]
[[ "$(sqlite3 "${db}" 'SELECT hex(payload) FROM records;')" == 00 ]]
[[ "$(sqlite3 "${db}" 'PRAGMA quick_check;')" == ok ]]

# A committed swap keeps the new database if cleanup was interrupted.
mkdir -- "${marker}"
sqlite3 "${marker}/original.db" 'CREATE TABLE obsolete (id INTEGER);'
touch -- "${marker}/committed"
bash "${repo_dir}/compact-plugin-dbs.sh" "${game_dir}" false 1 false 7 "${work_dir}/backup.sh"
[[ ! -e "${marker}" ]]
[[ "$(sqlite3 "${db}" 'SELECT hex(payload) FROM records;')" == 00 ]]

printf 'Plugin database compaction tests passed.\n'
