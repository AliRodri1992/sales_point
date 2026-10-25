#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
checker="${repo_root}/bin/check-commit-min-files"
schema_path='db/schema.rb'
fixture="$(mktemp -d)"
trap 'rm -rf "$fixture"' EXIT

expect_rejection() {
  if bash "$checker" "$@" >/dev/null 2>&1; then
    printf 'ERROR: debería rechazar: %s\n' "$*" >&2
    exit 1
  fi
}

commit_fixture() {
  git -c core.hooksPath=/dev/null commit -qm "$1"
}

cd "$fixture"
git init -q
git config user.name 'Commit Policy Test'
git config user.email 'commit-policy@example.invalid'

# Cinco archivos: aceptado en staging y en el historial.
for number in 1 2 3 4 5; do
  printf 'contenido %s\n' "$number" > "file-${number}.txt"
done
git add .
bash "$checker" --staged
commit_fixture 'Valid five-file commit'
bash "$checker" --commit HEAD

# Crear schema.rb no es una actualización y NO permite un commit individual.
mkdir -p "$(dirname "$schema_path")"
printf 'ActiveRecord::Schema[8.1].define(version: 1) {}\n' > "$schema_path"
git add .
expect_rejection --staged
commit_fixture 'Schema creation not allowed as exception'
expect_rejection --commit HEAD

# Modificar exclusivamente el schema.rb existente: permitido.
before_schema="$(git rev-parse HEAD)"
printf 'ActiveRecord::Schema[8.1].define(version: 2) {}\n' > "$schema_path"
git add .
bash "$checker" --staged
commit_fixture 'Necessary schema update'
bash "$checker" --commit HEAD
bash "$checker" --range "$before_schema" HEAD

# Un archivo distinto del esquema: rechazado en staging y en CI.
before_other="$(git rev-parse HEAD)"
printf 'cambio aislado\n' >> file-1.txt
git add .
expect_rejection --staged
commit_fixture 'Invalid single-file commit'
expect_rejection --commit HEAD
expect_rejection --range "$before_other" HEAD

# Otro archivo también denominado schema.rb, pero en una ruta distinta: rechazado.
mkdir -p unrelated
printf 'contenido\n' > unrelated/schema.rb
git add .
expect_rejection --staged
commit_fixture 'Invalid schema at unrelated path'
expect_rejection --commit HEAD

# Dos archivos incluyendo schema.rb: no aplica la excepción.
printf 'ActiveRecord::Schema[8.1].define(version: 3) {}\n' > "$schema_path"
printf 'cambio\n' >> file-1.txt
git add .
expect_rejection --staged
commit_fixture 'Invalid two-file schema commit'
expect_rejection --commit HEAD

# Tres y cuatro archivos: siempre rechazados.
for count in 3 4; do
  for number in $(seq 1 "$count"); do
    printf 'cambio adicional\n' >> "file-${number}.txt"
  done
  git add .
  expect_rejection --staged
  commit_fixture "Invalid ${count}-file commit"
  expect_rejection --commit HEAD
done

# Una eliminación del esquema NO constituye una modificación permitida.
git rm -q "$schema_path"
expect_rejection --staged
commit_fixture 'Invalid schema removal'
expect_rejection --commit HEAD

# Cinco archivos modificados: permitido de nuevo.
for number in 1 2 3 4 5; do
  printf 'cambio final\n' >> "file-${number}.txt"
done
git add .
bash "$checker" --staged
commit_fixture 'Valid five-file modification'
bash "$checker" --commit HEAD

printf 'OK: mínimo 5 y excepción exclusiva de modificación de schema.rb validados.\n'
