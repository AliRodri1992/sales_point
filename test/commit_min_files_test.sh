#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${repo_root}/bin/check-commit-min-files"
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

expect_rejection() {
  if bash "$checker" "$@" >/dev/null 2>&1; then
    echo "ERROR: debería rechazar: $*" >&2
    exit 1
  fi
}

cd "$fixture"
git init -q
git config user.name 'Commit Policy Test'
git config user.email 'commit-policy@example.invalid'

for number in 1 2 3 4; do
  printf 'contenido %s\n' "$number" > "file-${number}.txt"
done
git add .
expect_rejection --staged

printf 'quinto archivo\n' > file-5.txt
git add .
bash "$checker" --staged
git -c core.hooksPath=/dev/null commit -qm 'Valid five-file commit'
good_commit="$(git rev-parse HEAD)"
bash "$checker" --commit "$good_commit"

printf 'un archivo\n' > file-6.txt
git add .
expect_rejection --staged
git -c core.hooksPath=/dev/null commit -qm 'Invalid one-file commit'
expect_rejection --commit HEAD
expect_rejection --range "$good_commit" HEAD

printf 'OK: pruebas de la política de commits superadas.\n'
