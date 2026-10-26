#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
script="$repo_root/bin/repair-sidekiq-vips"
temp="$(mktemp -d)"
trap 'rm -rf "$temp"' EXIT
mkdir -p "$temp/mock-bin"

cat > "$temp/mock-bin/docker" <<'DOCKER'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
case "$*" in
  info) [[ "$FAKE_DOCKER_MODE" != 'offline' ]] ;;
  'compose version') true ;;
  *' run --rm -T --no-deps --entrypoint sh sidekiq -lc '*)
    if [[ "$FAKE_DOCKER_MODE" == 'stale' || "$FAKE_DOCKER_MODE" == 'build-error' || "$FAKE_DOCKER_MODE" == 'bad-new-image' ]]; then
      [[ -f "$FAKE_DOCKER_BUILT" && "$FAKE_DOCKER_MODE" != 'bad-new-image' ]]
    fi
    ;;
  *' build --no-cache sidekiq')
    [[ "$FAKE_DOCKER_MODE" != 'build-error' ]] || exit 43
    touch "$FAKE_DOCKER_BUILT"
    ;;
  *' up -d --no-deps --force-recreate sidekiq') true ;;
  *' exec -T sidekiq sh -lc '*)
    [[ "$FAKE_DOCKER_MODE" != 'bad-running-container' ]]
    ;;
  *) printf 'Unexpected Docker command: %s\n' "$*" >&2; exit 98 ;;
esac
DOCKER
chmod +x "$temp/mock-bin/docker"

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

run_case() {
  local mode="$1" expected="$2" status=0
  : > "$temp/calls"
  rm -f "$temp/built"
  FAKE_DOCKER_LOG="$temp/calls" FAKE_DOCKER_MODE="$mode" \
    FAKE_DOCKER_BUILT="$temp/built" PATH="$temp/mock-bin:$PATH" \
    bash "$script" > "$temp/stdout" 2> "$temp/stderr" || status=$?
  [[ "$status" == "$expected" ]] || fail "$mode: expected exit $expected, got $status: $(cat "$temp/stderr")"
}

run_case healthy 0
! grep -q ' build --no-cache ' "$temp/calls" || fail 'Healthy image should not be rebuilt.'
grep -q ' up -d --no-deps --force-recreate sidekiq' "$temp/calls" || fail 'Healthy image must recreate stale Sidekiq container.'
grep -q ' exec -T sidekiq ' "$temp/calls" || fail 'Must verify the running Sidekiq.'

run_case stale 0
grep -q ' build --no-cache sidekiq' "$temp/calls" || fail 'Stale image must be rebuilt.'
[[ "$(grep -c ' run --rm -T --no-deps --entrypoint sh sidekiq ' "$temp/calls")" == 2 ]] ||
  fail 'Check both old and rebuilt image before replacing Sidekiq.'
grep -q ' exec -T sidekiq ' "$temp/calls" || fail 'Must verify repaired Sidekiq.'

run_case build-error 1
! grep -q ' up -d ' "$temp/calls" || fail 'Must not replace container after a failed build.'

run_case bad-new-image 1
! grep -q ' up -d ' "$temp/calls" || fail 'Must not replace container if new image fails Vips check.'

run_case bad-running-container 1
grep -q ' up -d --no-deps --force-recreate sidekiq' "$temp/calls" ||
  fail 'Must attempt recreation.'
grep -q ' exec -T sidekiq ' "$temp/calls" || fail 'Must detect broken runtime.'

run_case offline 1
! grep -q ' run --rm ' "$temp/calls" || fail 'Do not proceed without Docker daemon.'

if grep -Eq ' down| --volumes| volume rm| volume prune| db| redis' "$temp/calls"; then
  fail 'Repair must not remove/modify Postgres or Redis volumes or services.'
fi

printf 'OK: Sidekiq Vips repair safely verifies, rebuilds if needed, recreates, and validates.\n'
