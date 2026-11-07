#!/usr/bin/env bash
set -Eeuo pipefail

repo_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
test_dir="$(mktemp -d)"
trap 'rm -rf -- "${test_dir}"' EXIT
mkdir -p "${test_dir}/bin" "${test_dir}/game"

cat > "${test_dir}/bin/curl" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "${@: -1}" > "${HEALTHCHECK_CALLED_URL}"
EOF
chmod +x "${test_dir}/bin/curl"
export PATH="${test_dir}/bin:${PATH}"
export HEALTHCHECK_CALLED_URL="${test_dir}/called-url"
cd "${test_dir}/game"

bash "${repo_dir}/healthcheck.sh"
[[ "$(cat "${HEALTHCHECK_CALLED_URL}")" == 'http://127.0.0.1:4254/info' ]]

printf 'Server_Port=5255\r\n' > server.properties
bash "${repo_dir}/healthcheck.sh"
[[ "$(cat "${HEALTHCHECK_CALLED_URL}")" == 'http://127.0.0.1:5254/info' ]]

printf '  Server_Port = 4355  \n' > server.properties
bash "${repo_dir}/healthcheck.sh"
[[ "$(cat "${HEALTHCHECK_CALLED_URL}")" == 'http://127.0.0.1:4354/info' ]]

rm "${HEALTHCHECK_CALLED_URL}"
printf 'Server_Port=invalid\n' > server.properties
if bash "${repo_dir}/healthcheck.sh" 2> "${test_dir}/error"; then
    printf 'Invalid Server_Port unexpectedly passed healthcheck.\n' >&2
    exit 1
fi
[[ ! -e "${HEALTHCHECK_CALLED_URL}" ]]
grep -q 'Invalid Server_Port' "${test_dir}/error"

printf 'Server_Port=1\n' > server.properties
if bash "${repo_dir}/healthcheck.sh" 2> "${test_dir}/error"; then
    printf 'Out-of-range Server_Port unexpectedly passed healthcheck.\n' >&2
    exit 1
fi
[[ ! -e "${HEALTHCHECK_CALLED_URL}" ]]

printf 'Healthcheck tests passed.\n'
