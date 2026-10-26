#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
runner="$repo_root/bin/overcommit-rspec"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT
mkdir -p "$fixture/mock-bin"

cat > "$fixture/mock-bin/docker" <<'MOCK'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >> "$FAKE_DOCKER_LOG"
case "$*" in
  info) [[ "$FAKE_DOCKER_MODE" != 'offline' ]] ;;
  'compose version') [[ "$FAKE_DOCKER_MODE" != 'no-compose' ]] ;;
  *' run --rm -T '* )
    [[ "$FAKE_DOCKER_MODE" != 'run-error' ]] || exit 23
    ;;
  *) printf 'Inesperada invocación Docker: %s\n' "$*" >&2; exit 98 ;;
esac
MOCK
chmod +x "$fixture/mock-bin/docker"

fail() { printf 'ERROR de prueba: %s\n' "$1" >&2; exit 1; }

check_invocation() {
  local mode="$1" expected_status="$2" expected_command="$3"
  shift 3
  : > "$fixture/docker.calls"
  local status=0
  FAKE_DOCKER_LOG="$fixture/docker.calls" FAKE_DOCKER_MODE="$mode" \
    PATH="$fixture/mock-bin:$PATH" bash "$runner" "$@" >"$fixture/out" 2>"$fixture/err" || status=$?
  [[ "$status" == "$expected_status" ]] || fail "$mode: esperaba $expected_status, recibió $status; $(cat "$fixture/err")"
  if [[ -n "$expected_command" ]]; then
    grep -q -- "$expected_command" "$fixture/docker.calls" || fail "$mode: no invocó $expected_command"
  fi
}

check_invocation running 0 ' run --rm -T ' spec/models/example_spec.rb
[[ "$(grep -c ' run --rm -T ' "$fixture/docker.calls")" == 1 ]] || fail 'Debe usar un solo contenedor temporal.'
grep -q 'RAILS_ENV=test' "$fixture/docker.calls" || fail 'El entorno debe ser test.'
grep -q 'POSTGRES_HOST=db' "$fixture/docker.calls" || fail 'La BD debe ser db dentro de Docker.'
grep -q 'unset DATABASE_URL; exec bundle exec ruby bin/with-test-db-lock' "$fixture/docker.calls" || fail 'Debe reservar la BD de pruebas.'
grep -q 'bin/rails db:prepare && exec bundle exec rspec' "$fixture/docker.calls" || fail 'Debe preparar la BD y correr RSpec.'
grep -q 'spec/models/example_spec.rb' "$fixture/docker.calls" || fail 'Debe pasar argumentos a RSpec.'

check_invocation stopped 0 ' run --rm -T '
! grep -q ' exec -T \| ps --status ' "$fixture/docker.calls" ||
  fail 'No debe tocar el servidor web ni depender de su estado.'

check_invocation offline 1 ''
! grep -q ' exec -T \| run --rm -T ' "$fixture/docker.calls" || fail 'No debe invocar Rails si Docker está desconectado.'
grep -q 'daemon' "$fixture/err" || fail 'Debe informar que el daemon no está disponible.'

check_invocation no-compose 1 ''
grep -q 'Docker Compose v2' "$fixture/err" || fail 'Debe informar que falta Compose.'

check_invocation run-error 23 ' run --rm -T '
grep -q 'código 23' "$fixture/err" || fail 'Debe propagar el fallo al levantar dependencias.'

printf 'OK: Overcommit RSpec usa un contenedor temporal aislado, sin interrumpir web.\n'
